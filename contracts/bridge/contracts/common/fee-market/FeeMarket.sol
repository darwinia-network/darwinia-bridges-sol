pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

contract FeeMarket {
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);
    event Locked(address indexed src, uint wad);
    event UnLocked(address indexed src, uint wad);
    event AddRelayer(address indexed relayer, uint fee);
    event RemoveRelayer(address indexed relayer);
    event OrderAssgigned(uint64 indexed nonce, uint timestamp, address[] top_relayers);
    event OrderDelivered(uint64 indexed nonce, uint timestamp);

    address internal constant SENTINEL_RELAYERS = address(0x1);

    address public immutable outbound;
    uint public constant immutable COLLATERAL_PERORDER;
    uint public constant immutable ASSIGNED_RELAYERS_NUMBER;

    struct Order {
        uint32 assigned_time;
        uint32 delivered_time;
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public locked;
    mapping(address => address) public relayers;
    mapping(address => uint256) public relayer_fee;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => mapping(uint256 => address)) public assigned_relayers;
    uint public relayer_count;

    modifier onlyOutBound() {
        require(msg.sender == outbound);
        _;
    }

    modifier enoughBalance() {
        require(balanceOf[msg.sender] >= COLLATERAL_PERORDER);
        _;
    }

    constructor(address _outbound) public {
        outbound = _outbound;
        relayers[SENTINEL_RELAYERS] = SENTINEL_RELAYERS;
    }

    receive() external payable {
    }

    function market_fee() external view returns (uint fee) {
        address[] memory top_relayers = getTopRelayers();
        address last = top_relayers[top_relayers.length - 1];
        return relayer_fee[last];
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        msg.sender.transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function assign(uint64 nonce) public payable onlyOutBound returns (bool) {
        //select assigned_relayers
        address[] memory top_relayers = getTopRelayers();
        address last = top_relayers[top_relayers.length - 1];
        require(msg.value >= relayer_fee[last]);
        for (uint i = 0; i < top_relayers.length; i++) {
            address r = top_relayers[i];
            require(is_relayer(r), "!relayer");
            require(_lock(r, COLLATERAL_PERORDER), "!lock");
            assigned_relayers[nonce][i] = r;
        }
        orders[nonce] = Order(block.timestamp, 0);
        emit OrderAssgigned(nonce, block.timestamp, top_relayers);
        return true;
    }

    function delivery(uint64 nonce) public onlyOutBound {
        orders[nonce].delivered_time = block.timestamp;
        emit OrderAssgigned(nonce, block.timestamp);
    }

    function settle(uint64 nonce) public {
        require(orders[nonce].delivered_time > 0, "!delivered");
        pay_relayers_rewards();
    }

    function enroll(address prev, uint fee) public payable {
        deposit();
        add_relayer(prev, fee);
    }

    function add_relayer(address prev, uint fee) public enoughBalance {
        address cur = msg.sender;
        address next = relayers[prev];
        require(cur != address(0) && cur != SENTINEL_RELAYERS && cur != address(this), "!valid");
        require(relayers[cur] == address(0), "!new");
        require(relayers[prev] != address(0), "!before");
        require(fee >= relayer_fee[prev], "!>=");
        if (next != SENTINEL_RELAYERS) {
            require(fee <= relayer_fee[next], "!<=");
        }
        relayers[cur] = next;
        relayers[prev] = cur;
        relayer_fee[cur] = fee;
        relayer_count++;
        emit AddRelayer(cur, fee);
    }

    function remove_relayer(address prev) public {
        _remove_relayer(prev, msg.sender);
    }

    function _remove_relayer(address prev, address cur) private {
        require(cur != address(0) && cur != SENTINEL_RELAYERS, "!valid");
        require(relayers[prev] == cur, "!cur");
        require(locked[cur] == 0, "!locked");
        relayers[prev] = relayers[cur];
        relayers[cur] = address(0);
        relayer_fee[cur] = 0;
        relayer_count--;
        emit RemoveRelayer(cur);
    }

    function swap_relayer(address old_prev, address new_prev, uint new_fee) public {
        remove_relayer(old_prev);
        add_relayer(new_prev, new_fee);
    }

    function getAllRelayers() public view returns (address[] memory) {
        return getRelayers(relayer_count);
    }

    function getTopRelayers() public view returns (address[] memory) {
        require(ASSIGNED_RELAYERS_NUMBER <= relayer_count, "!count");
        address[] memory array = new address[](ASSIGNED_RELAYERS_NUMBER);
        uint index = 0;
        address cur = relayers[SENTINEL_RELAYERS];
        while (cur != SENTINEL_RELAYERS) {
            if (balanceOf(cur) >= COLLATERAL_PERORDER) {
                array[index] = cur;
                index++;
            }
            cur = relayers[cur];
        }
        require(index == ASSIGNED_RELAYERS_NUMBER, "!assigned");
    }

    function getRelayers(uint count) public view returns (address[] memory) {
        require(count <= relayer_count, "!count");
        address[] memory array = new address[](count);
        uint index = 0;
        address cur = relayers[SENTINEL_RELAYERS];
        while (cur != SENTINEL_RELAYERS) {
            array[index] = cur;
            cur = relayers[cur];
            index++;
        }
    }

    function is_relayer(address addr) public view returns (bool) {
        return addr != SENTINEL_GUARDS && relayers[addr] != address(0);
    }

    function _lock(address src, uint wad) internal returns (bool) {
        require(balanceOf[src] >= wad);
        balanceOf[src] -= wad;
        locked[src] += wad;
        emit Locked(src, wad);
        return true;
    }

    function _unlock(address src, uint wad) internal returns (bool) {
        require(locked[src] >= wad);
        locked[src] -= wad;
        balanceOf[src] += wad;
        emit UnLocked(src, wad);
        return true;
    }

    /// Pay rewards to given relayers, optionally rewarding confirmation relayer.
    function pay_relayers_rewards(UnrewardedRelayer[] memory relayers, uint64 received_start, uint64 received_end) internal {
        address payable confirmation_relayer = msg.sender;
        uint256 confirmation_relayer_reward = 0;
        uint256 confirmation_fee = confirmationFee;
        // reward every relayer except `confirmation_relayer`
        for (uint256 i = 0; i < relayers.length; i++) {
            UnrewardedRelayer memory entry = relayers[i];
            address payable delivery_relayer = entry.relayer;
            uint64 nonce_begin = max(entry.messages.begin, received_start);
            uint64 nonce_end = min(entry.messages.end, received_end);
            uint256 delivery_reward = 0;
            uint256 confirmation_reward = 0;
            for (uint64 nonce = nonce_begin; nonce <= nonce_end; nonce++) {
                delivery_reward += messages[nonce].fee;
                confirmation_reward += confirmation_fee;
            }
            if (confirmation_relayer != delivery_relayer) {
                // If delivery confirmation is submitted by other relayer, let's deduct confirmation fee
                // from relayer reward.
                //
                // If confirmation fee has been increased (or if it was the only component of message
                // fee), then messages relayer may receive zero reward.
                if (confirmation_reward > delivery_reward) {
                    confirmation_reward = delivery_reward;
                }
                delivery_reward = delivery_reward - confirmation_reward;
                confirmation_relayer_reward = confirmation_relayer_reward + confirmation_reward;
            } else {
                // If delivery confirmation is submitted by this relayer, let's add confirmation fee
                // from other relayers to this relayer reward.
                confirmation_relayer_reward = confirmation_relayer_reward + delivery_reward;
                continue;
            }
            pay_relayer_reward(delivery_relayer, delivery_reward);
        }
        // finally - pay reward to confirmation relayer
        pay_relayer_reward(confirmation_relayer, confirmation_relayer_reward);
    }

    function pay_relayer_reward(address payable to, uint256 value) internal {
        if (value > 0) {
            to.transfer(value);
            emit RelayerReward(to, value);
        }
    }

}

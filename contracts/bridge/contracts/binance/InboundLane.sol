// SPDX-License-Identifier: MIT
// Message module that allows sending and receiving messages using lane concept:
//
// 1) the message is sent using `send_message()` call;
// 2) every outbound message is assigned nonce;
// 3) the messages are stored in the storage;
// 4) external component (relay) delivers messages to bridged chain;
// 5) messages are processed in order (ordered by assigned nonce);
// 6) relay may send proof-of-delivery back to this chain.
//
// Once message is sent, its progress can be tracked by looking at lane contract events.
// The assigned nonce is reported using `MessageAccepted` event. When message is
// delivered to the the bridged chain, it is reported using `MessagesDelivered` event.

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/ICrossChainFilter.sol";
import "./MessageCommitment.sol";
import "./SourceChain.sol";
import "./TargetChain.sol";

/**
 * @title Everything about incoming messages receival
 * @author echo
 * @notice The inbound lane is the message layer of the bridge
 * @dev See https://itering.notion.site/Basic-Message-Channel-c41f0c9e453c478abb68e93f6a067c52
 */
contract InboundLane is MessageCommitment, SourceChain, TargetChain {
    /**
     * @notice Notifies an observer that the message has dispatched
     * @param nonce The message nonce
     * @param result The message result
     * @param returndata The return data of message call, when return false, it's the reason of the error
     */
    event MessageDispatched(uint256 indexed lanePosition, uint256 indexed nonce, bool indexed result, bytes returndata);
    event DeliveredMessagePruned(uint256 indexed lanePosition, uint256 indexed nonce);

    /* Constants */

    /**
     * @dev Gas used per message needs to be less than 100000 wei
     */
    uint256 public constant MAX_GAS_PER_MESSAGE = 100000;

    uint256 public constant MAX_UNCONFIRMED_MESSAGES = 50;
    /**
     * @dev Gas buffer for executing `submit` tx
     */
    uint256 public constant GAS_BUFFER = 60000;

    /* State */

    /**
     * @dev ID of the next message, which is incremented in strict order
     * @notice When upgrading the lane, this value must be synchronized
     */

    struct InboundLaneNonce {
        uint256 last_confirmed_nonce;
        uint256 last_delivered_nonce;
    }

    InboundLaneNonce public inboundLaneNonce;

    struct RelayersIndex {
        uint256 front;
        uint256 back;
    }

    RelayersIndex public relayersIndex;

    // index => UnrewardedRelayer
    mapping(uint256 => UnrewardedRelayer) public relayers;

    /**
     * @notice Deploys the BasicInboundLane contract
     * @param _chainPosition The position of the leaf in the `chain_messages_merkle_tree`, index starting with 0
     * @param _lanePosition The position of the leaf in the `lane_messages_merkle_tree`, index starting with 0
     * @param _lightClientBridge The contract address of on-chain light client
     */
    constructor(address _lightClientBridge, uint256 _chainPosition, uint256 _lanePosition, uint256 _last_confirmed_nonce, uint256 _last_delivered_nonce) public MessageCommitment(_lightClientBridge, _chainPosition, _lanePosition) {
        inboundLaneNonce = InboundLaneNonce(_last_confirmed_nonce, _last_delivered_nonce);
    }

    /* Public Functions */

    // Receive messages proof from bridged chain.
    //
    // The weight of the call assumes that the transaction always brings outbound lane
    // state update. Because of that, the submitter (relayer) has no benefit of not including
    // this data in the transaction, so reward confirmations lags should be minimal.
    function receive_messages_proof(
        OutboundLaneData memory outboundLaneData,
        bytes32 inboundLaneDataHash,
        MessagesProof memory messagesProof
    ) public {
        verify_messages_proof(hash(outboundLaneData), inboundLaneDataHash, messagesProof);
        // Require there is enough gas to play all messages
        require(
            gasleft() >= outboundLaneData.messages.length * (MAX_GAS_PER_MESSAGE + GAS_BUFFER),
            "Lane: insufficient gas for delivery of all messages"
        );
        receive_state_update(outboundLaneData.latest_received_nonce);
        receive_message(outboundLaneData.messages);
        commit();
    }

    function relayer_size() public view returns (uint256 size) {
        size = relayersIndex.back - relayersIndex.front + 1;
    }

    function relayers_back() public view returns (address pre_relayer, uint256 nonce) {
        uint256 back = relayersIndex.back;
        pre_relayer = relayers[back].relayer;
        nonce = relayers[back].messages.begin;
    }

	// Get lane data from the storage.
    function data() public view returns (InboundLaneData memory lane_data) {
        uint256 size = relayer_size();
        lane_data.relayers = new UnrewardedRelayer[](size);
        uint256 front = relayersIndex.front;
        for (uint256 index = 0; index < size; index++) {
            lane_data.relayers[index] = relayers[front + index];
        }
        lane_data.last_confirmed_nonce = inboundLaneNonce.last_confirmed_nonce;
    }

    // storage proof issue: must use latest commitment in lightclient, cause we rm mmr root
    function commit() public returns (bytes32) {
        commitment = hash(data());
        return commitment;
    }

    /* Private Functions */

	// Receive state of the corresponding outbound lane.
    function receive_state_update(uint256 latest_received_nonce) internal returns (uint256) {
        uint256 last_delivered_nonce = inboundLaneNonce.last_delivered_nonce;
        uint256 last_confirmed_nonce = inboundLaneNonce.last_confirmed_nonce;
        require(latest_received_nonce <= last_delivered_nonce, "Lane: InvalidReceivedNonce");
        if (latest_received_nonce > last_confirmed_nonce) {
            uint256 new_confirmed_nonce = latest_received_nonce;
            uint256 front = relayersIndex.front;
            uint256 back = relayersIndex.back;
            for (uint256 index = front; index <= back; index++) {
                UnrewardedRelayer storage entry = relayers[index];
                if (entry.messages.end <= new_confirmed_nonce) {
                    // Firstly, remove all of the records where higher nonce <= new confirmed nonce
                    delete relayers[index];
                    relayersIndex.front = index + 1;
                } else if (entry.messages.begin < new_confirmed_nonce) {
                    // Secondly, update the next record with lower nonce equal to new confirmed nonce if needed.
                    // Note: There will be max. 1 record to update as we don't allow messages from relayers to
                    // overlap.
                    entry.messages.dispatch_results >>= (new_confirmed_nonce + 1 - entry.messages.begin);
                    entry.messages.begin = new_confirmed_nonce + 1;
                }
            }
            inboundLaneNonce.last_confirmed_nonce = new_confirmed_nonce;
        }
        return latest_received_nonce;
    }

	// Receive new message.
    function receive_message(Message[] memory messages) internal returns (uint256 dispatch_results) {
        address payable relayer = msg.sender;
        uint256 begin = inboundLaneNonce.last_delivered_nonce + 1;
        uint256 end = begin;
        for (uint256 i = 0; i < messages.length; i++) {
            Message memory message = messages[i];
            MessageKey memory key = message.key;
            MessagePayload memory message_payload = message.data.payload;
            if (key.nonce < end) {
                continue;
            }
            // check message nonce is correct and increment nonce for replay protection
            require(key.nonce == end, "Lane: InvalidNonce");
            // check message delivery to the correct lane position
            require(key.lane_id == lanePosition, "Lane: InvalidLaneID");
            // if there are more unconfirmed messages than we may accept, reject this message
            require(end - inboundLaneNonce.last_confirmed_nonce <= MAX_UNCONFIRMED_MESSAGES, "Lane: TooManyUnconfirmedMessages");
            // check message delivery to the correct lane contract
            require(message_payload.laneContract == address(this), "Lane: InvalidLaneContract");

            inboundLaneNonce.last_delivered_nonce = end;

            // then, dispatch message
            (bool dispatch_result, bytes memory returndata) = dispatch(message_payload);

            emit MessageDispatched(lanePosition, end, dispatch_result, returndata);
            // TODO: callback `pay_inbound_dispatch_fee_overhead`
            dispatch_results |= (dispatch_result ? uint256(1) : uint256(0)) << (end - begin);
        }
		// now let's update inbound lane storage
        (address pre_relayer, uint256 nonce) = relayers_back();
        if (pre_relayer == relayer) {
            UnrewardedRelayer storage r = relayers[nonce];
            uint256 padding = r.messages.end - r.messages.begin + 1;
            r.messages.end = end;
            r.messages.dispatch_results |= dispatch_results << padding;
        } else {
            relayersIndex.back += 1;
            relayers[relayersIndex.back] = UnrewardedRelayer(relayer, DeliveredMessages(begin, end, dispatch_results));
        }
    }

    function dispatch(MessagePayload memory payload) internal returns (bool dispatch_result, bytes memory returndata) {
        /**
         * @notice The app layer must implement the interface `ICrossChainFilter`
         */
        try ICrossChainFilter(payload.targetContract).crossChainFilter(payload.sourceAccount, payload.encoded)
            returns (bool ok)
        {
            if (ok) {
                // Deliver the message to the target
                (dispatch_result, returndata) = payload.targetContract.call{value: 0, gas: MAX_GAS_PER_MESSAGE}(payload.encoded);
            } else {
                dispatch_result = false;
                returndata = "Lane: filter failed";
            }
        } catch (bytes memory reason) {
            dispatch_result = false;
            returndata = reason;
        }
    }
}
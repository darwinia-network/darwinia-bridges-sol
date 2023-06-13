// This file is part of Darwinia.
// Copyright (C) 2018-2022 Darwinia Network
// SPDX-License-Identifier: GPL-3.0
//
// Darwinia is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Darwinia is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Darwinia. If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.17;

import "../../interfaces/IRequestOracle.sol";
import "../../utils/TransferHelper.sol";

contract RequestOracle {
    using TransferHelper for address;

    event ImportStarted(uint64 indexed request_id);
    event ImportCancelled(uint64 indexed request_id);
    event ImportCompleted(uint64 indexed request_id);
    event StateRootImported(uint256 block_number, bytes32 state_root);

    IRequestOracle public oracle;
    mapping(address => OracleRequest) public requestOf;
    uint256 internal latest_block_number;
    bytes32 internal latest_state_root;

    uint64 constant internal TIMEOUT = 180;

    struct OracleRequest {
        uint64 id;
        uint64 at;
    }

    modifier canCompleteRequest() {
        require(is_oracle_requested(), "!requested");
        require(is_oracle_completed(), "!completed");
        _;
    }

    constructor(address oracle_) {
        oracle = IRequestOracle(oracle_);
    }

    function start_import() external returns (uint64 request_id) {
        require(!is_oracle_requested(), "started");
        address relayer = msg.sender;
        (address feeToken, uint256 requestFee) = oracle.getRequestFee();
        if (feeToken == address(0)) {
            request_id = oracle.requestFinalizedHash{value: requestFee}();
        } else {
            feeToken.safeTransferFrom(relayer, address(oracle), requestFee);
            request_id = oracle.requestFinalizedHash();
        }
        requestOf[relayer] = OracleRequest(request_id, _current_time());
        emit ImportStarted(request_id);
    }

    function cancel_import() external {
        require(is_oracle_timed_out(), "!time_out");
        address relayer = msg.sender;
        uint64 request_id = requestOf[relayer].id;
        delete requestOf[relayer];
        emit ImportCancelled(request_id);
    }

    function complete_import() external canCompleteRequest {
        address relayer = msg.sender;
        OracleRequest memory request = requestOf[relayer];
        uint64 request_id = request.id;
        (uint256 block_number, bytes32 hash) = oracle.dataOf(request_id);
        if (block_number > latest_block_number) {
            latest_block_number = block_number;
            latest_state_root = hash;
            emit StateRootImported(block_number, hash);
        }
        delete requestOf[relayer];
        emit ImportCompleted(request_id);
    }

    function is_oracle_completed() public view returns (bool) {
        uint64 request_id = requestOf[msg.sender].id;
        return oracle.isRequestComplete(request_id);
    }

    function is_oracle_requested() public view returns (bool) {
        return requestOf[msg.sender].id != 0;
    }

    function is_oracle_timed_out() public view returns (bool) {
        OracleRequest memory request = requestOf[msg.sender];
        if (request.at == 0) {
            return false;
        } else {
            return TIMEOUT + request.at < _current_time();
        }
    }

    function _current_time() internal view returns (uint64) {
        return uint64(block.timestamp);
    }
}

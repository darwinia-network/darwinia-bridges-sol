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

pragma solidity 0.7.6;
pragma abicoder v2;

import "../interfaces/ILightClient.sol";

contract InboundLaneVerifier {
    /// @dev The contract address of on-chain light client
    ILightClient public immutable lightClient;

    struct Slot0 {
        // Bridged lane position of the leaf in the `lane_message_merkle_tree`, index starting with 0
        uint32 bridgedLanePosition;
        // Bridged chain position of the leaf in the `chain_message_merkle_tree`, index starting with 0
        uint32 bridgedChainPosition;
        // This lane position of the leaf in the `lane_message_merkle_tree`, index starting with 0
        uint32 thisLanePosition;
        // This chain position of the leaf in the `chain_message_merkle_tree`, index starting with 0
        uint32 thisChainPosition;
    }

    /* State */

    // indentify slot
    // slot 0 ------------------------------------------------------------
    Slot0 public slot0;
    // ------------------------------------------------------------------

    constructor(
        address _lightClient,
        uint32 _thisChainPosition,
        uint32 _thisLanePosition,
        uint32 _bridgedChainPosition,
        uint32 _bridgedLanePosition
    ) {
        lightClient = ILightClient(_lightClient);
        slot0.thisChainPosition = _thisChainPosition;
        slot0.thisLanePosition = _thisLanePosition;
        slot0.bridgedChainPosition = _bridgedChainPosition;
        slot0.bridgedLanePosition = _bridgedLanePosition;
    }

    /* Private Functions */

    function verify_messages_proof(
        bytes32 outlane_data_hash,
        bytes memory encoded_proof
    ) internal view {
        Slot0 memory _slot0 = slot0;
        require(
            lightClient.verify_messages_proof(
                outlane_data_hash,
                _slot0.thisChainPosition,
                _slot0.bridgedLanePosition,
                encoded_proof
            ), "Verifer: InvalidProof"
        );
    }

    function getLaneInfo() external view returns (uint32,uint32,uint32,uint32) {
        Slot0 memory _slot0 = slot0;
        return (
           _slot0.thisChainPosition,
           _slot0.thisLanePosition,
           _slot0.bridgedChainPosition,
           _slot0.bridgedLanePosition
       );
    }

    // 32 bytes to identify an unique message from source chain
    // MessageKey encoding:
    // BridgedChainPosition | BridgedLanePosition | ThisChainPosition | ThisLanePosition | Nonce
    // [0..8)   bytes ---- Reserved
    // [8..12)  bytes ---- BridgedChainPosition
    // [16..20) bytes ---- BridgedLanePosition
    // [12..16) bytes ---- ThisChainPosition
    // [20..24) bytes ---- ThisLanePosition
    // [24..32) bytes ---- Nonce, max of nonce is `uint64(-1)`
    function encodeMessageKey(uint64 nonce) public view returns (uint256) {
        Slot0 memory _slot0 = slot0;
        return (uint256(_slot0.bridgedChainPosition) << 160) +
                (uint256(_slot0.bridgedLanePosition) << 128) +
                (uint256(_slot0.thisChainPosition) << 96) +
                (uint256(_slot0.thisLanePosition) << 64) +
                uint256(nonce);
    }
}


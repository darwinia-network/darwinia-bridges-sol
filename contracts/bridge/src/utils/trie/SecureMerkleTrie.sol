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

import { MerkleTrie } from "./MerkleTrie.sol";

/**
 * @title SecureMerkleTrie
 * @notice SecureMerkleTrie is a thin wrapper around the MerkleTrie library that hashes the input
 *         keys. Ethereum's state trie hashes input keys before storing them.
 */
library SecureMerkleTrie {
    /**
     * @notice Verifies a proof that a given key/value pair is present in the Merkle trie.
     *
     * @param _key   Key of the node to search for, as a hex string.
     * @param _value Value of the node to search for, as a hex string.
     * @param _proof Merkle trie inclusion proof for the desired node. Unlike traditional Merkle
     *               trees, this proof is executed top-down and consists of a list of RLP-encoded
     *               nodes that make a path down to the target node.
     * @param _root  Known root of the Merkle trie. Used to verify that the included proof is
     *               correctly constructed.
     *
     * @return Whether or not the proof is valid.
     */
    function verifyInclusionProof(
        bytes memory _key,
        bytes memory _value,
        bytes[] memory _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        bytes memory key = _getSecureKey(_key);
        return MerkleTrie.verifyInclusionProof(key, _value, _proof, _root);
    }

    /**
     * @notice Retrieves the value associated with a given key.
     *
     * @param _key   Key to search for, as hex bytes.
     * @param _proof Merkle trie inclusion proof for the key.
     * @param _root  Known root of the Merkle trie.
     *
     * @return Value of the key if it exists.
     */
    function get(
        bytes memory _key,
        bytes[] memory _proof,
        bytes32 _root
    ) internal pure returns (bytes memory) {
        bytes memory key = _getSecureKey(_key);
        return MerkleTrie.get(key, _proof, _root);
    }

    /**
     * @notice Computes the hashed version of the input key.
     *
     * @param _key Key to hash.
     *
     * @return Hashed version of the key.
     */
    function _getSecureKey(bytes memory _key) private pure returns (bytes memory) {
        return abi.encodePacked(keccak256(_key));
    }
}

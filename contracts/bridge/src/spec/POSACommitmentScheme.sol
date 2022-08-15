// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

contract POSACommitmentScheme {
    // keccak256(
    //     "Commitment(uint32 block_number, bytes32 message_root, uint256 nonce)"
    // );
    bytes32 internal constant COMMIT_TYPEHASH = 0x1927575a20e860281e614acf70aa85920a1187ed2fb847ee50d71702e80e2b8f;

    /// The Commitment contains the message_root with block_number that is used for message verify
    /// @param block_number block number for the given commitment
    /// @param message_root Darwnia message root commitment hash
    struct Commitment {
        uint32 block_number;
        bytes32 message_root;
        uint256 nonce;
    }

    function hash(Commitment memory c)
        internal
        pure
        returns (bytes32)
    {
        // Encode and hash the Commitment
        return keccak256(
            abi.encode(
                COMMIT_TYPEHASH,
                c.block_number,
                c.message_root,
                c.nonce
            )
        );
    }
}

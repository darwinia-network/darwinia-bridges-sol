// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "./EcdsaAuthority.sol";
import "../common/MessageVerifier.sol";
import "../../spec/POSACommitmentScheme.sol";

contract POSALightClient is POSACommitmentScheme, MessageVerifier, EcdsaAuthority {
    event MessageRootImported(uint256 block_number, bytes32 message_root);

    // keccak256(
    //     "SignCommitment(bytes32 commitment,uint256 nonce)"
    // );
    bytes32 private constant COMMIT_TYPEHASH = 0x2ea67489b4c8762e92cdf00de12ced5672416d28fa4265cd7fb78ddd61dd3f32;

    uint256 internal latest_block_number;
    bytes32 internal latest_message_root;

    constructor(
        bytes32 _domain_separator,
        address[] memory _relayers,
        uint256 _threshold,
        uint256 _nonce
    ) EcdsaAuthority(_domain_separator, _relayers, _threshold, _nonce) {}

    function block_number() public view returns (uint256) {
        return latest_block_number;
    }

    function message_root() public view override returns (bytes32) {
        return latest_message_root;
    }

    /// @dev Import message commitment which signed by RelayAuthorities
    /// @param commitment contains the message_root with block_number that is used for message verify
    /// @param signatures The signatures of the relayers signed the commitment.
    function import_message_commitment(
        Commitment calldata commitment,
        bytes[] calldata signatures
    ) external payable {
        // Encode and hash the commitment
        bytes32 commitment_hash = hash(commitment);
        _verify_commitment(commitment_hash, signatures);

        require(commitment.block_number > latest_block_number, "!new");
        latest_block_number = commitment.block_number;
        latest_message_root = commitment.message_root;
        emit MessageRootImported(commitment.block_number, commitment.message_root);
    }

    function _verify_commitment(bytes32 commitment_hash, bytes[] memory signatures) internal view {
        bytes32 struct_hash =
            keccak256(
                abi.encode(
                    COMMIT_TYPEHASH,
                    commitment_hash,
                    nonce
                )
            );
        _check_relayer_signatures(struct_hash, signatures);
    }
}
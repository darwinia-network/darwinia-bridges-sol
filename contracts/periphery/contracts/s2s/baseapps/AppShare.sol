// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

abstract contract AppShare {
    // Chain Identifiers
    bytes4 internal constant _DARWINIA_CHAIN_ID = 0x64617277; // darw
    bytes4 internal constant _CRAB_CHAIN_ID = 0x63726162; // crab
    bytes4 internal constant _PANGORO_CHAIN_ID = 0x70616772; // pagr
    bytes4 internal constant _PANGOLIN_CHAIN_ID = 0x7061676c; // pagl
    bytes4 internal constant _PANGOLIN_PARACHAIN_CHAIN_ID = 0x70676c70; // pglp
    bytes4 internal constant _CRAB_PARACHAIN_CHAIN_ID = 0x63726170; // crap

    // Lane Identifiers
    bytes4 internal constant _DARWINIA_CRAB_LANE_ID = 0x00000000;
    bytes4 internal constant _PANGORO_PANGOLIN_LANE_ID = 0x726f6c69; // roli
    bytes4 internal constant _PANGOLIN_PANGOLIN_PARACHAIN_LANE_ID = 0x70616c69; // pali
    bytes4 internal constant _CRAB_CRAB_PARACHAIN_LANE_ID = 0x70616372; // pali
}
// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "../SmartChainApp.sol";
import "@darwinia/contracts-utils/contracts/Scale.types.sol";
import "@darwinia/contracts-utils/contracts/AccountId.sol";

pragma experimental ABIEncoderV2;

// Remote call from Crab SmartChain 
abstract contract CrabApp is SmartChainApp {
    function init() internal {
        bridgeConfigs[DARWINIA_CHAIN_ID] = BridgeConfig(
            0x3003,
            0xe0c938a0fbc88db6078b53e160c7c3ed2edb70953213f33a6ef6b8a5e3ffcab2,
            0xf1501030816118b9129255f5096aa9b296c246acb9b55077390e3ca723a0ca1f
        );

        bridgeConfigs[CRAB_PARACHAIN_CHAIN_ID] = BridgeConfig(
            0x3803,
            0x2158e364c657788d669f15db7687496b2edb70953213f33a6ef6b8a5e3ffcab2,
            0xef3be8173575ddc682e1a72d92ce0b2696c246acb9b55077390e3ca723a0ca1f
        );
    }
}

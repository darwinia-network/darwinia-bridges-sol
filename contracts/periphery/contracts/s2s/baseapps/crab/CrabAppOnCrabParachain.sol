// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "../SmartChainAppOnTarget.sol";

pragma experimental ABIEncoderV2;

abstract contract CrabAppOnCrabParachain is SmartChainAppOnTarget {
    function init() internal {
        srcChainId = CRAB_CHAIN_ID;
        tgtStorageKeyForLastDeliveredNonce = 0xf4e61b17ce395203fe0f3c53a0d39860e5f83cf83f2127eb47afdc35d6e43fab;
    }
}
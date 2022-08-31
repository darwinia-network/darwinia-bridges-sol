// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "../../ds-test/test.sol";
import "./PalletMessageRouter.sol";

import "hardhat/console.sol";

pragma experimental ABIEncoderV2;

contract PalletMessageRouterTest is DSTest {
    function setUp() public {}

    // {
    //     V2: [
    //         {
    //             Transact: {
    //                 originType: SovereignAccount
    //                 requireWeightAtMost: 5,000,000,000
    //                 call: {
    //                     encoded: 0x260000400d03000000000000000000000000000000000000000000000000000000000001004617d470f847ce166019d19a7944049ebb01740000000000000000000000000000000000000000000000000000000000000000001019ff1d2100
    //                 }
    //             }
    //         }
    //     ]
    // }
    //           callIndex	1a01
    //             message	02 04
    //                      06
    //          originType	01
    // requireWeightAtMost	0700f2052a01
    //             encoded	7d01 260000400d03000000000000000000000000000000000000000000000000000000000001004617d470f847ce166019d19a7944049ebb01740000000000000000000000000000000000000000000000000000000000000000001019ff1d2100
    function testEncodeVersionedXcmV2() public {
        bytes memory call = PalletMessageRouter.buildForwardToMoonbeamCall(
            0x1a01,
            hex"260000400d03000000000000000000000000000000000000000000000000000000000001004617d470f847ce166019d19a7944049ebb01740000000000000000000000000000000000000000000000000000000000000000001019ff1d2100"
        );
        assertEq0(
            call,
            hex"1a01020406010700f2052a017d01260000400d03000000000000000000000000000000000000000000000000000000000001004617d470f847ce166019d19a7944049ebb01740000000000000000000000000000000000000000000000000000000000000000001019ff1d2100"
        );
    }
}
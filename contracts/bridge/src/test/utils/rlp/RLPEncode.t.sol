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

import "../../test.sol";
import "../../../utils/rlp/RLPEncode.sol";

contract RLPEncodeTest is DSTest {
    function test_encode_bytes() public {
        assertEq0(
            RLPEncode.writeBytes(hex'deadbeef'),
            hex'84deadbeef'
        );
        assertEq0(
            RLPEncode.writeBytes(hex'0f'),
            hex'0f'
        );
        assertEq0(
            RLPEncode.writeBytes(hex'0400'),
            hex'820400'
        );
    }

    function test_encode_string() public {
        assertEq0(
            RLPEncode.writeString(""),
            hex'80'
        );
        assertEq0(
            RLPEncode.writeString("\u0000"),
            hex"00"
        );
        assertEq0(
            RLPEncode.writeString("\u0001"),
            hex"01"
        );
        assertEq0(
            RLPEncode.writeString("\u007F"),
            hex"7f"
        );
        assertEq0(
            RLPEncode.writeString("dog"),
            hex'83646f67'
        );
        assertEq0(
            RLPEncode.writeString("Lorem ipsum dolor sit amet, consectetur adipisicing eli"),
            hex"b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69"
        );
        assertEq0(
            RLPEncode.writeString("Lorem ipsum dolor sit amet, consectetur adipisicing elit"),
            hex"b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"
        );
        assertEq0(
            RLPEncode.writeString(
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur mauris magna, suscipit sed vehicula non, iaculis faucibus tortor. Proin suscipit ultricies malesuada. Duis tortor elit, dictum quis tristique eu, ultrices at risus. Morbi a est imperdiet mi ullamcorper aliquet suscipit nec lorem. Aenean quis leo mollis, vulputate elit varius, consequat enim. Nulla ultrices turpis justo, et posuere urna consectetur nec. Proin non convallis metus. Donec tempor ipsum in mauris congue sollicitudin. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Suspendisse convallis sem vel massa faucibus, eget lacinia lacus tempor. Nulla quis ultricies purus. Proin auctor rhoncus nibh condimentum mollis. Aliquam consequat enim at metus luctus, a eleifend purus egestas. Curabitur at nibh metus. Nam bibendum, neque at auctor tristique, lorem libero aliquet arcu, non interdum tellus lectus sit amet eros. Cras rhoncus, metus ac ornare cursus, dolor justo ultrices metus, at ullamcorper volutpat"
            ),
            hex"b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d6175726973206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c697320666175636962757320746f72746f722e2050726f696e20737573636970697420756c74726963696573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920612065737420696d70657264696574206d6920756c6c616d636f7270657220616c6971756574207375736369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c2076756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e6120636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d657475732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d697320696e206661756369627573206f726369206c756374757320657420756c74726963657320706f737565726520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e20617563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f72207472697374697175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e74657264756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174"
        );
    }

    function test_encode_address() public {
        assertEq0(
            RLPEncode.writeAddress(0xaa6e07aC6B69723eCAdfe1483A75d72E7740ECDC),
            hex'94aa6e07ac6b69723ecadfe1483a75d72e7740ecdc'
        );
    }

    function test_encode_uint() public {
        assertEq0(
            RLPEncode.writeUint(0),
            hex'80'
        );
        assertEq0(
            RLPEncode.writeUint(1),
            hex"01"
        );
        assertEq0(
            RLPEncode.writeUint(15),
            hex'0f'
        );
        assertEq0(
            RLPEncode.writeUint(16),
            hex"10"
        );
        assertEq0(
            RLPEncode.writeUint(79),
            hex"4f"
        );
        assertEq0(
            RLPEncode.writeUint(127),
            hex"7f"
        );
        assertEq0(
            RLPEncode.writeUint(128),
            hex"8180"
        );
        assertEq0(
            RLPEncode.writeUint(1000),
            hex"8203e8"
        );
        assertEq0(
            RLPEncode.writeUint(1024),
            hex'820400'
        );
        assertEq0(
            RLPEncode.writeUint(100000),
            hex"830186a0"
        );
    }

    function test_encode_bool() public {
        assertEq0(
            RLPEncode.writeBool(true),
            hex'01'
        );
        assertEq0(
            RLPEncode.writeBool(false),
            hex'80'
        );
    }

    function test_encode_list() public {
        assertEq0(RLPEncode.writeList(new bytes[](0)), hex"c0");

        bytes[] memory list = new bytes[](3);
        list[0] = RLPEncode.writeString("dog");
        list[1] = RLPEncode.writeString("god");
        list[2] = RLPEncode.writeString("cat");
        assertEq0(RLPEncode.writeList(list), hex"cc83646f6783676f6483636174");

        bytes[] memory p = new bytes[](1);
        p[0] = RLPEncode.writeBytes(hex'f843a120bb1a6e4ccaed62181ab95a202f4e45c3f9f171ce3aff3cad7b56641d0929f678a0de3ab968a3335494010c90e8741a537971d635808651318a7b752898fd30cdeb');
        bytes memory data = RLPEncode.writeList(p);
        assertEq0(data, hex'f847b845f843a120bb1a6e4ccaed62181ab95a202f4e45c3f9f171ce3aff3cad7b56641d0929f678a0de3ab968a3335494010c90e8741a537971d635808651318a7b752898fd30cdeb');
    }

    function test_encode_list_multiList() external {
        bytes[] memory list = new bytes[](3);
        bytes[] memory list2 = new bytes[](1);
        list2[0] = RLPEncode.writeUint(4);

        list[0] = RLPEncode.writeString("zw");
        list[1] = RLPEncode.writeList(list2);
        list[2] = RLPEncode.writeUint(1);

        assertEq0(RLPEncode.writeList(list), hex"c6827a77c10401");
    }

    function test_encode_list_shortListMax1() external {
        bytes[] memory list = new bytes[](11);
        list[0]  = RLPEncode.writeString("asdf");
        list[1]  = RLPEncode.writeString("qwer");
        list[2]  = RLPEncode.writeString("zxcv");
        list[3]  = RLPEncode.writeString("asdf");
        list[4]  = RLPEncode.writeString("qwer");
        list[5]  = RLPEncode.writeString("zxcv");
        list[6]  = RLPEncode.writeString("asdf");
        list[7]  = RLPEncode.writeString("qwer");
        list[8]  = RLPEncode.writeString("zxcv");
        list[9]  = RLPEncode.writeString("asdf");
        list[10] = RLPEncode.writeString("qwer");

        assertEq0(
            RLPEncode.writeList(list),
            hex"f784617364668471776572847a78637684617364668471776572847a78637684617364668471776572847a78637684617364668471776572"
        );
    }

    function test_encode_list_longlist1() external {
        bytes[] memory list = new bytes[](4);
        bytes[] memory list2 = new bytes[](3);

        list2[0] = RLPEncode.writeString("asdf");
        list2[1] = RLPEncode.writeString("qwer");
        list2[2] = RLPEncode.writeString("zxcv");

        list[0]  = RLPEncode.writeList(list2);
        list[1]  = RLPEncode.writeList(list2);
        list[2]  = RLPEncode.writeList(list2);
        list[3]  = RLPEncode.writeList(list2);

        assertEq0(
            RLPEncode.writeList(list),
            hex"f840cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376"
        );
    }

    function test_encode_list_longlist2() external {
        bytes[] memory list = new bytes[](32);
        bytes[] memory list2 = new bytes[](3);

        list2[0] = RLPEncode.writeString("asdf");
        list2[1] = RLPEncode.writeString("qwer");
        list2[2] = RLPEncode.writeString("zxcv");

        for (uint256 i = 0; i < 32; i++) {
            list[i] = RLPEncode.writeList(list2);
        }

        assertEq0(
            RLPEncode.writeList(list),
            hex"f90200cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376cf84617364668471776572847a786376"
        );
    }

    function test_encode_list_listoflists() external {
        // [ [ [], [] ], [] ]
        bytes[] memory list = new bytes[](2);
        bytes[] memory list2 = new bytes[](2);

        list2[0] = RLPEncode.writeList(new bytes[](0));
        list2[1] = RLPEncode.writeList(new bytes[](0));

        list[0]  = RLPEncode.writeList(list2);
        list[1]  = RLPEncode.writeList(new bytes[](0));

        assertEq0(RLPEncode.writeList(list), hex"c4c2c0c0c0");
    }

    function test_encode_list_listoflists2() external {
        // [ [], [[]], [ [], [[]] ] ]
        bytes[] memory list = new bytes[](3);
        list[0] = RLPEncode.writeList(new bytes[](0));

        bytes[] memory list2 = new bytes[](1);
        list2[0] = RLPEncode.writeList(new bytes[](0));

        list[1] = RLPEncode.writeList(list2);

        bytes[] memory list3 = new bytes[](2);
        list3[0] = RLPEncode.writeList(new bytes[](0));
        list3[1] = RLPEncode.writeList(list2);

        list[2] = RLPEncode.writeList(list3);

        assertEq0(RLPEncode.writeList(list), hex"c7c0c1c0c3c0c1c0");
    }

    function test_encode_list_dictTest1() external {
        bytes[] memory list = new bytes[](4);

        bytes[] memory list1 = new bytes[](2);
        list1[0] = RLPEncode.writeString("key1");
        list1[1] = RLPEncode.writeString("val1");

        bytes[] memory list2 = new bytes[](2);
        list2[0] = RLPEncode.writeString("key2");
        list2[1] = RLPEncode.writeString("val2");

        bytes[] memory list3 = new bytes[](2);
        list3[0] = RLPEncode.writeString("key3");
        list3[1] = RLPEncode.writeString("val3");

        bytes[] memory list4 = new bytes[](2);
        list4[0] = RLPEncode.writeString("key4");
        list4[1] = RLPEncode.writeString("val4");

        list[0] = RLPEncode.writeList(list1);
        list[1] = RLPEncode.writeList(list2);
        list[2] = RLPEncode.writeList(list3);
        list[3] = RLPEncode.writeList(list4);

        assertEq0(
            RLPEncode.writeList(list),
            hex"ecca846b6579318476616c31ca846b6579328476616c32ca846b6579338476616c33ca846b6579348476616c34"
        );
    }
}

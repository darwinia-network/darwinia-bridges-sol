// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "../SmartChainXApp.sol";
import "@darwinia/contracts-utils/contracts/Scale.types.sol";

contract RemarkDemo is SmartChainXApp {
    function remark() public payable {
        // 1. prepare the call that will be executed on the target chain
        System.RemarkCall memory call = System.RemarkCall(
            hex"0001",
            hex"12345678"
        );
        bytes memory callEncoded = System.encodeRemarkCall(call);

        // 2. send the message
        MessagePayload memory payload = MessagePayload(
            1200, // spec version of target chain
            2654000000, // call weight
            callEncoded // call encoded bytes
        );
        sendMessage(
            0, // lane id
            payload, // message payload
            200000000000000000000 // deliveryAndDispatchFee
        );
    }
}

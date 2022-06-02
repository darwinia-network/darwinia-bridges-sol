// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "../SmartChainXApp.sol";
import "@darwinia/contracts-utils/contracts/Ownable.sol";
import "../types/PalletEthereum.sol";

// deploy on the target chain first, then deploy on the source chain
contract TransactDemo is SmartChainXApp, Ownable {
    uint256 public number;

    // source chain ethereum sender address,
    // it will be updated after the app is deployed on the source chain.
    address public senderOfSourceChain;

    constructor() public {
        // Globle settings
        dispatchAddress = 0x0000000000000000000000000000000000000019;
        callIndexOfSendMessage = 0x2b03;
        storageAddress = 0x000000000000000000000000000000000000001a;
        callbackSender = 0x6461722f64766D70000000000000000000000000;
    }

    ///////////////////////////////////////////
    // used on the source chain
    ///////////////////////////////////////////

    function callAddOnTheTargetChain() public payable {
        // 1. prepare the call that will be executed on the target chain
        PalletEthereum.TransactCall memory call = PalletEthereum
            .TransactCall(
                // the call index of substrate_transact
                0x2902,
                // the evm transaction to transact
                PalletEthereum.buildTransactionV2(
                    0, // evm tx nonce, nonce on the target chain + pending nonce on the source chain + 1
                    1000000000, // gasPrice, get from the target chain
                    600000, // gasLimit, get from the target chain
                    0x50275d3F95E0F2FCb2cAb2Ec7A231aE188d7319d, // <------------------ change to the contract address on the target chain
                    0, // value, 0 means no value transfer
                    hex"1003e2d20000000000000000000000000000000000000000000000000000000000000002" // the add function bytes that will be called on the target chain, add(2)
                )
            );
        bytes memory callEncoded = PalletEthereum.encodeTransactCall(
            call
        );

        // 2. send the message
        MessagePayload memory payload = MessagePayload(
            28110, // spec version of target chain <----------- This may be changed, go to https://pangoro.subscan.io/runtime get the latest spec version
            2654000000, // call weight
            callEncoded // call encoded bytes
        );
        uint64 nonce = sendMessage(
            // lane id
            0,
            // storage key for Darwinia market fee
            hex"190d00dd4103825c78f55e5b5dbf8bfe2edb70953213f33a6ef6b8a5e3ffcab2",
            // storage key for the latest nonce of Darwinia message lane
            hex"c9b76e645ba80b6ca47619d64cb5e58d96c246acb9b55077390e3ca723a0ca1f11d2df4e979aa105cf552e9544ebd2b500000000",
            payload // message payload
        );
    }

    function onMessageDelivered(
        bytes4 lane,
        uint64 nonce,
        bool result
    ) external override {
        require(
            msg.sender == callbackSender,
            "Only pallet address is allowed to call 'onMessageDelivered'"
        );
        // TODO: Your code goes here...
    }

    ///////////////////////////////////////////
    // used on the target chain
    ///////////////////////////////////////////

    function add(uint256 _value) public {
        requireSenderOfSourceChain(0, senderOfSourceChain);
        number = number + _value;
    }

    function setSenderOfSourceChain(address _senderOfSourceChain) public onlyOwner {
        senderOfSourceChain = _senderOfSourceChain;
    }
}

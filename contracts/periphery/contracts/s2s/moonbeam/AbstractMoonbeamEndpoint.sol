// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../SmartChainXLib.sol";
import "../types/PalletEthereum.sol";
import "../types/PalletBridgeMessages.sol";
import "../precompiles/moonbeam/XcmTransactorV1.sol";

abstract contract AbstractMoonbeamEndpoint {
    // Remote params
    address public remoteEndpoint;
    uint64 public remoteSmartChainId;
    bytes2 public remoteMessageTransactCallIndex;
    uint64 public remoteWeightPerGas = 40_000; // 1 gas ~= 40_000 weight

    // router params
    bytes2 public routerSendMessageCallIndex;
    bytes4 public routerOutboundLaneId;
    bytes4 public routerParachainId;

    // Local params
    address public feeLocationAddress;
    //   darwinia endpoint addresses
    bytes32 public darwiniaEndpointAccountId32;
    bytes32 public darwiniaEndpointAccountId32Derived;
    address public darwiniaEndpointAddressDerived;

    event TargetInputGenerated(bytes);
    event TargetTransactCallGenerated(bytes);
    event LcmpMessngeGenerated(bytes);

    ///////////////////////////////
    // Outbound
    ///////////////////////////////
    function _remoteExecute(
        uint32 _tgtSpecVersion,
        address _callReceiver,
        bytes calldata _callPayload,
        uint256 _gasLimit,
        //
        uint128 _deliveryAndDispatchFee
    ) internal {
        // solidity call that will be executed on crab smart chain
        bytes memory tgtInput = abi.encodeWithSelector(
            this.execute.selector,
            _callReceiver,
            _callPayload
        );

        emit TargetInputGenerated(tgtInput);

        // transact dispatch call that will be executed on crab chain
        bytes memory tgtTransactCallEncoded = PalletEthereum
            .encodeMessageTransactCall(
                PalletEthereum.MessageTransactCall(
                    remoteMessageTransactCallIndex,
                    PalletEthereum.buildTransactionV2ForMessageTransact(
                        _gasLimit,
                        remoteEndpoint,
                        remoteSmartChainId,
                        tgtInput
                    )
                )
            );

        emit TargetTransactCallGenerated(tgtTransactCallEncoded);

        uint64 tgtTransactCallWeight = uint64(_gasLimit * remoteWeightPerGas);

        // send_message dispatch call that will be executed on crab parachain
        bytes memory message = SmartChainXLib.buildMessage(
            _tgtSpecVersion,
            tgtTransactCallWeight,
            tgtTransactCallEncoded
        );

        emit LcmpMessngeGenerated(message);

        bytes memory routerSendMessageCallEncoded = PalletBridgeMessages
            .encodeSendMessageCall(
                PalletBridgeMessages.SendMessageCall(
                    routerSendMessageCallIndex,
                    routerOutboundLaneId,
                    message,
                    _deliveryAndDispatchFee
                )
            );


        uint64 routerSendMessageCallWeight = uint64(
            1617480000 + (1383867 * (1024 + message.length)) / 1024
        );

        // remote call send_message from moonbeam
        XcmTransactorV1.transactThroughSigned(
            routerParachainId,
            feeLocationAddress,
            routerSendMessageCallWeight,
            routerSendMessageCallEncoded
        );
    }

    ///////////////////////////////
    // Inbound
    ///////////////////////////////
    modifier onlyMessageSender() {
        require(
            darwiniaEndpointAddressDerived == msg.sender,
            "MessageEndpoint: Invalid sender"
        );
        _;
    }

    function execute(address callReceiver, bytes calldata callPayload)
        external
        onlyMessageSender
    {
        if (_executable(callReceiver, callPayload)) {
            (bool success, ) = callReceiver.call(callPayload);
            require(success, "MessageEndpoint: Call execution failed");
        } else {
            revert("MessageEndpoint: Unapproved call");
        }
    }

    // Check if the call can be executed
    function _executable(address callReceiver, bytes calldata callPayload)
        internal
        view
        virtual
        returns (bool);

    ///////////////////////////////
    // Setters
    ///////////////////////////////
    function _setRemoteEndpoint(
        bytes4 _remoteChainId,
        bytes4 _parachainId,
        address _remoteEndpoint
    ) internal {
        remoteEndpoint = _remoteEndpoint;

        (darwiniaEndpointAccountId32, darwiniaEndpointAccountId32Derived, darwiniaEndpointAddressDerived) = SmartChainXLib
            .deriveSenderFromSmartChainOnMoonbeam(
                _remoteChainId,
                _remoteEndpoint,
                _parachainId
            );
    }

    function _setRemoteMessageTransactCallIndex(
        bytes2 _remoteMessageTransactCallIndex
    ) internal {
        remoteMessageTransactCallIndex = _remoteMessageTransactCallIndex;
    }

    function _setRemoteSmartChainId(uint64 _remoteSmartChainId) internal {
        remoteSmartChainId = _remoteSmartChainId;
    }

    function _setRemoteWeightPerGas(uint64 _remoteWeightPerGas) internal {
        remoteWeightPerGas = _remoteWeightPerGas;
    }

    function _setRouterSendMessageCallIndex(bytes2 _routerSendMessageCallIndex)
        internal
    {
        routerSendMessageCallIndex = _routerSendMessageCallIndex;
    }

    function _setRouterOutboundLaneId(bytes4 _routerOutboundLaneId) internal {
        routerOutboundLaneId = _routerOutboundLaneId;
    }

    function _setFeeLocationAddress(address _feeLocationAddress) internal {
        feeLocationAddress = _feeLocationAddress;
    }
}

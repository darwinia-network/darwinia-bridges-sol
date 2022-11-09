// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../RemoteDispatchEndpoint.sol";
import "../Executable.sol";
import "../../SmartChainXLib.sol";
import "../../types/PalletMessageRouter.sol";
import "../../types/XcmTypes.sol";
import "../../types/PalletEthereumXcm.sol";
import "../../types/PalletHelixBridge.sol";

// TODO: AbstractLcmpXcmpDarwiniaEndpoint
// router: darwinia parachain
abstract contract AbstractDarwiniaEndpoint is RemoteDispatchEndpoint, Executable {
    uint8 public constant TARGET_MOONBEAM = 0;
    uint8 public constant TARGET_ASTAR = 1;

    // Target params
    address public targetEndpoint;
    bytes2 public targetMessageTransactCallIndex;

    // router calls
    bytes2 public forwardCallIndex;
    uint64 public forwardCallWeight = 337_239_000;
    bytes2 public issueFromRemoteCallIndex;
    bytes2 public handleIssuingFailureFromRemoteCallIndex;

    event TargetInputGenerated(bytes);
    event TargetTransactCallGenerated(bytes);

    ///////////////////////////////
    // Outbound
    ///////////////////////////////
    function _targetExecute(
        uint32 _routerSpecVersion,
        uint8 _target,
        // target params
        address _callReceiver,
        bytes calldata _callPayload,
        uint256 _gasLimit
    ) internal returns (uint256) {
        bytes memory input = abi.encodeWithSelector(
            this.execute.selector,
            _callReceiver,
            _callPayload
        );

        emit TargetInputGenerated(input);

        // build the TransactCall
        bytes memory tgtTransactCallEncoded = PalletEthereumXcm
            .buildTransactCall(
                targetMessageTransactCallIndex,
                _gasLimit,
                targetEndpoint,
                0,
                input
            );

        emit TargetTransactCallGenerated(tgtTransactCallEncoded);

        // calc requireWeightAtMost
        uint64 requireWeightAtMost = 1_000_000_000_000 / 40_000_000 * uint64(_gasLimit) + 25_000_000;

        // call router.forward
        return
            _forward(
                _routerSpecVersion,
                _target,
                PalletMessageRouter.buildXcmToBeForward(tgtTransactCallEncoded, requireWeightAtMost)
            );
    }

    function _forward(
        uint32 _routerSpecVersion,
        // call params
        uint8 _target,
        XcmTypes.EnumItem_VersionedXcm_V2 memory _message
    ) internal returns (uint256) {
        PalletMessageRouter.ForwardCall
            memory call = PalletMessageRouter.ForwardCall(
                forwardCallIndex,
                _target,
                _message
            );
        bytes memory callEncoded = PalletMessageRouter.encodeForwardCall(
            call
        );

        return
            _remoteDispatch(
                _routerSpecVersion,
                callEncoded,
                forwardCallWeight
            );
    }

    function _issueFromRemote(
        uint32 _routerSpecVersion,
        // call params
        uint128 _value,
        bytes32 _recipient,
        uint64[] memory _burnPrunedMessages,
        uint64 _maxLockPrunedNonce
    ) internal returns (uint256) {
        PalletHelixBridge.IssueFromRemoteCall memory call = PalletHelixBridge
            .IssueFromRemoteCall(
                issueFromRemoteCallIndex,
                _value,
                _recipient,
                _burnPrunedMessages,
                _maxLockPrunedNonce
            );
        bytes memory callEncoded = PalletHelixBridge.encodeIssueFromRemoteCall(
            call
        );

        return
            _remoteDispatch(
                _routerSpecVersion,
                callEncoded,
                100 // TODO: callWeight
            );
    }

    function _handleIssuingFailureFromRemote(
        uint32 _routerSpecVersion,
        // call params
        uint64 _failureNonce,
        uint64[] memory _burnPrunedMessages,
        uint64 _maxLockPrunedNonce
    ) internal returns (uint256) {
        PalletHelixBridge.HandleIssuingFailureFromRemoteCall
            memory call = PalletHelixBridge.HandleIssuingFailureFromRemoteCall(
                handleIssuingFailureFromRemoteCallIndex,
                _failureNonce,
                _burnPrunedMessages,
                _maxLockPrunedNonce
            );
        bytes memory callEncoded = PalletHelixBridge
            .encodeHandleIssuingFailureFromRemoteCall(call);

        return
            _remoteDispatch(
                _routerSpecVersion,
                callEncoded,
                100 // TODO: callWeight
            );
    }

    ///////////////////////////////
    // Inbound
    ///////////////////////////////
    function _setTargetEndpoint(bytes4 _routerChainId, address _targetEndpoint)
        internal
    {
        targetEndpoint = _targetEndpoint;
        derivedMessageSender = SmartChainXLib.deriveSenderFromRemote(
            _routerChainId,
            _targetEndpoint
        );
    }

    ///////////////////////////////
    // Setters
    ///////////////////////////////
    function _setTargetMessageTransactCallIndex(
        bytes2 _targetMessageTransactCallIndex
    ) internal {
        targetMessageTransactCallIndex = _targetMessageTransactCallIndex;
    }

    function _setForwardCallIndex(
        bytes2 _forwardCallIndex
    ) internal {
        forwardCallIndex = _forwardCallIndex;
    }

    function _setForwardCallWeight(
        uint64 _forwardCallWeight
    ) internal {
        forwardCallWeight = _forwardCallWeight;
    }

    function _setIssueFromRemoteCallIndex(
        bytes2 _issueFromRemoteCallIndex
    ) internal {
        issueFromRemoteCallIndex = _issueFromRemoteCallIndex;
    }

    function _setHandleIssuingFailureFromRemoteCallIndex(
        bytes2 _handleIssuingFailureFromRemoteCallIndex
    ) internal {
        handleIssuingFailureFromRemoteCallIndex = _handleIssuingFailureFromRemoteCallIndex;
    }
}
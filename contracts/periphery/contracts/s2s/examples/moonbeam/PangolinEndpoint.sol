// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../endpoints/routing/AbstractDarwiniaEndpoint.sol";

contract PangolinEndpoint is AbstractDarwiniaEndpoint {
    constructor() {
        targetMessageTransactCallIndex = 0x2600;
        forwardCallIndex = 0x1a01;
        dispatchAddress = address(1025);
        sendMessageCallIndex = 0x3f03;
        storageAddress = address(1024);
        storageKeyForMarketFee = 0x39bf2363dd0720bd6e11a4c86f4949322edb70953213f33a6ef6b8a5e3ffcab2;
        storageKeyForLatestNonce = 0xdcdffe6202217f0ecb0ec75d8a09b32c96c246acb9b55077390e3ca723a0ca1f;
        storageKeyForLastDeliveredNonce = 0xdcdffe6202217f0ecb0ec75d8a09b32ce5f83cf83f2127eb47afdc35d6e43fab;
        outboundLaneId = 0x70616c69;
        inboundLaneId = 0x70616c69;
        chainId = 0x7061676c; // pangolin chain id, pagl
    }

    function _approved(address, bytes calldata)
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }

    function targetExecute(
        uint32 _routerSpecVersion,
        address _callReceiver,
        bytes calldata _callPayload,
        uint256 _gasLimit
    ) external payable returns (uint256) {
        return
            _targetExecute(
                _routerSpecVersion,
                TARGET_MOONBEAM,
                _callReceiver,
                _callPayload,
                _gasLimit
            );
    }

    function setTargetEndpoint(bytes4 routerChainId, address targetEndpoint)
        external
    {
        _setTargetEndpoint(routerChainId, targetEndpoint);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

import "@darwinia/contracts-utils/contracts/Scale.types.sol";
import "@darwinia/contracts-utils/contracts/AccountId.sol";

abstract contract SmartChainApp {
    address public constant DISPATCH = 0x0000000000000000000000000000000000000019;

    event DispatchResult(bool success, bytes result);

    receive() external payable {}

    fallback() external {}

    // TODO: 
    //   define constant from palletIndex and laneId
    function sendMessage(bytes2 callIndex, bytes4 laneId, uint256 fee, bytes memory message) internal {
    	// the pricision in contract is 18, and in pallet is 9, transform the fee value
        uint256 feeInPallet = fee/(10**9); 

        // encode send_message call
        BridgeMessages.SendMessageCall memory sendMessageCall = 
            BridgeMessages.SendMessageCall(
                callIndex,
                laneId,
                message,
                uint128(feeInPallet)
            );

        bytes memory sendMessageCallEncoded = 
            BridgeMessages.encodeSendMessageCall(sendMessageCall);
        
        // dispatch the send_message call
        (bool success, bytes memory result) = DISPATCH.call(sendMessageCallEncoded);
        emit DispatchResult(success, result);
    }

    
    function buildMessage(uint32 specVersion, uint64 weight, bytes memory callEncoded) internal returns (bytes memory) {
        Types.EnumItemWithAccountId memory origin = Types.EnumItemWithAccountId(
            2, // index in enum
            AccountId.fromAddress(address(this)) // UserApp contract address
        );

        Types.EnumItemWithNull memory dispatchFeePayment = 
            Types.EnumItemWithNull(0);

        return Types.encodeMessage(
            Types.Message(
                specVersion,
                weight,
                origin,
                dispatchFeePayment,
                callEncoded
            )
        );
    }
}

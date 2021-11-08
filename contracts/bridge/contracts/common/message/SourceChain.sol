// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

contract SourceChain {
    /**
     * The MessagePayload is the structure of DarwiniaRPC which should be delivery to Ethereum-like chain
     * @param sourceAccount The derived DVM address of pallet ID which send the message
     * @param targetContract The targe contract address which receive the message
     * @param laneContract The inbound lane contract address which the message commuting to
     * @param encoded The calldata which encoded by ABI Encoding
     */
    struct MessagePayload {
        address sourceAccount;
        address targetContract;
        address laneContract; //TODO: may not necessary
        bytes encoded; /*abi.encodePacked(SELECTOR, PARAMS)*/
    }

    // Message key (unique message identifier) as it is stored in the storage.
    struct MessageKey {
        // Bridged chain position
        uint256 chain_id;
        // Position of the message lane.
        uint256 lane_id;
        /// Nonce of the message.
        uint256 nonce;
    }

    // Message data as it is stored in the storage.
    struct MessageData {
        // Message payload.
        MessagePayload payload;
        // Message delivery and dispatch fee, paid by the submitter.
        uint256 fee;
    }

    // Message as it is stored in the storage.
    struct Message {
        // Message key.
        MessageKey key;
        // Message data.
        MessageData data;
    }

    // Outbound lane data.
    struct OutboundLaneData {
        // Nonce of the latest message, received by bridged chain.
        uint256 latest_received_nonce;
        // Messages sent through this lane.
        Message[] messages;
    }

    /**
     * Hash of the OutboundLaneData Schema
     * keccak256(abi.encodePacked(
     *     "OutboundLaneData(uint256 latest_received_nonce,bytes32 messages)"
     *     ")"
     * )
     */
    bytes32 internal constant OUTBOUNDLANEDATA_TYPETASH = 0x82446a31771d975201a71d0d87c46edcb4996361ca06e16208c5a001081dee55;

    /**
     * Hash of the Message Schema
     * keccak256(abi.encodePacked(
     *     "Message(MessageKey key,MessageData data)",
     *     "MessageKey(uint256 chain_id,uint256 lane_id,uint256 nonce)",
     *     "MessageData(MessagePayload payload,uint256 fee)",
     *     "MessagePayload(address sourceAccount,address targetContract,address laneContract,bytes encoded)"
     *     ")"
     * )
     */
    bytes32 internal constant MESSAGE_TYPEHASH = 0xbf061c47658829c8b578ca83b92b38baa29739ec8716bc73ff824f1615886a84;

    /**
     * Hash of the MessageKey Schema
     * keccak256(abi.encodePacked(
     *     "MessageKey(uint256 chain_id,uint256 lane_id,uint256 nonce)"
     *     ")"
     * )
     */
    bytes32 internal constant MESSAGEKEY_TYPEHASH = 0x05d847bac0dcd6aa45b1df9d9ad148e9405c0f55df6fea4f2ae4a3d8be54eaaf;

    /**
     * Hash of the MessageData Schema
     * keccak256(abi.encodePacked(
     *     "MessageData(MessagePayload payload,uint256 fee)"
     *     ")"
     * )
     */
    bytes32 internal constant MESSAGEDATA_TYPEHASH = 0xfbb4c6defc088226e5b8f7cf8a93938d3b205761bc122d067088d4ec27f1f04a;

    /**
     * Hash of the MessagePayload Schema
     * keccak256(abi.encodePacked(
     *     "MessagePayload(address sourceAccount,address targetContract,address laneContract,bytes encoded)"
     *     ")"
     * )
     */
    bytes32 internal constant MESSAGEPAYLOAD_TYPEHASH = 0xa2b843d52192ed322a0cda3ca8b407825100c01ffd3676529bc139bc847a12fb;

    function hash(OutboundLaneData memory subLandData)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                OUTBOUNDLANEDATA_TYPETASH,
                subLandData.latest_received_nonce,
                hash(subLandData.messages)
            )
        );
    }

    function hash(Message[] memory msgs)
        internal
        pure
        returns (bytes32)
    {
        bytes memory encoded = abi.encode(msgs.length);
        for (uint256 i = 0; i < msgs.length; i ++) {
            Message memory message = msgs[i];
            encoded = abi.encodePacked(
                encoded,
                abi.encode(
                    MESSAGE_TYPEHASH,
                    hash(message.key),
                    hash(message.data)
                )
            );
        }
        return keccak256(encoded);
    }

    function hash(MessageKey memory key)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                MESSAGEKEY_TYPEHASH,
                key.lane_id,
                key.nonce
            )
        );
    }

    function hash(MessageData memory data)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                MESSAGEDATA_TYPEHASH,
                hash(data.payload),
                data.fee
            )
        );
    }

    function hash(MessagePayload memory payload)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                MESSAGEPAYLOAD_TYPEHASH,
                payload.sourceAccount,
                payload.targetContract,
                payload.laneContract,
                payload.encoded
            )
        );
    }
}
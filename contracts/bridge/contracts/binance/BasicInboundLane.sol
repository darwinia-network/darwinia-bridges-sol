// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "./BasicLane.sol";
import "../interfaces/ICrossChainFilter.sol";

/**
 * @title A entry contract for syncing message from Darwinia to Ethereum-like chain
 * @author echo
 * @notice The basic inbound lane is the message layer of the bridge
 * @dev See https://itering.notion.site/Basic-Message-Channel-c41f0c9e453c478abb68e93f6a067c52
 */
contract BasicInboundLane is BasicLane {
    /**
     * @notice Notifies an observer that the message has dispatched
     * @param nonce The message nonce
     * @param result The message result
     * @param returndata The return data of message call, when return false, it's the reason of the error
     */
    event MessageDispatched(uint256 indexed lanePosition, uint256 indexed nonce, bool indexed result, bytes returndata);
    event MessagePruned(uint256 indexed lanePosition, uint256 indexed nonce);

    /* Constants */

    /**
     * Hash of the OutboundLaneData Schema
     * keccak256(abi.encodePacked(
     *     "OutboundLaneData(uint256 latestReceivedNonce,bytes32 messagesHash)"
     *     ")"
     * )
     */
    bytes32 public constant OUTBOUNDLANEDATA_TYPETASH = 0x54fe6a2dce20f4c0c068b32ba323865c047ce85a18de6aa3a48bbe4fba4c5284;
    /**
     * @dev Gas used per message needs to be less than 100000 wei
     */
    uint256 public constant MAX_GAS_PER_MESSAGE = 100000;
    /**
     * @dev Gas buffer for executing `submit` tx
     */
    uint256 public constant GAS_BUFFER = 60000;

    struct OutboundLaneData {
        uint256 latestReceivedNonce;
        Message[] msgs;
    }

    /* State */

    /**
     * @dev ID of the next message, which is incremented in strict order
     * @notice When upgrading the lane, this value must be synchronized
     */
    uint256 public lastConfirmedNonce;

    uint256 public lastDeliveredNonce;

    // nonce => message
    mapping(uint256 => MessageStorage) messages;

    /**
     * @notice Deploys the BasicInboundLane contract
     * @param _chainPosition The position of the leaf in the `chain_messages_merkle_tree`, index starting with 0
     * @param _lanePosition The position of the leaf in the `lane_messages_merkle_tree`, index starting with 0
     * @param _lightClientBridge The contract address of on-chain light client
     */
    constructor(uint256 _chainPosition, uint256 _lanePosition, uint256 _lastConfirmedNonce, uint256 _lastDeliveredNonce, ILightClientBridge _lightClientBridge) public {
        chainPosition = _chainPosition;
        lanePosition = _lanePosition;
        lastConfirmedNonce = _lastConfirmedNonce;
        lastDeliveredNonce = _lastDeliveredNonce;
        lightClientBridge = _lightClientBridge;
    }

    /* Public Functions */

    /**
     * @notice Deliver and dispatch the messages
     * @param chainCount Number of all chain
     * @param chainMessagesProof The merkle proof required for validation of the messages in the `chain_messages_merkle_tree`
     * @param laneMessagesRoot The merkle root of the lanes, each lane is a leaf constructed by the hash of the messages in the lane
     * @param laneCount Number of all lanes
     * @param laneMessagesProof The merkle proof required for validation of the messages in the `lane_messages_merkle_tree`
     * @param beefyMMRLeaf Beefy MMR leaf which the messages root is located
     * @param beefyMMRLeafIndex Beefy MMR index which the beefy leaf is located
     * @param beefyMMRLeafCount Beefy MMR width of the MMR tree
     * @param peaks The proof required for validation the leaf
     * @param siblings The proof required for validation the leaf
     */
    function receiveMessagesProof(
        OutboundLaneData memory outboundLaneData,
        bytes32 inboundLaneDataHash,
        uint256 chainCount,
        bytes32[] memory chainMessagesProof,
        bytes32 laneMessagesRoot,
        uint256 laneCount,
        bytes32[] memory laneMessagesProof,
        BeefyMMRLeaf memory beefyMMRLeaf,
        uint256 beefyMMRLeafIndex,
        uint256 beefyMMRLeafCount,
        bytes32[] memory peaks,
        bytes32[] memory siblings
    ) public {
        verifyMMRLeaf(beefyMMRLeaf, beefyMMRLeafIndex, beefyMMRLeafCount, peaks, siblings);
        verifyMessages(
            hash(outboundLaneData),
            inboundLaneDataHash,
            beefyMMRLeaf,
            chainCount,
            chainMessagesProof,
            laneMessagesRoot,
            laneCount,
            laneMessagesProof
        );
        // Require there is enough gas to play all messages
        require(
            gasleft() >= outboundLaneData.msgs.length * (MAX_GAS_PER_MESSAGE + GAS_BUFFER),
            "Lane: insufficient gas for delivery of all messages"
        );
        receiveStateUpdate(outboundLaneData.latestReceivedNonce);
        dispatch(outboundLaneData.msgs);
    }

    /* Private Functions */

    function receiveStateUpdate(uint256 latest_received_nonce) internal {
        uint256 last_delivered_nonce = lastDeliveredNonce;
        uint256 last_confirmed_nonce = lastConfirmedNonce;
        require(latest_received_nonce <= last_delivered_nonce, "Lane: invalid received nonce");
        if (latest_received_nonce > last_confirmed_nonce) {
            for (uint256 nonce = last_confirmed_nonce; nonce <= latest_received_nonce; nonce++) {
                pruneMessage(nonce);
            }
            lastConfirmedNonce = latest_received_nonce;
        }
    }

    function pruneMessage(uint256 nonce) internal {
        delete messages[nonce];
        emit MessagePruned(lanePosition, nonce);
    }

    function dispatch(Message[] memory msgs) internal {
        for (uint256 i = 0; i < msgs.length; i++) {
            require(msgs[i].status == Status.ACCEPTED, "Lane: invalid message status");
            MessageInfo memory messageInfo = msgs[i].info;
            uint256 nonce = lastDeliveredNonce + 1;
            if (messageInfo.nonce < nonce) {
                continue;
            }
            // Check message nonce is correct and increment nonce for replay protection
            require(messageInfo.nonce == nonce, "Lane: invalid nonce");
            require(messageInfo.laneContract == address(this), "Lane: invalid lane contract");

            lastDeliveredNonce = nonce;

            bool success = false;
            bytes memory returndata;

            /**
             * @notice The app layer must implement the interface `ICrossChainFilter`
             */
            try ICrossChainFilter(messageInfo.targetContract).crossChainFilter(messageInfo.sourceAccount, messageInfo.payload)
                returns (bool ok)
            {
                if (ok) {
                    // Deliver the message to the target
                    (success, returndata) =
                        messageInfo.targetContract.call{value: 0, gas: MAX_GAS_PER_MESSAGE}(
                            messageInfo.payload
                    );
                } else {
                    success = false;
                    returndata = "Lane: filter failed";
                }
            } catch (bytes memory reason) {
                success = false;
                returndata = reason;
            }

            messages[nonce] = MessageStorage({
                status: Status.DISPATCHED,
                infoHash: hash(messageInfo),
                dispatchResult: success
            });
            emit MessageDispatched(lanePosition, messageInfo.nonce, success, returndata);
        }
    }

    function hash(OutboundLaneData memory outboundLaneData)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
                    abi.encode(
                        OUTBOUNDLANEDATA_TYPETASH,
                        outboundLaneData.latestReceivedNonce,
                        hash(outboundLaneData.msgs)
                    )
                );
    }
}

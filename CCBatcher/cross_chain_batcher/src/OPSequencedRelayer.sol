// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {IL2ToL2CrossDomainMessenger} from
    "lib/optimism/packages/contracts-bedrock/src/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {Predeploys} from "lib/optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";
import {Unauthorized} from "lib/optimism/packages/contracts-bedrock/src/libraries/errors/CommonErrors.sol";
import {SafeCall} from "lib/optimism/packages/contracts-bedrock/src/libraries/SafeCall.sol";

/// @notice SequencedRelayer is a helper contract that works on top of Optimism
/// interoperability protocol to allow sequencing several executing messages by
/// specifying message dependency for each executing message.
/// The squenced messages are guaranteed to be executed in the correct order.
/// SequencedRelayer can be used to trustlessly pay the relayer for executing
/// cross-chain messages.
/// To work correctly, SequencedRelayer must be deployed with the same address on
/// all supported chains.
contract OPSequencedRelayer {
    /// @notice Thrown when attempting to send a message to the chain that the message is being sent from.
    error MessageDestinationSameChain();

    /// @notice Thrown when attempting to relay a message whose target is CrossL2Inbox.
    error MessageTargetCrossL2Inbox();

    /// @notice Thrown when attempting to relay a message whose target is L2ToL2CrossDomainMessenger.
    error MessageTargetL2ToL2CrossDomainMessenger();

    /// @notice Thrown when attempting to relay a message whose target is OPSequencedRelayer.
    error MessageTargetSequencedRelayer();

    /// @notice Thrown when attempting to relay a message and the cross domain message sender is not the
    /// OPSequencedRelayer.
    error InvalidCrossDomainSender();

    /// @notice Thrown when attemptring to relay a sequence message with a not yet relayed sequence dependency.
    error SequenceDependencyNotRelayed();

    /// @notice Emitted whenever a sequence entry is sent.
    /// @param destination  Chain ID of the destination chain
    /// @param target       Target contract or wallet address.
    /// @param prevMsgHash  Message hash of the previous message in the sequence that the
    ///                     current sequence entry depends on. Can be zero to indicate the first entry in the sequence.
    /// @param message      Message payload to call target with.
    event SentSequenceEntry(
        uint256 indexed destination, address indexed target, bytes32 indexed prevMsgHash, bytes message
    );

    /// @notice Emitted whenever a sequence entry is successfully relayed on this chain.
    /// @param source       Chain ID of the source chain
    /// @param prevMsgHash  Message hash of the previous message in the sequence that the
    ///                     current sequence entry depends on. Can be zero to indicate the first entry in the sequence.
    /// @param message      Message payload to call target with.
    event RelayedSequenceEntry(uint256 indexed source, bytes32 indexed prevMsgHash, bytes message);

    /// @notice Emitted whenever a sequence entry fails to be relayed on this chain.
    /// @param source       Chain ID of the source chain
    /// @param prevMsgHash  Message hash of the previous message in the sequence that the
    ///                     current sequence entry depends on. Can be zero to indicate the first entry in the sequence.
    /// @param message      Message payload to call target with.
    event FailedRelayedSequenceEntry(uint256 indexed source, bytes32 indexed prevMsgHash, bytes message);

    IL2ToL2CrossDomainMessenger internal constant MESSENGER =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    /// @notice Sends a message to some target address on a destination chain. The message can be executed on
    /// the executing chain only after a message with the given hash was successfully relayed.
    /// @param _chainId     Chain ID of the destination chain.
    /// @param _target      Target contract or wallet address.
    /// @param _prevMsgHash Message hash of the previous message in the sequence that the
    ///                     current sequence entry depends on. Can be zero to indicate the first entry in the sequence.
    /// @param _message     Message to trigger the target address with.
    /// @return msgHash_    The hash of the message being sent, which can be used for tracking whether
    ///                     the message has successfully been relayed.
    function sendSequenceEntry(uint256 _chainId, address _target, bytes32 _prevMsgHash, bytes calldata _message)
        external
        returns (bytes32 msgHash_)
    {
        // repeating sanity checks from L2ToL2CrossDomainMessenger
        if (_chainId == block.chainid) revert MessageDestinationSameChain();
        if (_target == Predeploys.CROSS_L2_INBOX) revert MessageTargetCrossL2Inbox();
        if (_target == Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER) revert MessageTargetL2ToL2CrossDomainMessenger();
        if (_target == address(this)) revert MessageTargetSequencedRelayer();

        bytes memory ccMessage = abi.encodeCall(this.relaySequenceEntry, (_target, _prevMsgHash, _message));
        msgHash_ = MESSENGER.sendMessage(_chainId, address(this), ccMessage);

        emit SentSequenceEntry(_chainId, _target, _prevMsgHash, _message);
    }

    /// @notice Relays the message that was sent by other OPSequencedRelayer. Can be successful
    /// only after a message with the given hash was successfully relayed before.
    /// @param _target      Target contract or wallet address.
    /// @param _prevMsgHash Message hash of the previous message in the sequence that the
    ///                     current sequence entry depends on. Can be zero to indicate the first entry in the sequence.
    /// @param _message     Message to trigger the target address with.
    function relaySequenceEntry(address _target, bytes32 _prevMsgHash, bytes calldata _message) external {
        if (msg.sender != address(MESSENGER)) revert Unauthorized();

        if (MESSENGER.crossDomainMessageSender() != address(this)) revert InvalidCrossDomainSender();

        if (_prevMsgHash != 0 && !MESSENGER.successfulMessages(_prevMsgHash)) revert SequenceDependencyNotRelayed();

        bool success = SafeCall.call(_target, 0, _message);
        uint256 source = MESSENGER.crossDomainMessageSource();

        if (success) {
            emit RelayedSequenceEntry(source, _prevMsgHash, _message);
        } else {
            emit FailedRelayedSequenceEntry(source, _prevMsgHash, _message);
        }
    }
}

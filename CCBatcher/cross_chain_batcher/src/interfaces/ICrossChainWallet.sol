// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import {IL2ToL2CrossDomainMessenger} from
    "lib/optimism/packages/contracts-bedrock/src/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";

interface ICrossChainWallet {
    /**
     * Getter to get L2ToL2CrossDomainMessenger instance that relays messages for this ICrossChainWallet.
     */
    function crossDomainMessenger() external returns (IL2ToL2CrossDomainMessenger messenger);

    /**
     * Sends a cross chain transaction to be executed in another ICrossChainWallet deployed on a
     * different chain. Emits a cross chain message that executes the transaction on the other
     * chain once relayed. Relaying of the sent message can depend on other cross-chain messages
     * being successfully relayed before.
     *
     * @dev Must be called by a verified user owner (e.g. from a known EOA or a user operation with
     * a verified signature).
     * @param _chainId          Chain ID of the target chain where the transaction should be executed.
     * @param _dest             Address of the target contract to be called in the transaction.
     * @param _value            ETH value associated with the transaction call.
     * @param _calldata         Calldata to be passed to the transaction call.
     * @param _prevMsgHashes    Array of message hashes on which the execution of the transaction depends.
     *                          All messages with hashes on this array must be successfully relayed before
     *                          this cross chain trs can be relayed.
     */
    function sendCrossChainTrx(
        uint256 _chainId,
        address _dest,
        uint256 _value,
        bytes calldata _calldata,
        bytes32[] calldata _prevMsgHashes
    ) external returns (bytes32 msgHash);

    /**
     * Relays the message that was sent by another ICrossChainWallet. The relaying of the message
     * should initiate a transaction call
     *
     * @dev Must be called from IL2ToL2CrossDomainMessenger. Must check that the initial message
     * sender is another instance of the same ICrossChainWallet.
     * @param _dest             Address of the target contract to be called in the transaction.
     * @param _value            ETH value associated with the transaction call.
     * @param _calldata         Calldata to be passed to the transaction call.
     * @param _prevMsgHashes    Array of message hashes on which the execution of the transaction depends.
     *                          All messages with hashes on this array must be successfully relayed before
     *                          this cross chain trs can be relayed.
     */
    function relayCrossChainTrx(
        address _dest,
        uint256 _value,
        bytes calldata _calldata,
        bytes32[] calldata _prevMsgHashes
    ) external;
}

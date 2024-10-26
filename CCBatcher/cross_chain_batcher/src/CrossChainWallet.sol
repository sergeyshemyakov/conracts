// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import {ICrossChainWallet} from "./interfaces/ICrossChainWallet.sol";
import {Predeploys} from "lib/optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";
import {IL2ToL2CrossDomainMessenger} from
    "lib/optimism/packages/contracts-bedrock/src/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {SuperchainTokenBridge} from "lib/optimism/packages/contracts-bedrock/src/L2/SuperchainTokenBridge.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";

/**
 * Simple implementation of Cross Chain Wallet. Allows sending single cross chain transaction. Supports relayer
 * incintivization via ERC20 token tips.
 */
contract CrossChainWallet is ICrossChainWallet {
    IL2ToL2CrossDomainMessenger internal constant MESSENGER =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
    SuperchainTokenBridge BRIDGE = SuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE);

    address immutable OWNER;
    uint256 public testFlag;
    address public lastRelayer;

    modifier dependsOnMessages(bytes32[] calldata _prevMsgHashes) {
        for (uint256 i = 0; i < _prevMsgHashes.length; ++i) {
            require(_prevMsgHashes[i] == 0 || MESSENGER.successfulMessages(_prevMsgHashes[i]));
        }
        _;
    }

    modifier onlyFromMessenger() {
        require(msg.sender == address(MESSENGER), "Not from L2ToL2CrossDomainMessenger");
        _;
    }

    modifier onlyFromAnotherCrossChainInstance() {
        require(MESSENGER.crossDomainMessageSender() == address(this), "Wrong message source on the other chain");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "Can be called only by wallet owner");
        _;
    }

    constructor() {
        // OWNER = msg.sender;
        OWNER = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    }

    function crossDomainMessenger() external pure returns (IL2ToL2CrossDomainMessenger messenger) {
        return MESSENGER;
    }

    /// @inheritdoc ICrossChainWallet
    function sendCrossChainTrx(
        uint256 _chainId,
        address _dest,
        uint256 _value,
        bytes calldata _calldata,
        bytes32[] calldata _prevMsgHashes
    ) external onlyOwner returns (bytes32 msgHash) {
        bytes memory _message = abi.encodeCall(this.relayCrossChainTrx, (_dest, _value, _calldata, _prevMsgHashes));
        msgHash = MESSENGER.sendMessage(_chainId, address(this), _message);
    }

    /**
     * Sends a cross chain transaction together with a tip for relayer. The tip is paid by sender on the sending chain
     * and received by relayer on the receiving chain. Tip can be paid in any ERC20 token, however token address
     * must be the same on sending and receiving chains.
     * Relayer can claim the tip only after the executing transaction is successfully relayed.
     *
     * @param _chainId          Chain ID of the target chain where the transaction should be executed.
     * @param _dest             Address of the target contract to be called in the transaction.
     * @param _value            ETH value associated with the transaction call.
     * @param _calldata         Calldata to be passed to the transaction call.
     * @param _token            Address of the ERC20 token to pay tip.
     * @param _tip              Amount of tip to be paid to relayer.
     */
    function sendCrossChainTrxWithTip(
        uint256 _chainId,
        address _dest,
        uint256 _value,
        bytes calldata _calldata,
        address _token,
        uint256 _tip
    ) external onlyOwner {
        bytes32 _msgHash1 = BRIDGE.sendERC20(_token, address(this), _tip, _chainId);
        bytes32[] memory _msgHashes = new bytes32[](2);
        _msgHashes[0] = _msgHash1;
        bytes memory _message1 = abi.encodeCall(this.relayCrossChainTrx, (_dest, _value, _calldata, new bytes32[](0)));
        bytes32 _msgHash2 = MESSENGER.sendMessage(_chainId, address(this), _message1);
        _msgHashes[1] = _msgHash2;
        bytes memory _message2 = abi.encodeCall(this.relayTipRelayer, (_token, _tip, _msgHashes));
        MESSENGER.sendMessage(_chainId, address(this), _message2);
    }

    /**
     * Test function to send a message cross-chain. Sets the flag to 1 on the sending chain.
     * Pays no relayer tip and sends only one cross-chain message.
     */
    function sendSetTestFlag(uint256 _chainId) external {
        testFlag = 1;
        bytes memory _message = abi.encodeCall(this.relaySetTestFlag, ());
        MESSENGER.sendMessage(_chainId, address(this), _message);
    }

    function sendSetTestFlagWithTip(uint256 _chainId, address _token, uint256 _tip) external {
        testFlag = 3;
        bytes32 _msgHash1 = BRIDGE.sendERC20(_token, address(this), _tip, _chainId);
        bytes32[] memory _msgHashes = new bytes32[](2);
        _msgHashes[0] = _msgHash1;
        bytes memory _message1 = abi.encodeCall(this.relaySetTestFlag, ());
        bytes32 _msgHash2 = MESSENGER.sendMessage(_chainId, address(this), _message1);
        _msgHashes[1] = _msgHash2;
        bytes memory _message2 = abi.encodeCall(this.relayTipRelayer, (_token, _tip, _msgHashes));
        MESSENGER.sendMessage(_chainId, address(this), _message2);
    }

    /**
     * Test function to be called cross-chain. Once executed succesfully, sets test flag to 2.
     * Does not depend on any other messages. Pays no relayer tip.
     */
    function relaySetTestFlag() external onlyFromAnotherCrossChainInstance onlyFromMessenger {
        testFlag = 2;
        lastRelayer = tx.origin;
    }

    /// @inheritdoc ICrossChainWallet
    function relayCrossChainTrx(
        address _dest,
        uint256 _value,
        bytes calldata _calldata,
        bytes32[] calldata _prevMsgHashes
    ) external dependsOnMessages(_prevMsgHashes) onlyFromAnotherCrossChainInstance onlyFromMessenger {
        _call(_dest, _value, _calldata);
    }

    /**
     * Function to pay relayer tip after receiving corresponding cross chain message. Requires messages
     * with given message hash to be succesfully relayed before.
     *
     * @param _token            Address of the ERC20 token to pay tip.
     * @param _tip              Amount of tip to be paid to relayer.
     * @param _prevMsgHashes    Array of message hashes on which the execution of the transaction depends.
     *                          All messages with hashes on this array must be successfully relayed before
     *                          this cross chain trs can be relayed.
     */
    function relayTipRelayer(address _token, uint256 _tip, bytes32[] calldata _prevMsgHashes)
        external
        dependsOnMessages(_prevMsgHashes)
        onlyFromAnotherCrossChainInstance
        onlyFromMessenger
    {
        IERC20(_token).transfer(tx.origin, _tip);
        lastRelayer = tx.origin;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}

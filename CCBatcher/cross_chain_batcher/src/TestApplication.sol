// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import {IL2ToL2CrossDomainMessenger} from
    "lib/optimism/packages/contracts-bedrock/src/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {SuperchainTokenBridge} from "lib/optimism/packages/contracts-bedrock/src/L2/SuperchainTokenBridge.sol";
import {Predeploys} from "lib/optimism/packages/contracts-bedrock/src/libraries/Predeploys.sol";
import {IERC20} from "lib/forge-std/src/interfaces/IERC20.sol";

contract TestApplication {
    modifier dependsOnMessage(bytes32 _prevMsgHash) {
        require(_prevMsgHash == 0 || MESSENGER.successfulMessages(_prevMsgHash));
        _;
    }

    IL2ToL2CrossDomainMessenger internal constant MESSENGER =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);
    SuperchainTokenBridge BRIDGE = SuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE);

    function sendERC20WithTip(address _token, address _to, uint256 _amount, uint256 _chainId, uint256 _tip)
        external
        returns (bytes32 msgHash)
    {
        require(_amount > _tip, "Total amount must be bigger than tip");

        bytes32 _msgHash = BRIDGE.sendERC20(_token, _to, _amount, _chainId);
        bytes memory _message = abi.encodeCall(this.relayERC20WithTip, (_token, _to, _amount, _tip, _msgHash));
        msgHash = MESSENGER.sendMessage(_chainId, address(this), _message);
    }

    function relayERC20WithTip(address _token, address _to, uint256 _amount, uint256 _tip, bytes32 _prevMsgHash)
        external
        dependsOnMessage(_prevMsgHash)
    {
        require(msg.sender == address(MESSENGER), "Not from sequenced relayer");
        require(MESSENGER.crossDomainMessageSender() == address(this), "Wrong message source on the other chain");

        IERC20 erc20 = IERC20(_token);
        erc20.transfer(_to, _amount - _tip);
        erc20.transfer(tx.origin, _tip);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {CrossChainWallet} from "../src/CrossChainWallet.sol";

// 0x7c840Bf42d848A97D59168e6C0CAA95E5464835d
contract CrossChainWalletScript is Script {
    function run() public {
        // Deployer's private key. Owner of the Claim contract which can perform upgrades. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        bytes32 salt = keccak256("random shit");

        // deploy L2Claim Implementation Contract
        vm.startBroadcast(deployerPrivateKey);
        CrossChainWallet wallet = new CrossChainWallet{salt: salt}();
        console2.log("Address of the deployed cross chain wallet: %s", address(wallet));

        vm.stopBroadcast();
        assert(address(wallet) != address(0));
    }
}

// cast call 0x6B48c8134760B85637872D3dedD6DdfDa467037D "testFlag()(uint256)" --rpc-url http://127.0.0.1:9545
// cast send 0x6B48c8134760B85637872D3dedD6DdfDa467037D "sendSetTestFlag(uint256)()" 902 --rpc-url http://127.0.0.1:9545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// cast call 0x6B48c8134760B85637872D3dedD6DdfDa467037D "lastRelayer()(address)" --rpc-url http://127.0.0.1:9546
// cast send 0x420beeF000000000000000000000000000000001 "mint(address _to, uint256 _amount)"  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1000  --rpc-url http://127.0.0.1:9545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// cast send 0x420beeF000000000000000000000000000000001 "transfer(address,uint256)(bool)" 0x6B48c8134760B85637872D3dedD6DdfDa467037D 500 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://127.0.0.1:9545
// cast call 0x420beeF000000000000000000000000000000001 "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://127.0.0.1:9545
// cast send 0x6B48c8134760B85637872D3dedD6DdfDa467037D "sendSetTestFlagWithTip(uint256,address,uint256)()" 902 0x420beeF000000000000000000000000000000001 250 --rpc-url http://127.0.0.1:9545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
// cast call 0x6B48c8134760B85637872D3dedD6DdfDa467037D "testFlag()(uint256)" --rpc-url http://127.0.0.1:9545
// cast call 0x420beeF000000000000000000000000000000001 "balanceOf(address)(uint256)" 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 --rpc-url http://127.0.0.1:9546

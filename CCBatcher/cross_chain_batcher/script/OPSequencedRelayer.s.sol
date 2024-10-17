// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25;

import {Script, console2} from "forge-std/Script.sol";
import {OPSequencedRelayer} from "../src/OPSequencedRelayer.sol";
import {TestApplication} from "../src/TestApplication.sol";

// 0xBf5B4875eE1F6f67aBD736f6801526d86409601a
contract SequencedRelayerScript is Script {
    function run() public {
        // Deployer's private key. Owner of the Claim contract which can perform upgrades. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        bytes32 salt = keccak256("random shit");

        // deploy L2Claim Implementation Contract
        vm.startBroadcast(deployerPrivateKey);
        OPSequencedRelayer relayer = new OPSequencedRelayer{salt: salt}();
        console2.log("Address of the deployed relayer: %s", address(relayer));
        TestApplication app = new TestApplication{salt: salt}();
        console2.log("Address of the deployed test app: %s", address(app));

        vm.stopBroadcast();
        assert(address(relayer) != address(0));
    }
}

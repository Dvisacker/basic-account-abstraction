// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SmartAccount} from "src/SmartAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract Deployer is Script {
    function run() public {}

    function deploySmartAccount() public returns (HelperConfig, SmartAccount, IERC20) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        SmartAccount smartAccount = new SmartAccount(config.entryPoint);
        IERC20 usdc = new ERC20Mock();
        smartAccount.transferOwnership(config.account);
        vm.stopBroadcast();

        console.log("Smart Account address: ", address(smartAccount));
        console.log("Smart Account owner: ", smartAccount.owner());
        console.log("USDC address: ", address(usdc));
        console.log("Entry Point address: ", config.entryPoint);

        return (helperConfig, smartAccount, usdc);
    }
}

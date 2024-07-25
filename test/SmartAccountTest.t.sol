// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {SmartAccount} from "src/SmartAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Deployer} from "script/Deployer.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract SmartAccountTest is Test {
    SmartAccount public smartAccount;
    IEntryPoint public entryPoint;
    HelperConfig public helperConfig;
    SendPackedUserOp public sendPackedUserOp;
    IERC20 public usdc;

    address node = address(0x1);
    address hacker = address(0x2);

    uint256 public constant AMOUNT = 1e18;

    function setUp() public {
        Deployer deployer = new Deployer();
        (helperConfig, smartAccount, usdc) = deployer.deploySmartAccount();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entryPoint = IEntryPoint(config.entryPoint);
    }

    function testOwnerCanExecute() public {
        assertEq(usdc.balanceOf(address(smartAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(smartAccount), 1000);

        vm.prank(smartAccount.owner());
        smartAccount.execute(dest, value, functionData);

        assertEq(usdc.balanceOf(address(smartAccount)), 1000);
    }

    function testNonOwnerCannotExecute() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(smartAccount), 1000);

        vm.prank(hacker);
        vm.expectRevert();
        smartAccount.execute(dest, value, functionData);
    }

    function testValidateUserOp() public {
        address dest = address(usdc);
        uint256 value = 0;
        sendPackedUserOp = new SendPackedUserOp();
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(smartAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(SmartAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory op = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(smartAccount)
        );
        bytes32 userOpHash = entryPoint.getUserOpHash(op);
        uint256 missingAccountFunds = AMOUNT;

        vm.prank(address(entryPoint));
        uint256 validationData = smartAccount.validateUserOp(op, userOpHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntrypointCanSendSignedOp() public {
        address dest = address(usdc);
        uint256 value = 0;
        sendPackedUserOp = new SendPackedUserOp();
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(smartAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(SmartAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory op = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(smartAccount)
        );

        vm.deal(address(smartAccount), AMOUNT);
        vm.prank(node);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, payable(node));
        assertEq(usdc.balanceOf(address(smartAccount)), AMOUNT);
    }
}

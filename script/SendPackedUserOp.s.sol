// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SmartAccount} from "src/SmartAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
// import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    // function run() public {
    //     HelperConfig helperConfig = new HelperConfig();
    //     HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    //     address dest = helperConfig.getConfig().usdc;
    //     uint256 value = 0;
    //     address minimalAccountAddress =
    // }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory op = _generateSignedUserOp(callData, minimalAccount, nonce);
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(op);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        op.signature = abi.encodePacked(r, s, v);
        return op;
    }

    function _generateSignedUserOp(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}

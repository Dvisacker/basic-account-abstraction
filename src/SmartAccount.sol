// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "forge-std/console.sol";

contract SmartAccount is IAccount, Ownable {
    IEntryPoint private immutable i_entryPoint;

    error SmartAccount__Unauthorized();
    error SmartAccount__CallFailed();

    // Functions

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    // Modifiers

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert SmartAccount__Unauthorized();
        }
        _;
    }

    modifier requireFromOwnerOrEntryPoint() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert SmartAccount__Unauthorized();
        }
        _;
    }

    // external functions

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromOwnerOrEntryPoint {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert SmartAccount__CallFailed();
        }
    }

    // internal functions

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 eip191Hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(eip191Hash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    // Getters

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}

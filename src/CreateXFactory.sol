// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ICreateXFactory} from "./ICreateXFactory.sol";
import {CreateX} from "./CreateX.sol";

/// @title CreateXFactory
/// @notice A factory contract that provides a unified interface for deploying contracts using various creation patterns
/// @dev Supported deployment methods:
///      - CREATE: Traditional deployment
///      - CREATE2: Deterministic deployment
///      - CREATE3: Chain-agnostic deployment
///      - EIP-1167: Minimal proxy & Deterministic minimal proxy
/// @author fomoweth
contract CreateXFactory is ICreateXFactory {
    /// @notice Ensures that the first 20 bytes of submitted salt match either the caller or the zero address
    modifier ensure(bytes32 salt) {
        assembly ("memory-safe") {
            if iszero(or(iszero(shr(0x60, salt)), eq(shr(0x60, salt), caller()))) {
                mstore(0x00, 0x81e69d9b) // InvalidSalt()
                revert(0x1c, 0x04)
            }
        }
        _;
    }

    /// @inheritdoc ICreateXFactory
    function createX(CreationType creationType, bytes calldata initCode, bytes32 salt)
        external
        payable
        returns (address)
    {
        if (creationType == CreationType.CREATE) {
            return create(initCode);
        } else if (creationType == CreationType.CREATE2) {
            return create2(initCode, salt);
        } else if (creationType == CreationType.CREATE3) {
            return create3(initCode, salt);
        } else if (creationType == CreationType.Clone) {
            // For Clone type, interpret first 20 bytes of initCode as implementation address
            return clone(address(bytes20(initCode[:20])));
        } else if (creationType == CreationType.CloneDeterministic) {
            // For CloneDeterministic type, interpret first 20 bytes of initCode as implementation address
            return cloneDeterministic(address(bytes20(initCode[:20])), salt);
        } else {
            revert InvalidCreationType();
        }
    }

    /// @inheritdoc ICreateXFactory
    function create(bytes calldata initCode) public payable returns (address instance) {
        emit ContractCreation(instance = CreateX.create(initCode, msg.value), msg.sender);
    }

    /// @inheritdoc ICreateXFactory
    function create2(bytes calldata initCode, bytes32 salt) public payable ensure(salt) returns (address instance) {
        emit ContractCreation(instance = CreateX.create2(initCode, salt, msg.value), msg.sender, salt);
    }

    /// @inheritdoc ICreateXFactory
    function create3(bytes calldata initCode, bytes32 salt) public payable ensure(salt) returns (address instance) {
        emit ContractCreation(instance = CreateX.create3(initCode, salt, msg.value), msg.sender, salt);
    }

    /// @inheritdoc ICreateXFactory
    function clone(address implementation) public payable returns (address instance) {
        emit ContractCreation(instance = CreateX.clone(implementation, msg.value), msg.sender);
    }

    /// @inheritdoc ICreateXFactory
    function cloneDeterministic(address implementation, bytes32 salt)
        public
        payable
        ensure(salt)
        returns (address instance)
    {
        emit ContractCreation(instance = CreateX.cloneDeterministic(implementation, salt, msg.value), msg.sender, salt);
    }

    /// @inheritdoc ICreateXFactory
    function computeCreateXAddress(CreationType creationType, bytes32 initCodeHash, bytes32 salt)
        external
        view
        returns (address)
    {
        if (creationType == CreationType.CREATE || creationType == CreationType.Clone) {
            // For CREATE and Clone types, treat salt parameter as nonce
            return computeCreateAddress(uint256(salt));
        } else if (creationType == CreationType.CREATE2) {
            return computeCreate2Address(initCodeHash, salt);
        } else if (creationType == CreationType.CREATE3) {
            return computeCreate3Address(salt);
        } else if (creationType == CreationType.CloneDeterministic) {
            // For CloneDeterministic, interpret initCodeHash as implementation address
            return computeCloneDeterministicAddress(address(bytes20(initCodeHash)), salt);
        } else {
            revert InvalidCreationType();
        }
    }

    /// @inheritdoc ICreateXFactory
    function computeCreateAddress(uint256 nonce) public view returns (address) {
        return CreateX.computeCreateAddress(nonce);
    }

    /// @inheritdoc ICreateXFactory
    function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) public view returns (address) {
        return CreateX.computeCreate2Address(initCodeHash, salt);
    }

    /// @inheritdoc ICreateXFactory
    function computeCreate3Address(bytes32 salt) public view returns (address) {
        return CreateX.computeCreate3Address(salt);
    }

    /// @inheritdoc ICreateXFactory
    function computeCloneDeterministicAddress(address implementation, bytes32 salt) public view returns (address) {
        return CreateX.computeCloneDeterministicAddress(implementation, salt);
    }
}

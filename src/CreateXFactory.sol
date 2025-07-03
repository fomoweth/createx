// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ICreateXFactory} from "src/interfaces/ICreateXFactory.sol";
import {CreateX} from "./CreateX.sol";

/// @title CreateXFactory
/// @notice A factory contract that provides unified interface for deploying contracts using various creation patterns
/// @dev This factory consolidates different deployment strategies into a single interface
///      Supported deployment methods:
///      - CREATE: Traditional deployment
///      - CREATE2: Deterministic deployment
///      - CREATE3: Chain-agnostic deployment
///      - EIP-1167: Minimal proxy & Deterministic minimal proxy
/// @author fomoweth
contract CreateXFactory is ICreateXFactory {
	/// @notice Constants defining creation types for different deployment patterns
	uint256 internal constant CREATION_TYPE_CREATE = 1; // Standard CREATE opcode
	uint256 internal constant CREATION_TYPE_CREATE2 = 2; // CREATE2 with salt
	uint256 internal constant CREATION_TYPE_CREATE3 = 3; // CREATE3 via proxy
	uint256 internal constant CREATION_TYPE_CLONE = 4; // EIP-1167 minimal proxy with CREATE
	uint256 internal constant CREATION_TYPE_CLONE_DETERMINISTIC = 5; // EIP-1167 minimal proxy with CREATE2

	/// @notice Constants defining salt processing modes
	uint256 internal constant MODE_RAW = 0; // Use original salt without modification
	uint256 internal constant MODE_GUARDED = 1; // Automatically generate secure salt
	uint256 internal constant MODE_STRICT = 2; // Enforce strict salt format validation

	/// @notice Constants defining guard levels applied when MODE ≠ RAW
	uint256 internal constant GUARD_NONE = 0; // No protection
	uint256 internal constant GUARD_CALLER = 1; // Protect with caller address
	uint256 internal constant GUARD_CHAIN = 2; // Protect with chain ID
	uint256 internal constant GUARD_CALLER_AND_CHAIN = 3; // Protect with caller address and chain ID

	/// @inheritdoc ICreateXFactory
	function deployCreateX(
		CreationType creationType,
		bytes calldata initCode,
		bytes32 salt
	) external payable returns (address instance) {
		if (creationType == CreationType.CREATE) {
			return _deployCreate(initCode);
		} else if (creationType == CreationType.CREATE2) {
			return _deployCreate2(initCode, _processSalt(salt));
		} else if (creationType == CreationType.CREATE3) {
			return _deployCreate3(initCode, _processSalt(salt));
		} else if (creationType == CreationType.Clone) {
			// For Clone type, interpret first 20 bytes of initCode as implementation address
			return _deployClone(address(bytes20(initCode[:20])));
		} else if (creationType == CreationType.CloneDeterministic) {
			// For CloneDeterministic type, interpret first 20 bytes of initCode as implementation address
			return _deployCloneDeterministic(address(bytes20(initCode[:20])), _processSalt(salt));
		} else {
			revert InvalidCreationType();
		}
	}

	/// @inheritdoc ICreateXFactory
	function deployCreate(bytes calldata initCode) external payable returns (address instance) {
		return _deployCreate(initCode);
	}

	/// @inheritdoc ICreateXFactory
	function deployCreate2(bytes calldata initCode, bytes32 salt) external payable returns (address instance) {
		return _deployCreate2(initCode, _processSalt(salt));
	}

	/// @inheritdoc ICreateXFactory
	function deployCreate3(bytes calldata initCode, bytes32 salt) external payable returns (address instance) {
		return _deployCreate3(initCode, _processSalt(salt));
	}

	/// @inheritdoc ICreateXFactory
	function deployClone(address implementation) external payable returns (address instance) {
		return _deployClone(implementation);
	}

	/// @inheritdoc ICreateXFactory
	function deployCloneDeterministic(
		address implementation,
		bytes32 salt
	) external payable returns (address instance) {
		return _deployCloneDeterministic(implementation, _processSalt(salt));
	}

	/// @notice Performs deployment using CREATE opcode and emits events
	/// @param initCode Contract initialization code
	/// @return instance Address of the deployed contract
	function _deployCreate(bytes calldata initCode) private returns (address instance) {
		emit ContractCreation(instance = CreateX.create(initCode, msg.value), msg.sender);
	}

	/// @notice Performs deterministic deployment using CREATE2 opcode and emits events with salt information
	/// @param initCode Contract initialization code
	/// @param salt Processed salt value used in address derivation
	/// @return instance Address of the deployed contract
	function _deployCreate2(bytes calldata initCode, bytes32 salt) private returns (address instance) {
		emit ContractCreation(instance = CreateX.create2(initCode, salt, msg.value), salt, msg.sender);
	}

	/// @notice Performs proxy-based deployment using CREATE3 pattern and emits events
	/// @param initCode Contract initialization code
	/// @param salt Processed salt value used in address derivation
	/// @return instance Address of the deployed contract
	function _deployCreate3(bytes calldata initCode, bytes32 salt) private returns (address instance) {
		emit ContractCreation(instance = CreateX.create3(initCode, salt, msg.value), salt, msg.sender);
	}

	/// @notice Creates EIP-1167 minimal proxy and emits events
	/// @param implementation Implementation contract address to clone
	/// @return instance Address of the deployed proxy contract
	function _deployClone(address implementation) private returns (address instance) {
		emit ContractCreation(instance = CreateX.clone(implementation, msg.value), msg.sender);
	}

	/// @notice Creates deterministic EIP-1167 minimal proxy and emits events
	/// @param implementation Implementation contract address to clone
	/// @param salt Processed salt value used in address derivation
	/// @return instance Address of the deployed proxy contract
	function _deployCloneDeterministic(address implementation, bytes32 salt) private returns (address instance) {
		emit ContractCreation(instance = CreateX.cloneDeterministic(implementation, salt, msg.value), salt, msg.sender);
	}

	/// @inheritdoc ICreateXFactory
	function computeCreateXAddress(
		CreationType creationType,
		bytes32 initCodeHash,
		bytes32 salt
	) external view returns (address predicted) {
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
	function computeCreateAddress(uint256 nonce) public view virtual returns (address predicted) {
		return CreateX.computeCreateAddress(address(this), nonce);
	}

	/// @inheritdoc ICreateXFactory
	function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) public view virtual returns (address predicted) {
		return CreateX.computeCreate2Address(address(this), initCodeHash, _processSalt(salt));
	}

	/// @inheritdoc ICreateXFactory
	function computeCreate3Address(bytes32 salt) public view virtual returns (address predicted) {
		return CreateX.computeCreate3Address(address(this), _processSalt(salt));
	}

	/// @inheritdoc ICreateXFactory
	function computeCloneDeterministicAddress(
		address implementation,
		bytes32 salt
	) public view virtual returns (address predicted) {
		return CreateX.computeCloneDeterministicAddress(address(this), implementation, _processSalt(salt));
	}

	/// @notice Converts a raw salt into a guarded salt based on the embedded mode & guard configuration
	/// @dev Salt structure: [caller address (20 bytes), identifier (10 bytes), guard level (1 byte), mode (1 byte)]
	/// @param original Original unprotected salt
	/// @return salt Processed salt to be used in CREATE2 and CREATE3
	function _processSalt(bytes32 original) internal view virtual returns (bytes32 salt) {
		assembly ("memory-safe") {
			// prettier-ignore
			for {} 0x01 {} {
                // Parse original salt structure
                // original salt = [caller address (address), identifier (uint80), guard level (uint8), mode (uint8)]
                let mode := shr(0xf8, shl(0xf8, original))        // Extract last 1 byte (mode)
                let guard := shr(0xf8, shl(0xf0, original))       // Extract second-to-last byte (guard level)

				// MODE_RAW: Return the original salt without modification
				if iszero(mode) {
					salt := original
					break
				}

				// MODE_STRICT: Ensure the original salt starts with either the zero address or caller address
				if eq(mode, MODE_STRICT) {
					// Revert if first 20 bytes are neither zero address nor caller address
					if iszero(or(iszero(shr(0x60, original)), eq(shr(0x60, original), caller()))) {
						mstore(0x00, 0x81e69d9b) // InvalidSalt()
						revert(0x1c, 0x04)
					}
				}

				// Guard handling for MODE_STRICT / MODE_GUARDED
				// 	Mode.RAW     → salt returned untouched
				//	Mode.STRICT  → first 20 bytes must equal caller or zero, else revert
				//	Mode.GUARDED/STRICT → guard style applied:
				//		- GUARD_CALLER            : keccak256(caller, salt)
				//		- GUARD_CHAIN             : keccak256(chainId, salt)
				//		- GUARD_CALLER_AND_CHAIN  : keccak256(caller, chainId, salt)
				//		- GUARD_NONE / default    : salt unchanged
				switch guard
				// GUARD_CALLER: Combine caller address with salt
				case 0x01 {
					mstore(0x00, caller())
					mstore(0x20, original)
					salt := keccak256(0x00, 0x40)
				}
				// GUARD_CHAIN: Combine chain ID with salt
				case 0x02 {
					mstore(0x00, chainid())
					mstore(0x20, original)
					salt := keccak256(0x00, 0x40)
				}
				// GUARD_CALLER_AND_CHAIN: Combine caller + chain ID + salt
				case 0x03 {
					let ptr := mload(0x40)
					mstore(0x00, caller())
					mstore(0x20, chainid())
					mstore(0x40, original)
					salt := keccak256(0x00, 0x60)
					mstore(0x40, ptr)
				}
				// GUARD_NONE (or unknown code): Return the original salt without modification
				default { salt := original }
				break
			}
		}
	}
}

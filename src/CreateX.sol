// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title CreateX
/// @notice Provides deterministic deployments for CREATE, CREATE2, CREATE3, and EIP-1167 Minimal Proxy patterns
/// @author fomoweth
library CreateX {
	//──────────────────────────────────────────────────────────────────────────────//
	//									Custom Errors								//
	//──────────────────────────────────────────────────────────────────────────────//

	/// @notice Thrown when contract creation fails during deployment
	error ContractCreationFailed();

	/// @notice Thrown when the intermediate proxy creation fails during CREATE3 deployment
	error ProxyCreationFailed();

	/// @notice Thrown when the deploying contract has insufficient balance for the deployment
	error InsufficientBalance();

	/// @notice Thrown when provided implementation address is zero address for proxy deployments
	error InvalidImplementation();

	/// @notice Thrown when provided nonce exceeds the maximum allowed by EIP-2681 (2^64-1)
	error InvalidNonce();

	//──────────────────────────────────────────────────────────────────────────────//
	//									CREATE										//
	//──────────────────────────────────────────────────────────────────────────────//

	/// @notice Deploys a contract using CREATE opcode
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @return instance Address of the deployed contract
	function create(bytes memory initCode) internal returns (address instance) {
		return create(initCode, uint256(0));
	}

	/// @notice Deploys a contract using CREATE opcode
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param value Amount of ETH to send to the contract during deployment
	/// @return instance Address of the deployed contract
	function create(bytes memory initCode, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Deploy using CREATE opcode
			instance := create(value, add(initCode, 0x20), mload(initCode))

			// Verify deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE opcode
	/// @param nonce Nonce value of the deployer at the time of deployment
	/// @return predicted Predicted contract address
	function computeCreateAddress(uint256 nonce) internal view returns (address predicted) {
		return computeCreateAddress(address(this), nonce);
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE opcode
	/// @param deployer Address performing the deployment
	/// @param nonce Nonce value of the deployer at the time of deployment
	/// @return predicted Predicted contract address
	function computeCreateAddress(address deployer, uint256 nonce) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			// Enforce EIP‑2681 nonce constraint (https://eips.ethereum.org/EIPS/eip-2681)
			if iszero(lt(nonce, 0xffffffffffffffff)) {
				mstore(0x00, 0x756688fe) // InvalidNonce()
				revert(0x1c, 0x04)
			}

			// Construct RLP structure
			mstore8(0x01, 0x94) // Store RLP prefix for address
			mstore(0x02, shl(0x60, deployer)) // Store deployer address

			let offset  // Variable to track additional bytes needed for large nonces

			// prettier-ignore
			// Encode nonce according to RLP rules
			for {} 0x01 {} {
				// Single byte encoding case (0x00...0x7f)
				if lt(nonce, 0x80) {
					// Nonce value 0 is encoded as empty string, so convert to 0x80
					if iszero(nonce) { nonce := 0x80 }
					mstore8(0x16, nonce) // Store prefix or nonce directly
					break
				}

				// Multi-byte encoding case (≥ 0x80)
				// Compute number of bytes needed to encode nonce
				for { let i := nonce } i { i := shr(0x08, i) offset := add(offset, 0x01) } {}

				// Store length prefix indicating number of bytes used for nonce (0x80 + number of bytes)
				mstore8(0x16, add(0x80, offset))
				// Store nonce value in big-endian format at appropriate position
				mstore(0x17, shl(sub(0x100, mul(offset, 0x08)), nonce))
				break
			}

			// Complete RLP structure and compute predicted address
			mstore8(0x00, add(0xd6, offset)) // Set RLP prefix for total length
			predicted := keccak256(0x00, add(offset, 0x17)) // Compute predicted address
		}
	}

	//──────────────────────────────────────────────────────────────────────────────//
	//									CREATE2										//
	//──────────────────────────────────────────────────────────────────────────────//

	/// @notice Deploys a contract using CREATE2 opcode for deterministic addressing
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed contract
	function create2(bytes memory initCode, bytes32 salt) internal returns (address instance) {
		return create2(initCode, salt, uint256(0));
	}

	/// @notice Deploys a contract using CREATE2 opcode for deterministic addressing
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @param value Amount of ETH to send to the contract during deployment
	/// @return instance Address of the deployed contract
	function create2(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Deploy using CREATE2 opcode
			instance := create2(value, add(initCode, 0x20), mload(initCode), salt)

			// Verify deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE2 opcode
	/// @param initCodeHash keccak256 hash of initialization code
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) internal view returns (address predicted) {
		return computeCreate2Address(address(this), initCodeHash, salt);
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE2 opcode
	/// @param deployer Address performing the deployment
	/// @param initCodeHash keccak256 hash of initialization code
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate2Address(
		address deployer,
		bytes32 initCodeHash,
		bytes32 salt
	) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			mstore8(0x00, 0xff) // Store CREATE2 prefix
			mstore(0x35, initCodeHash) // Store creation bytecode hash
			mstore(0x01, shl(0x60, deployer)) // Store deployer address
			mstore(0x15, salt) // Store salt
			predicted := keccak256(0x00, 0x55) // Compute predicted address
			mstore(0x35, 0x00) // Clear hash storage
		}
	}

	//──────────────────────────────────────────────────────────────────────────────//
	//									CREATE3										//
	//──────────────────────────────────────────────────────────────────────────────//

	/// @notice Deploys a contract using CREATE3 pattern for chain-agnostic deterministic addressing
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed contract
	function create3(bytes memory initCode, bytes32 salt) internal returns (address instance) {
		return create3(initCode, salt, uint256(0));
	}

	/// @notice Deploys a contract using CREATE3 pattern for chain-agnostic deterministic addressing
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @param value Amount of ETH to send to the final contract
	/// @return instance Address of the deployed contract
	function create3(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Phase 1: Deploy intermediate proxy using CREATE2 opcode
			// Store creation bytecode for proxy
			// This bytecode creates a proxy that will use CREATE opcode to deploy final contract
			mstore(0x00, 0x67363d3d37363d34f03d5260086018f3)

			// Deploy proxy at deterministic address using CREATE2 opcode
			let proxy := create2(0x00, 0x10, 0x10, salt)

			// Verify deployed proxy address is not zero address
			if iszero(shl(0x60, proxy)) {
				mstore(0x00, 0xd49e7d74) // ProxyCreationFailed()
				revert(0x1c, 0x04)
			}

			// Phase 2: Perform inner deployment via proxy using CREATE opcode
			// The actual contract will be deployed by proxy at nonce 1

			// 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01)
			// 0x94 = 0x80 + 0x14 (length of an address, 20 bytes, in hex)
			mstore(0x14, proxy) // Store proxy address
			mstore(0x00, 0xd694) // Store RLP encoding prefix for address (0xd6 + 0x94)
			mstore8(0x34, 0x01) // Store proxy nonce
			instance := keccak256(0x1e, 0x17) // Compute final contract address

			// Call proxy with final contract's initialization code to deploy the actual contract using CREATE opcode
			if iszero(
				mul(
					extcodesize(instance), // Verify final contract contains code after deployment
					call(gas(), proxy, value, add(initCode, 0x20), mload(initCode), codesize(), 0x00)
				)
			) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE3 pattern
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate3Address(bytes32 salt) internal view returns (address predicted) {
		return computeCreate3Address(address(this), salt);
	}

	/// @notice Computes the predicted address of a contract deployed using CREATE3 pattern
	/// @param deployer Address performing the deployment
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate3Address(address deployer, bytes32 salt) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			// Compute proxy address using CREATE2 opcode
			let ptr := mload(0x40) // Cache free memory pointer
			mstore(0x00, deployer) // Store deployer address
			mstore8(0x0b, 0xff) // Store CREATE2 prefix
			mstore(0x20, salt) // Store salt
			// Store hash of minimal proxy creation bytecode
			// Equivalent to keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))
			mstore(0x40, 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f)
			mstore(0x14, keccak256(0x0b, 0x55)) // Compute and store proxy address
			mstore(0x40, ptr) // Restore free memory pointer
			// Compute final contract address using CREATE opcode
			// 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01)
			// 0x94 = 0x80 + 0x14 (length of an address, 20 bytes, in hex)
			mstore(0x00, 0xd694) // Store RLP encoding prefix for proxy deployment
			mstore8(0x34, 0x01) // Store proxy nonce
			predicted := keccak256(0x1e, 0x17) // Compute predicted address
		}
	}

	//──────────────────────────────────────────────────────────────────────────────//
	//							EIP-1167: Minimal Proxy								//
	//──────────────────────────────────────────────────────────────────────────────//

	/// @notice Deploys an EIP-1167 minimal proxy contract using CREATE opcode
	/// @param implementation Address of the logic contract for delegation
	/// @return instance Address of the deployed proxy
	function clone(address implementation) internal returns (address instance) {
		return clone(implementation, uint256(0));
	}

	/// @notice Deploys an EIP-1167 minimal proxy contract using CREATE opcode
	/// @param implementation Address of the logic contract for delegation
	/// @param value Amount of ETH to send to the proxy during deployment
	/// @return instance Address of the deployed proxy
	function clone(address implementation, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify implementation address is not zero and contains code
			if or(iszero(shl(0x60, implementation)), iszero(extcodesize(implementation))) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			// Verify current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Construct EIP-1167 minimal proxy bytecode
			// Clean upper 96 bits of implementation address and pack with bytecode before address
			mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
			// Pack remaining 17 bytes of implementation address with bytecode after address
			mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))

			// Deploy proxy using CREATE opcode
			instance := create(value, 0x09, 0x37)

			// Verify deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Deploys an EIP-1167 minimal proxy contract deterministically using CREATE2 opcode
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed proxy
	function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
		return cloneDeterministic(implementation, salt, uint256(0));
	}

	/// @notice Deploys an EIP-1167 minimal proxy contract deterministically using CREATE2 opcode
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @param value Amount of ETH to send to the proxy during deployment
	/// @return instance Address of the deployed proxy
	function cloneDeterministic(
		address implementation,
		bytes32 salt,
		uint256 value
	) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify implementation address is not zero and contains code
			if or(iszero(shl(0x60, implementation)), iszero(extcodesize(implementation))) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			// Verify current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Construct EIP-1167 minimal proxy bytecode
			// Clean upper 96 bits of implementation address and pack with bytecode before address
			mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
			// Pack remaining 17 bytes of implementation address with bytecode after address
			mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))

			// Deploy proxy using CREATE2 opcode
			instance := create2(value, 0x09, 0x37, salt)

			// Verify deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the predicted address of a contract deployed using EIP-1167 pattern
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCloneDeterministicAddress(
		address implementation,
		bytes32 salt
	) internal view returns (address predicted) {
		return computeCloneDeterministicAddress(address(this), implementation, salt);
	}

	/// @notice Computes the predicted address of a contract deployed using EIP-1167 pattern
	/// @param deployer Address performing the deployment
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCloneDeterministicAddress(
		address deployer,
		address implementation,
		bytes32 salt
	) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			let ptr := mload(0x40) // Cache free memory pointer
			mstore(add(ptr, 0x58), salt) // Store salt
			mstore(add(ptr, 0x38), deployer) // Store deployer address
			mstore(add(ptr, 0x24), 0x5af43d82803e903d91602b57fd5bf3ff) // Store runtime code suffix
			mstore(add(ptr, 0x14), implementation) // Store implementation address
			mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73) // Store creation code and runtime code prefix
			mstore(add(ptr, 0x78), keccak256(add(ptr, 0x0c), 0x37)) // Compute hash of proxy bytecode and store
			predicted := keccak256(add(ptr, 0x43), 0x55) // Compute predicted address
		}
	}
}

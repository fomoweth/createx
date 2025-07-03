// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title CreateX
/// @notice Provides deterministic deployments for CREATE, CREATE2, CREATE3, and EIP‑1167 Minimal Proxy patterns
/// @author fomoweth
library CreateX {
	/// @notice Thrown when contract deployment fails during deployment
	/// @dev Common causes: insufficient gas, invalid bytecode, constructor revert, size limits exceeded
	error ContractCreationFailed();

	/// @notice Thrown when the intermediate proxy deployment fails during CREATE3 deployment
	/// @dev CREATE3 requires a successful proxy deployment as the first step of a two-phase process
	error ProxyCreationFailed();

	/// @notice Thrown when the deploying contract has insufficient balance for the deployment
	/// @dev Balance check is performed before deployment to prevent failed transactions
	error InsufficientBalance();

	/// @notice Thrown when provided implementation address is the zero address for proxy deployments
	/// @dev Implementation address must be a valid, deployed contract with actual bytecode
	error InvalidImplementation();

	/// @notice Thrown when provided nonce exceeds the EIP-2681 limit (2^64-1)
	/// @dev This applies to CREATE and CLONE deployment types that use nonce-based addressing
	error InvalidNonce();

	/*──────────────────────────────────────────────────────────────────────────────*/
	/*									CREATE										*/
	/*──────────────────────────────────────────────────────────────────────────────*/

	/// @notice Deploys a contract using the traditional CREATE opcode
	/// @dev Address is deterministic based on deployer address and nonce (RLP encoding)
	/// @param initCode Complete contract bytecode including constructor and constructor arguments
	/// @param value Amount of ETH to send to the contract during deployment
	/// @return instance Address of the deployed contract
	function create(bytes memory initCode, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify the current contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Deploy using CREATE opcode
			instance := create(value, add(initCode, 0x20), mload(initCode))

			// Verify the deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the address of a contract deployed via CREATE
	/// @dev Uses RLP encoding rules to predict the deployment address deterministically
	/// @param deployer The address performing the deployment
	/// @param nonce Nonce value of the deployer at the time of deployment
	/// @return predicted The predicted deployment address
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

			// Encode nonce according to RLP rules
			// prettier-ignore
			for {} 0x01 {} {
				// Single byte encoding case (0x00...0x7f)
				if lt(nonce, 0x80) {
					// The value 0 is encoded as empty string, so convert to 0x80
					if iszero(nonce) { nonce := 0x80 }
					mstore8(0x16, nonce) // Store prefix or nonce directly
					break
				}

				// Multi-byte encoding case (≥ 0x80)
				// Compute number of bytes needed to encode the nonce
				for { let i := nonce } iszero(iszero(i)) { i := shr(0x08, i) offset := add(offset, 0x01) } {}

				// Store length prefix indicating number of bytes used for nonce (0x80 + number of bytes)
				mstore8(0x16, add(0x80, offset))
				// Store the nonce value in big-endian format at appropriate position
				mstore(0x17, shl(sub(0x100, mul(offset, 0x08)), nonce))
				break
			}

			// Complete RLP structure and compute predicted address
			mstore8(0x00, add(0xd6, offset)) // Set RLP prefix for total length
			predicted := keccak256(0x00, add(offset, 0x17)) // Compute predicted address
		}
	}

	/*──────────────────────────────────────────────────────────────────────────────*/
	/*									CREATE2										*/
	/*──────────────────────────────────────────────────────────────────────────────*/

	/// @notice Deploys a contract using CREATE2 opcode for deterministic addressing
	/// @dev The contract address is deterministic based on deployer, salt, and initCode hash
	/// @param initCode Complete contract bytecode including constructor and constructor arguments
	/// @param salt 32-byte value used in address derivation (should be unique for different contracts)
	/// @param value Amount of ETH to send to the contract during deployment
	/// @return instance Address of the deployed contract
	function create2(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify the contract has sufficient balance to send the specified value
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

	/// @notice Computes the address of a contract deployed via CREATE2
	/// @dev Uses the standard CREATE2 address computation formula: keccak256(0xff + deployer + salt + keccak256(initCode))
	/// @param deployer The address performing the deployment
	/// @param initCodeHash keccak256 hash of the contract's initialization code
	/// @param salt 32-byte value used in address derivation
	/// @return predicted The predicted deployment address
	function computeCreate2Address(
		address deployer,
		bytes32 initCodeHash,
		bytes32 salt
	) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			// Construct CREATE2 computation structure
			mstore8(0x00, 0xff) // Store CREATE2 prefix
			mstore(0x35, initCodeHash) // Store creation bytecode hash
			mstore(0x01, shl(0x60, deployer)) // Store deployer address
			mstore(0x15, salt) // Store salt
			predicted := keccak256(0x00, 0x55) // Compute predicted address
			mstore(0x35, 0x00) // Clear the hash storage
		}
	}

	/*──────────────────────────────────────────────────────────────────────────────*/
	/*									CREATE3										*/
	/*──────────────────────────────────────────────────────────────────────────────*/

	/// @notice Deploys a contract using CREATE3 pattern for chain-agnostic addressing
	/// @dev Two-phase deployment: first deploys a proxy via CREATE2, then deploys actual contract via proxy
	/// @param initCode Complete contract bytecode including constructor and constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @param value Amount of ETH to send to the final contract
	/// @return instance Address of the deployed contract
	function create3(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify the contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Phase 1: Deploy intermediate proxy using CREATE2 opcode
			// Store creation bytecode for proxy used by CREATE3 pattern
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
			// 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex)
			mstore(0x14, proxy) // Store proxy address
			mstore(0x00, 0xd694) // RLP encoding prefix for address (0xd6 + 0x94)
			mstore8(0x34, 0x01) // Nonce of the proxy (1)
			instance := keccak256(0x1e, 0x17) // Compute final contract address

			// Call proxy with final contract's initCode to deploy the actual contract using CREATE opcode
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

	/// @notice Computes the address of a contract deployed via CREATE3
	/// @dev The contract address is deterministic based on deployer and salt
	/// @param deployer The address performing the deployment
	/// @param salt 32-byte value used in address derivation
	/// @return predicted The predicted deployment address
	function computeCreate3Address(address deployer, bytes32 salt) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			// Compute proxy address using CREATE2 opcode
			let ptr := mload(0x40)
			mstore(0x00, deployer) // Store deployer address
			mstore8(0x0b, 0xff) // Store CREATE2 prefix
			mstore(0x20, salt) // Store salt
			// Store hash of minimal proxy creation bytecode
			// Equivalent to keccak256(abi.encodePacked(hex"67363d3d37363d34f03d5260086018f3"))
			mstore(0x40, 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f)
			mstore(0x14, keccak256(0x0b, 0x55)) // Compute proxy address and store
			mstore(0x40, ptr) // Restore memory pointer
			// Compute final contract address using CREATE opcode
			// 0xd6 = 0xc0 (short RLP prefix) + 0x16 (length of: 0x94 ++ proxy ++ 0x01)
			// 0x94 = 0x80 + 0x14 (0x14 = the length of an address, 20 bytes, in hex)
			mstore(0x00, 0xd694) // Store RLP encoding prefix for proxy deployment
			mstore8(0x34, 0x01) // Store proxy's nonce (1)
			predicted := keccak256(0x1e, 0x17) // Compute predicted address
		}
	}

	/*──────────────────────────────────────────────────────────────────────────────*/
	/*							EIP-1167: Minimal Proxy								*/
	/*──────────────────────────────────────────────────────────────────────────────*/

	/// @notice Deploys an EIP-1167 minimal proxy contract using the CREATE opcode
	/// @dev Proxy forwards all calls via DELEGATECALL to the implementation contract
	/// @param implementation Address of the logic contract for delegation
	/// @param value Amount of ETH to send to the proxy during deployment
	/// @return instance Address of the deployed proxy contract
	function clone(address implementation, uint256 value) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify the implementation address is not zero and contains code
			if or(iszero(shl(0x60, implementation)), iszero(extcodesize(implementation))) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			// Verify the contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Construct EIP-1167 minimal proxy bytecode
			// Clean upper 96 bits of implementation address and pack with bytecode before address
			// 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000: bytecode before implementation address
			mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
			// Pack remaining 17 bytes of implementation address with bytecode after address
			// 0x5af43d82803e903d91602b57fd5bf3: bytecode after implementation address
			mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))

			// Deploy proxy using CREATE opcode
			instance := create(value, 0x09, 0x37)

			// Verify the deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Creates a deterministic minimal proxy using CREATE2 opcode
	/// @dev Combines EIP-1167 proxy pattern with CREATE2 for predictable addresses
	/// @param implementation Address of the logic contract for delegation
	/// @param salt Salt value for deterministic address generation
	/// @param value Amount of ETH to send to the proxy during deployment
	/// @return instance Address of the deployed deterministic proxy
	function cloneDeterministic(
		address implementation,
		bytes32 salt,
		uint256 value
	) internal returns (address instance) {
		assembly ("memory-safe") {
			// Verify the implementation address is not zero and contains code
			if or(iszero(shl(0x60, implementation)), iszero(extcodesize(implementation))) {
				mstore(0x00, 0x68155f9a) // InvalidImplementation()
				revert(0x1c, 0x04)
			}

			// Verify the contract has sufficient balance to send the specified value
			if lt(selfbalance(), value) {
				mstore(0x00, 0xf4d678b8) // InsufficientBalance()
				revert(0x1c, 0x04)
			}

			// Construct EIP-1167 minimal proxy bytecode (identical to {clone} function)
			mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
			mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))

			// Deploy proxy using CREATE2 opcode
			instance := create2(value, 0x09, 0x37, salt)

			// Verify the deployed contract address is not zero and contains code
			if or(iszero(shl(0x60, instance)), iszero(extcodesize(instance))) {
				mstore(0x00, 0xa28c2473) // ContractCreationFailed()
				revert(0x1c, 0x04)
			}
		}
	}

	/// @notice Computes the address of a deterministic minimal proxy
	/// @dev Uses the standard CREATE2 formula with the minimal proxy bytecode hash
	/// @param deployer The address performing the deployment
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return predicted The predicted address of the proxy contract
	function computeCloneDeterministicAddress(
		address deployer,
		address implementation,
		bytes32 salt
	) internal pure returns (address predicted) {
		assembly ("memory-safe") {
			// Construct proxy bytecode with implementation address
			// Creation code 20 bytes ─ 0x3d602d80600a3d3981f3
			// Runtime code 15 bytes ─ 0x363d3d373d3d3d363d73 ++ impl ++ 0x5af43d82803e903d91602b57fd5bf3
			// Total 0x37 bytes (55 bytes)
			let ptr := mload(0x40)
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

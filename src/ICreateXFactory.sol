// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ICreateXFactory
/// @notice Unified interface for deploying contracts using various creation patterns
/// @author fomoweth
interface ICreateXFactory {
	/// @notice Thrown when provided creation type is outside the supported enum range
	error InvalidCreationType();

	/// @notice Thrown when provided salt fails validation
	error InvalidSalt();

	/// @notice Emitted when a contract is created without salt (CREATE / Clone)
	/// @param instance Address of the deployed contract
	/// @param deployer Address that initiated the deployment transaction
	event ContractCreation(address indexed instance, address indexed deployer);

	/// @notice Emitted when a contract is created with salt (CREATE2 / CREATE3 / CloneDeterministic)
	/// @param instance Address of the deployed contract
	/// @param deployer Address that initiated the deployment transaction
	/// @param salt 32-byte value used in address derivation
	event ContractCreation(address indexed instance, address indexed deployer, bytes32 indexed salt);

	// prettier-ignore
	/// @notice Enumeration defining supported contract creation methods
	enum CreationType {
		CREATE, 			// 0 – traditional deployment
		CREATE2,			// 1 – deterministic deployment
		CREATE3,			// 2 – chain-agnostic deployment
		Clone,				// 3 – EIP-1167 via CREATE
		CloneDeterministic	// 4 – EIP-1167 via CREATE2
	}

	/// @notice Deploys a contract using the specified creation method
	/// @dev Unified contract deployment function covering every {CreationType}
	/// @param creationType Creation method to use
	/// @param initCode Contract initialization code (interpreted as implementation address for Clone / CloneDeterministic)
	/// @param salt 32-byte value used in address derivation (can be empty for CREATE / Clone)
	/// @return instance Address of the deployed contract
	function createX(
		CreationType creationType,
		bytes calldata initCode,
		bytes32 salt
	) external payable returns (address instance);

	/// @notice Deploys a contract using CREATE opcode
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @return instance Address of the deployed contract
	function create(bytes calldata initCode) external payable returns (address instance);

	/// @notice Deploys a contract using CREATE2 opcode
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed contract
	function create2(bytes calldata initCode, bytes32 salt) external payable returns (address instance);

	/// @notice Deploys a contract using CREATE3 pattern
	/// @param initCode Complete contract bytecode including constructor arguments
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed contract
	function create3(bytes calldata initCode, bytes32 salt) external payable returns (address instance);

	/// @notice Deploys an EIP-1167 minimal proxy contract using CREATE opcode
	/// @param implementation Address of the logic contract for delegation
	/// @return instance Address of the deployed contract
	function clone(address implementation) external payable returns (address instance);

	/// @notice Deploys an EIP-1167 minimal proxy contract deterministically using CREATE2 opcode
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return instance Address of the deployed contract
	function cloneDeterministic(address implementation, bytes32 salt) external payable returns (address instance);

	/// @notice Computes the predicted address for the specified creation method
	/// @dev Unified address prediction function covering every {CreationType}
	/// @param creationType Creation method to use
	/// @param initCodeHash The hash or identifier used for address calculation
	/// 					- CREATE: not used in calculation, can be empty
	/// 					- CREATE2: keccak256 hash of the initialization code
	/// 					- CREATE3: not used in calculation, can be empty (proxy hash is constant)
	/// 					- Clone: not used in calculation, can be empty
	/// 					- CloneDeterministic: implementation contract address as bytes32
	/// @param salt 32-byte value used in address derivation (interpreted as nonce for CREATE / Clone)
	/// @return predicted Predicted contract address
	function computeCreateXAddress(
		CreationType creationType,
		bytes32 initCodeHash,
		bytes32 salt
	) external view returns (address predicted);

	/// @notice Computes the predicted address of a contract deployed using CREATE opcode
	/// @param nonce Nonce value at the time of deployment
	/// @return predicted Predicted contract address
	function computeCreateAddress(uint256 nonce) external view returns (address predicted);

	/// @notice Computes the predicted address of a contract deployed using CREATE2 opcode
	/// @param initCodeHash keccak256 hash of initialization code
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) external view returns (address predicted);

	/// @notice Computes the predicted address of a contract deployed using CREATE3 pattern
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate3Address(bytes32 salt) external view returns (address predicted);

	/// @notice Computes the predicted address of a contract deployed using EIP-1167 pattern
	/// @param implementation Address of the logic contract for delegation
	/// @param salt 32-byte value used in address derivation
	/// @return predicted Predicted contract address
	function computeCloneDeterministicAddress(
		address implementation,
		bytes32 salt
	) external view returns (address predicted);
}

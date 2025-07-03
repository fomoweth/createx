// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ICreateXFactory
/// @notice Interface for deploying contracts through multiple creation patterns:
///      	- CREATE: Traditional deployment (unpredictable addresses)
///      	- CREATE2: Deterministic deployment (salt-based address prediction)
///      	- CREATE3: Chain-agnostic deployment (consistent addresses across chains)
///      	- Clone: EIP-1167 minimal proxy (gas-efficient duplication)
///      	- CloneDeterministic: Deterministic EIP-1167 minimal proxy (predictable addresses)
/// @author fomoweth
interface ICreateXFactory {
	/// @notice Thrown when provided creation type is outside the supported enum range
	error InvalidCreationType();

	/// @notice Thrown when provided salt fails validation (e.g. wrong prefix or reused)
	error InvalidSalt();

	/// @notice Emitted when a contract is created with salt (CREATE2 / CREATE3 / CloneDeterministic)
	/// @param instance Address of the deployed contract
	/// @param salt Salt value used in address derivation
	/// @param deployer  Address that initiated the deployment transaction
	event ContractCreation(address indexed instance, bytes32 indexed salt, address indexed deployer);

	/// @notice Emitted when a contract is created without salt (CREATE / Clone)
	/// @param instance Address of the deployed contract
	/// @param deployer  Address that initiated the deployment transaction
	event ContractCreation(address indexed instance, address indexed deployer);

	// prettier-ignore
	/// @notice Enumeration defining contract creation methods
	enum CreationType {
		CREATE, 			// 0 – traditional deployment
		CREATE2,			// 1 – deterministic deployment
		CREATE3,			// 2 – chain-agnostic deployment
		Clone,				// 3 – EIP‑1167 via CREATE
		CloneDeterministic	// 4 – EIP‑1167 via CREATE2
	}

	// prettier-ignore
	/// @notice Enumeration defining salt protection levels
	enum Guard {
        None,               // 0 – no guard, uses original salt
        Caller,             // 1 – combines caller address with salt
        Chain,              // 2 – combines chain ID with salt
        CallerAndChain      // 3 – combines caller address, chain ID, and salt
	}

	// prettier-ignore
	/// @notice Enumeration defining salt processing modes
	enum Mode {
        Raw,                // 0 – uses original salt without modification
        Strict,             // 1 – enforces salt prefix matches caller or zero address
        Guarded             // 2 – apply guard logic (Caller / Chain / CallerAndChain)
	}

	/// @notice Unified contract deployment function covering every `CreationType`
	/// @param creationType Creation method to use (CREATE, CREATE2, CREATE3, Clone, CloneDeterministic)
	/// @param initCode Contract initialization code or implementation address (for Clone types
	/// @param salt Salt value used in address derivation (interpreted as nonce for CREATE / Clone)
	/// @return instance Address of the deployed contract
	function deployCreateX(
		CreationType creationType,
		bytes calldata initCode,
		bytes32 salt
	) external payable returns (address instance);

	/// @notice Deploy contract using CREATE opcode
	/// @param initCode Contract bytecode and constructor parameters
	/// @return instance Address of the deployed contract
	function deployCreate(bytes calldata initCode) external payable returns (address instance);

	/// @notice Deploy contract using CREATE2 opcode for deterministic addresses
	/// @param initCode Contract bytecode and constructor parameters
	/// @param salt Salt value used in address derivation
	/// @return instance Address of the deployed contract
	function deployCreate2(bytes calldata initCode, bytes32 salt) external payable returns (address instance);

	/// @notice Deploy contract using CREATE3 pattern for chain-agnostic addresses
	/// @param initCode Contract bytecode and constructor parameters
	/// @param salt Salt value used in address derivation
	/// @return instance Address of the deployed contract
	function deployCreate3(bytes calldata initCode, bytes32 salt) external payable returns (address instance);

	/// @notice Deploy EIP-1167 minimal proxy contract using CREATE opcode
	/// @param implementation Address of the implementation contract to clone
	/// @return instance Address of the deployed proxy contract
	function deployClone(address implementation) external payable returns (address instance);

	/// @notice Deploy deterministic EIP-1167 minimal proxy contract using CREATE2 opcode
	/// @param implementation Address of the implementation contract to clone
	/// @param salt Salt value for address calculation
	/// @return instance Address of the deployed proxy contract
	function deployCloneDeterministic(address implementation, bytes32 salt) external payable returns (address instance);

	/// @notice Unified address prediction function
	/// @dev Supports address prediction for all deployment types supported by {deployCreateX}
	/// @param creationType Creation method to use (CREATE, CREATE2, CREATE3, Clone, CloneDeterministic)
	/// @param initCodeHash The hash or identifier used for address calculation
	///             		- For CREATE: Not used in calculation (can be any value)
	///             		- For CREATE2: keccak256 hash of the initialization code
	///             		- For CREATE3: Not used in calculation (proxy hash is constant)
	///             		- For Clone: Not used in calculation (can be any value)
	///             		- For CloneDeterministic: Implementation contract address as bytes32
	/// @param salt Salt value used in address derivation (interpreted as nonce for CREATE / Clone)
	/// @return predicted Predicted contract address
	function computeCreateXAddress(
		CreationType creationType,
		bytes32 initCodeHash,
		bytes32 salt
	) external view returns (address predicted);

	/// @notice Computes predicted address for CREATE deployment
	/// @dev Nonce-based address calculation
	/// @param nonce Nonce value to use
	/// @return predicted Predicted contract address
	function computeCreateAddress(uint256 nonce) external view returns (address predicted);

	/// @notice Computes predicted address for CREATE2 deployment
	/// @dev Salt and initCodeHash based address calculation
	/// @param initCodeHash Keccak256 hash of initialization code
	/// @param salt Salt value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) external view returns (address predicted);

	/// @notice Computes predicted address for CREATE3 deployment
	/// @dev Salt-only address calculation (independent of initCode)
	/// @param salt Salt value used in address derivation
	/// @return predicted Predicted contract address
	function computeCreate3Address(bytes32 salt) external view returns (address predicted);

	/// @notice Computes predicted address for CloneDeterministic deployment
	/// @dev Implementation address and salt based address calculation
	/// @param implementation Address of the implementation contract to clone
	/// @param salt Salt value used in address derivation
	/// @return predicted Predicted proxy contract address
	function computeCloneDeterministicAddress(
		address implementation,
		bytes32 salt
	) external view returns (address predicted);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ICreateXFactory} from "src/ICreateXFactory.sol";
import {CreateX as CreateXLib} from "src/CreateX.sol";
import {BaseScript} from "./BaseScript.sol";
import {ERC1967_PROXY_BYTECODE, TRANSPARENT_PROXY_BYTECODE} from "./Precompiles.sol";

contract CreateX is BaseScript {
	ICreateXFactory internal constant CREATEX_FACTORY = ICreateXFactory(0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf);

	function deployContract() internal virtual broadcast returns (address) {
		uint256 creationType = promptCreationType();
		bytes memory initCode;
		bytes32 salt;
		uint256 value;

		if (creationType < uint8(ICreateXFactory.CreationType.Clone)) {
			bytes memory creationCode = vm.getCode(prompt("Artifact path"));
			bytes memory arguments = promptBytes("Constructor arguments");
			initCode = bytes.concat(creationCode, arguments);
		} else {
			address implementation = vm.promptAddress("Implementation");
			initCode = abi.encodePacked(implementation);
		}

		if (
			creationType != uint8(ICreateXFactory.CreationType.CREATE) &&
			creationType != uint8(ICreateXFactory.CreationType.Clone)
		) {
			salt = promptBytes32("Salt", defaultSalt());
		}

		value = promptUint256("msg.value");

		return deployCreateX(creationType, initCode, salt, value);
	}

	function deployCreateX(uint256 creationType, bytes memory initCode, bytes32 salt) internal returns (address) {
		return deployCreateX(creationType, initCode, salt, 0);
	}

	function deployCreateX(
		uint256 creationType,
		bytes memory initCode,
		bytes32 salt,
		uint256 value
	) internal returns (address) {
		return CREATEX_FACTORY.createX{value: value}(asCreationType(creationType), initCode, salt);
	}

	function deployCreate(bytes memory initCode) internal returns (address) {
		return deployCreate(initCode, 0);
	}

	function deployCreate(bytes memory initCode, uint256 value) internal returns (address) {
		return CREATEX_FACTORY.create{value: value}(initCode);
	}

	function deployCreate2(bytes memory initCode, bytes32 salt) internal returns (address) {
		return deployCreate2(initCode, salt, 0);
	}

	function deployCreate2(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address) {
		return CREATEX_FACTORY.create2{value: value}(initCode, salt);
	}

	function deployCreate3(bytes memory initCode, bytes32 salt) internal returns (address) {
		return deployCreate3(initCode, salt, 0);
	}

	function deployCreate3(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address) {
		return CREATEX_FACTORY.create3{value: value}(initCode, salt);
	}

	function deployClone(address implementation) internal returns (address) {
		return deployClone(implementation, 0);
	}

	function deployClone(address implementation, uint256 value) internal returns (address) {
		return CREATEX_FACTORY.clone{value: value}(implementation);
	}

	function deployCloneDeterministic(address implementation, bytes32 salt) internal returns (address) {
		return deployCloneDeterministic(implementation, salt, 0);
	}

	function deployCloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address) {
		return CREATEX_FACTORY.cloneDeterministic{value: value}(implementation, salt);
	}

	function deployERC1967Proxy(
		address implementation,
		bytes memory data,
		uint256 value
	) internal returns (address proxy) {
		bytes memory arguments = abi.encode(implementation, data);
		bytes memory initCode = bytes.concat(ERC1967_PROXY_BYTECODE, arguments);
		return deployCreate(initCode, value);
	}

	function deployERC1967Proxy(
		address implementation,
		bytes memory data,
		bytes32 salt,
		uint256 value
	) internal returns (address proxy) {
		bytes memory arguments = abi.encode(implementation, data);
		bytes memory initCode = bytes.concat(ERC1967_PROXY_BYTECODE, arguments);
		return deployCreate2(initCode, salt, value);
	}

	function deployTransparentProxy(
		address owner,
		address implementation,
		bytes memory data,
		uint256 value
	) internal returns (address proxy, address proxyAdmin) {
		bytes memory arguments = abi.encode(owner, implementation, data);
		bytes memory initCode = bytes.concat(TRANSPARENT_PROXY_BYTECODE, arguments);
		proxyAdmin = CreateXLib.computeCreateAddress(proxy = deployCreate(initCode, value), 1);
	}

	function deployTransparentProxy(
		address owner,
		address implementation,
		bytes memory data,
		bytes32 salt,
		uint256 value
	) internal returns (address proxy, address proxyAdmin) {
		bytes memory arguments = abi.encode(owner, implementation, data);
		bytes memory initCode = bytes.concat(TRANSPARENT_PROXY_BYTECODE, arguments);
		proxyAdmin = CreateXLib.computeCreateAddress(proxy = deployCreate2(initCode, salt, value), 1);
	}

	function promptCreationType() internal returns (uint256) {
		string memory promptText = "CreationType (0: CREATE, 1: CREATE2, 2: CREATE3, 3: Clone, 4: CloneDeterministic)";
		return vm.promptUint(promptText);
	}

	function asCreationType(uint256 creationType) internal pure returns (ICreateXFactory.CreationType) {
		if (creationType > uint8(type(ICreateXFactory.CreationType).max)) revert ICreateXFactory.InvalidCreationType();
		return ICreateXFactory.CreationType(creationType);
	}
}

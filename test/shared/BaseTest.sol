// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

abstract contract BaseTest is Test {
	uint256 internal constant CREATION_TYPE_CREATE = 0;
	uint256 internal constant CREATION_TYPE_CREATE2 = 1;
	uint256 internal constant CREATION_TYPE_CREATE3 = 2;
	uint256 internal constant CREATION_TYPE_CLONE = 3;
	uint256 internal constant CREATION_TYPE_CLONE_DETERMINISTIC = 4;

	uint8 internal constant MODE_RAW = 0;
	uint8 internal constant MODE_GUARDED = 1;
	uint8 internal constant MODE_STRICT = 2;

	uint8 internal constant GUARD_NONE = 0;
	uint8 internal constant GUARD_CALLER = 1;
	uint8 internal constant GUARD_CHAIN = 2;
	uint8 internal constant GUARD_CALLER_AND_CHAIN = 3;

	uint256 internal snapshotId = type(uint256).max;

	modifier impersonate(address account) {
		vm.startPrank(account);
		_;
		vm.stopPrank();
	}

	function revertToState() internal virtual {
		if (snapshotId != type(uint256).max) vm.revertToState(snapshotId);
		snapshotId = vm.snapshotState();
	}

	function createAccounts(
		string memory prefix,
		uint256 initialBalance,
		uint256 length
	) internal virtual returns (address[] memory accounts) {
		accounts = new address[](length);
		for (uint256 i; i < length; ) {
			accounts[i] = createAccount(string.concat(prefix, " #", vm.toString(i)), initialBalance);

			unchecked {
				i = i + 1;
			}
		}
	}

	function createAccount(string memory key, uint256 initialBalance) internal virtual returns (address account) {
		vm.label(account = vm.addr(encodePrivateKey(key)), key);
		vm.deal(account, initialBalance);
	}

	function createAccount(string memory key) internal virtual returns (address account) {
		return createAccount(key, 0);
	}

	function generateSalt(address sender) internal virtual returns (bytes32 salt) {
		return generateSalt(sender, uint80(vm.randomUint(0, type(uint80).max)));
	}

	function generateSalt(address sender, uint80 identifier) internal virtual returns (bytes32 salt) {
		return
			generateSalt(
				sender,
				uint8(vm.randomUint(MODE_RAW, MODE_STRICT)),
				uint8(vm.randomUint(GUARD_NONE, GUARD_CALLER_AND_CHAIN)),
				identifier
			);
	}

	function generateSalt(
		address sender,
		uint8 mode,
		uint8 guard,
		uint80 identifier
	) internal pure virtual returns (bytes32 salt) {
		mode = uint8(bound(mode, MODE_RAW, MODE_STRICT));

		if (mode == MODE_RAW) {
			guard = GUARD_NONE;
		} else if (mode == MODE_GUARDED) {
			guard = uint8(bound(guard, GUARD_CALLER, GUARD_CALLER_AND_CHAIN));
		} else {
			guard = uint8(bound(guard, GUARD_NONE, GUARD_CALLER_AND_CHAIN));
		}

		return encodeSalt(sender, mode, guard, identifier);
	}

	function encodeSalt(
		address sender,
		uint8 mode,
		uint8 guard,
		uint80 identifier
	) internal pure virtual returns (bytes32 salt) {
		return bytes32(abi.encodePacked(sender, identifier, guard, mode));
	}

	function processSalt(bytes32 original) internal view virtual returns (bytes32 salt) {
		return processSalt(original, address(bytes20(original)));
	}

	function processSalt(bytes32 original, address msgSender) internal view virtual returns (bytes32 salt) {
		return processSalt(uint8(bytes1(original[31])), uint8(bytes1(original[30])), original, msgSender);
	}

	function processSalt(
		uint8 mode,
		uint8 guard,
		bytes32 original,
		address msgSender
	) internal view virtual returns (bytes32 salt) {
		if (mode != MODE_RAW) {
			if (guard == GUARD_CALLER) {
				return keccak256(abi.encode(msgSender, original));
			} else if (guard == GUARD_CHAIN) {
				return keccak256(abi.encode(block.chainid, original));
			} else if (guard == GUARD_CALLER_AND_CHAIN) {
				return keccak256(abi.encode(msgSender, block.chainid, original));
			}
		}

		return original;
	}

	function computeCreate2Address(
		address deployer,
		bytes32 initCodeHash,
		bytes32 salt
	) internal pure virtual returns (address predicted) {
		return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
	}

	function computeCreate3Address(address deployer, bytes32 salt) internal pure virtual returns (address predicted) {
		bytes32 initCodeHash = keccak256(abi.encodePacked(hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3"));

		address proxy = computeCreate2Address(deployer, initCodeHash, salt);

		return address(uint160(uint256(keccak256(abi.encodePacked(hex"d6_94", proxy, hex"01")))));
	}

	function computeCloneDeterministicAddress(
		address deployer,
		address implementation,
		bytes32 salt
	) internal pure virtual returns (address predicted) {
		bytes32 initCodeHash = keccak256(
			abi.encodePacked(
				hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
				bytes20(implementation),
				hex"5af43d82803e903d91602b57fd5bf3"
			)
		);

		return computeCreate2Address(deployer, initCodeHash, salt);
	}

	function encodePrivateKey(string memory name) internal pure virtual returns (uint256 privateKey) {
		return boundPrivateKey(uint256(keccak256(abi.encodePacked(name))));
	}
}

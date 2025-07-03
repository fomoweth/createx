// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateXFactory, ICreateXFactory} from "src/CreateXFactory.sol";
import {CreateX} from "src/CreateX.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";
import {BaseTest} from "test/shared/BaseTest.sol";

contract CreateXFactoryTest is BaseTest {
	CreateXFactory internal factory;

	address internal user;

	function setUp() public {
		vm.roll(100);
		user = createAccount("User", 1000 ether);
		factory = new CreateXFactory();
	}

	function test_deployCreateX(
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bool guarded,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		vm.assume(mode <= MODE_STRICT);
		vm.assume(guard <= GUARD_CALLER_AND_CHAIN);
		vm.assume(value <= user.balance);

		MockTarget instance;
		address predicted;

		bytes32 original = encodeSalt(mode, guard, identifier, guarded ? user : address(0));
		bytes32 salt = processSalt(mode, guard, original, user);

		address mock = address(new MockTarget(key));
		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		bytes32 initCodeHash = keccak256(initCode);

		revertToState();
		predicted = factory.computeCreateAddress(vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		instance = MockTarget(
			payable(factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE, initCode, original))
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreate2Address(initCodeHash, original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			payable(factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE2, initCode, original))
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreate3Address(original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			payable(factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE3, initCode, original))
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreateAddress(vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		instance = MockTarget(
			payable(
				factory.deployCreateX{value: value}(
					ICreateXFactory.CreationType.Clone,
					abi.encodePacked(mock),
					original
				)
			)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCloneDeterministicAddress(mock, original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			payable(
				factory.deployCreateX{value: value}(
					ICreateXFactory.CreationType.CloneDeterministic,
					abi.encodePacked(mock),
					original
				)
			)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
	}

	function test_computeCreateXAddress(
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bool guarded,
		bytes32 hash
	) public impersonate(user) {
		vm.assume(mode <= MODE_STRICT);
		vm.assume(guard <= GUARD_CALLER_AND_CHAIN);

		if (identifier >= type(uint64).max) {
			vm.expectRevert(CreateX.InvalidNonce.selector);
			factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE, hash, bytes32(uint256(identifier)));
		} else {
			assertEq(
				factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE, hash, bytes32(uint256(identifier))),
				vm.computeCreateAddress(address(factory), identifier)
			);

			assertEq(
				factory.computeCreateXAddress(ICreateXFactory.CreationType.Clone, hash, bytes32(uint256(identifier))),
				vm.computeCreateAddress(address(factory), identifier)
			);
		}

		bytes32 original = encodeSalt(mode, guard, identifier, guarded ? user : address(0));
		bytes32 salt = processSalt(mode, guard, original, user);

		assertEq(
			factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE2, hash, original),
			computeCreate2Address(address(factory), hash, salt)
		);

		assertEq(
			factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE3, hash, original),
			computeCreate3Address(address(factory), salt)
		);

		address implementation = vm.addr(boundPrivateKey(uint256(hash)));

		assertEq(
			factory.computeCreateXAddress(
				ICreateXFactory.CreationType.CloneDeterministic,
				bytes32(bytes20(implementation)),
				original
			),
			computeCloneDeterministicAddress(address(factory), implementation, salt)
		);
	}

	function test_deployCreateERC20() public impersonate(user) {
		bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));

		address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		MockERC20 token = MockERC20(factory.deployCreate(initCode));

		assertEq(address(token), predicted);
		assertEq(address(token).balance, 0);
		assertEq(token.name(), "Mock Token");
		assertEq(token.symbol(), "MOCK");
		assertEq(token.decimals(), 18);
	}

	function test_deployCreate2ERC20() public impersonate(user) {
		bytes32 salt = encodeSalt(MODE_STRICT, GUARD_NONE, 0, user);
		bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));

		address predicted = computeCreate2Address(address(factory), keccak256(initCode), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockERC20 token = MockERC20(factory.deployCreate2(initCode, salt));

		assertEq(address(token), predicted);
		assertEq(address(token).balance, 0);
		assertEq(token.name(), "Mock Token");
		assertEq(token.symbol(), "MOCK");
		assertEq(token.decimals(), 18);
	}

	function test_deployCreate3ERC20() public impersonate(user) {
		bytes32 salt = encodeSalt(MODE_STRICT, GUARD_NONE, 0, user);
		bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));

		address predicted = computeCreate3Address(address(factory), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockERC20 token = MockERC20(factory.deployCreate3(initCode, salt));

		assertEq(address(token), predicted);
		assertEq(address(token).balance, 0);
		assertEq(token.name(), "Mock Token");
		assertEq(token.symbol(), "MOCK");
		assertEq(token.decimals(), 18);
	}

	function test_deployCreate(bytes32 key, uint256 value) public impersonate(user) {
		vm.assume(value <= user.balance);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		MockTarget instance = MockTarget(payable(factory.deployCreate{value: value}(initCode)));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCreate2(
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bool guarded,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		vm.assume(mode <= MODE_STRICT);
		vm.assume(guard <= GUARD_CALLER_AND_CHAIN);
		vm.assume(value <= user.balance);

		bytes32 original = encodeSalt(mode, guard, identifier, guarded ? user : address(0));
		bytes32 salt = processSalt(mode, guard, original, user);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = computeCreate2Address(address(factory), keccak256(initCode), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(payable(factory.deployCreate2{value: value}(initCode, original)));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCreate3(
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bool guarded,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		vm.assume(mode <= MODE_STRICT);
		vm.assume(guard <= GUARD_CALLER_AND_CHAIN);
		vm.assume(value <= user.balance);

		bytes32 original = encodeSalt(mode, guard, identifier, guarded ? user : address(0));
		bytes32 salt = processSalt(mode, guard, original, user);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = computeCreate3Address(address(factory), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(payable(factory.deployCreate3{value: value}(initCode, original)));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployClone(bytes32 key, uint256 value) public impersonate(user) {
		vm.assume(value <= user.balance);

		MockTarget mock = new MockTarget(key);
		address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		MockTarget instance = MockTarget(payable(factory.deployClone{value: value}(address(mock))));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), mock.key());
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCloneDeterministic(
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bool guarded,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		vm.assume(mode <= MODE_STRICT);
		vm.assume(guard <= GUARD_CALLER_AND_CHAIN);
		vm.assume(value <= user.balance);

		bytes32 original = encodeSalt(mode, guard, identifier, guarded ? user : address(0));
		bytes32 salt = processSalt(mode, guard, original, user);

		MockTarget mock = new MockTarget(key);
		address predicted = computeCloneDeterministicAddress(address(factory), address(mock), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(
			payable(factory.deployCloneDeterministic{value: value}(address(mock), original))
		);

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), mock.key());
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}
}

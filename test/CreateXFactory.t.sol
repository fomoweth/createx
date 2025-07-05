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
		user = createAccount("User", 1000 ether);
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
	}

	function test_deployCreateX(
		bool protected,
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		MockTarget instance;
		address predicted;
		address sender;

		if (protected) {
			mode = MODE_STRICT;
			sender = user;
		}

		value = bound(value, 0, user.balance);

		bytes32 original = encodeSalt(sender, mode, guard, identifier);
		bytes32 salt = processSalt(original, user);

		address mock = address(new MockTarget(key));
		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		bytes32 initCodeHash = keccak256(initCode);

		revertToState();
		predicted = factory.computeCreateAddress(vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		instance = MockTarget(
			factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE, initCode, original)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreate2Address(initCodeHash, original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE2, initCode, original)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreate3Address(original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			factory.deployCreateX{value: value}(ICreateXFactory.CreationType.CREATE3, initCode, original)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCreateAddress(vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		instance = MockTarget(
			factory.deployCreateX{value: value}(ICreateXFactory.CreationType.Clone, abi.encodePacked(mock), original)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);

		revertToState();
		predicted = factory.computeCloneDeterministicAddress(mock, original);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		instance = MockTarget(
			factory.deployCreateX{value: value}(
				ICreateXFactory.CreationType.CloneDeterministic,
				abi.encodePacked(mock),
				original
			)
		);
		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
	}

	function test_computeCreateXAddress(
		bool protected,
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bytes32 hash
	) public impersonate(user) {
		address sender;
		if (protected) {
			mode = MODE_STRICT;
			sender = user;
		}

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

		bytes32 original = encodeSalt(sender, mode, guard, identifier);
		bytes32 salt = processSalt(original, user);

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

	function test_deployCreate(bytes32 key, uint256 value) public impersonate(user) {
		value = bound(value, 0, user.balance);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		MockTarget instance = MockTarget(factory.deployCreate{value: value}(initCode));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
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

	function test_deployCreate2(
		bool protected,
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		value = bound(value, 0, user.balance);

		address sender;
		if (protected) {
			mode = MODE_STRICT;
			sender = user;
		}

		bytes32 original = generateSalt(sender, mode, guard, identifier);
		bytes32 salt = processSalt(original, user);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = computeCreate2Address(address(factory), keccak256(initCode), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(factory.deployCreate2{value: value}(initCode, original));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCreate2ERC20() public impersonate(user) {
		bytes32 salt = encodeSalt(user, MODE_RAW, GUARD_NONE, 0);
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

	function test_deployCreate3(
		bool protected,
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		value = bound(value, 0, user.balance);

		address sender;
		if (protected) {
			mode = MODE_STRICT;
			sender = user;
		}

		bytes32 original = encodeSalt(sender, mode, guard, identifier);
		bytes32 salt = processSalt(original, user);

		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(key));
		address predicted = computeCreate3Address(address(factory), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(factory.deployCreate3{value: value}(initCode, original));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), key);
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCreate3ERC20() public impersonate(user) {
		bytes32 salt = encodeSalt(user, MODE_RAW, GUARD_NONE, 0);
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

	function test_deployCreate3ChainAgnosticDeployment() public impersonate(user) {
		bytes32 salt = processSalt(encodeSalt(user, MODE_RAW, GUARD_NONE, 0));
		bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));

		vm.createSelectFork("ethereum");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address ethereum = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("optimism");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address optimism = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("bnb");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address bnb = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("polygon");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address polygon = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("unichain");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address unichain = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("fantom");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address fantom = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("base");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address base = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("arbitrum");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address arbitrum = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("avalanche");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address avalanche = factory.deployCreate3(initCode, salt);

		vm.createSelectFork("linea");
		factory = new CreateXFactory{salt: bytes32("CreateX")}();
		address linea = factory.deployCreate3(initCode, salt);

		assertEq(ethereum, optimism);
		assertEq(ethereum, bnb);
		assertEq(ethereum, polygon);
		assertEq(ethereum, unichain);
		assertEq(ethereum, fantom);
		assertEq(ethereum, base);
		assertEq(ethereum, arbitrum);
		assertEq(ethereum, avalanche);
		assertEq(ethereum, linea);
	}

	function test_deployCreate3_revertsDeploymentForSameSalt() public impersonate(user) {
		bytes32 salt = processSalt(encodeSalt(user, MODE_RAW, GUARD_NONE, 0));
		bytes memory initCode = bytes.concat(type(MockTarget).creationCode, abi.encode(bytes32("KEY")));

		factory.deployCreate3(initCode, salt);
		vm.expectRevert(CreateX.ProxyCreationFailed.selector);
		factory.deployCreate3(initCode, salt);
	}

	function test_deployCreate3_revertsDeploymentForSameSaltDifferentCode() public impersonate(user) {
		bytes32 salt = processSalt(encodeSalt(user, MODE_RAW, GUARD_NONE, 0));
		bytes memory mockInitCode = bytes.concat(type(MockTarget).creationCode, abi.encode(bytes32("KEY")));
		bytes memory tokenInitCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));

		factory.deployCreate3(mockInitCode, salt);
		vm.expectRevert(CreateX.ProxyCreationFailed.selector);
		factory.deployCreate3(tokenInitCode, salt);
	}

	function test_deployClone(bytes32 key, uint256 value) public impersonate(user) {
		value = bound(value, 0, user.balance);

		MockTarget mock = new MockTarget(key);
		address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, user);

		MockTarget instance = MockTarget(factory.deployClone{value: value}(address(mock)));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), mock.key());
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployClone_revertsIfInvalidImplementationGiven() public impersonate(user) {
		vm.expectRevert(CreateX.InvalidImplementation.selector);
		factory.deployClone(address(0));

		vm.expectRevert(CreateX.InvalidImplementation.selector);
		factory.deployClone(user);
	}

	function test_deployCloneDeterministic(
		bool protected,
		uint8 mode,
		uint8 guard,
		uint80 identifier,
		bytes32 key,
		uint256 value
	) public impersonate(user) {
		value = bound(value, 0, user.balance);

		address sender;
		if (protected) {
			mode = MODE_STRICT;
			sender = user;
		}

		bytes32 original = encodeSalt(sender, mode, guard, identifier);
		bytes32 salt = processSalt(original, user);

		MockTarget mock = new MockTarget(key);
		address predicted = computeCloneDeterministicAddress(address(factory), address(mock), salt);

		vm.expectEmit(true, true, true, true);
		emit ICreateXFactory.ContractCreation(predicted, salt, user);

		MockTarget instance = MockTarget(factory.deployCloneDeterministic{value: value}(address(mock), original));

		assertEq(address(instance), predicted);
		assertEq(address(instance).balance, value);
		assertEq(instance.key(), mock.key());
		assertEq(instance.getValue(), 0);
		instance.setValue(value);
		assertEq(instance.getValue(), value);
	}

	function test_deployCloneDeterministic_revertsIfInvalidImplementationGiven() public impersonate(user) {
		vm.expectRevert(CreateX.InvalidImplementation.selector);
		factory.deployCloneDeterministic(address(0), bytes32(0));

		vm.expectRevert(CreateX.InvalidImplementation.selector);
		factory.deployCloneDeterministic(user, bytes32(0));
	}

	function test_computeCreateAddress(address deployer, uint256 nonce) public {
		if (nonce >= type(uint64).max) {
			vm.expectRevert(CreateX.InvalidNonce.selector);
			factory.computeCreateAddress(nonce);
		} else {
			assertEq(CreateX.computeCreateAddress(deployer, nonce), vm.computeCreateAddress(deployer, nonce));
		}
	}

	function test_computeCreate2Address(address deployer, bytes32 hash, bytes32 salt) public pure {
		assertEq(CreateX.computeCreate2Address(deployer, hash, salt), computeCreate2Address(deployer, hash, salt));
	}

	function test_computeCreate3Address(address deployer, bytes32 salt) public pure {
		assertEq(CreateX.computeCreate3Address(deployer, salt), computeCreate3Address(deployer, salt));
	}

	function test_computeCloneDeterministicAddress(address deployer, address implementation, bytes32 salt) public pure {
		assertEq(
			CreateX.computeCloneDeterministicAddress(deployer, implementation, salt),
			computeCloneDeterministicAddress(deployer, implementation, salt)
		);
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Config} from "forge-std/Config.sol";
import {CreateXFactory, ICreateXFactory} from "src/CreateXFactory.sol";
import {CreateX} from "src/CreateX.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockTarget} from "test/mocks/MockTarget.sol";

contract CreateXFactoryTest is Test, Config {
    uint256 internal snapshotId = type(uint256).max;

    CreateXFactory internal factory;

    modifier impersonate(address account, uint256 value) {
        vm.assume(account != address(0));
        if (value != uint256(0)) deal(account, value);
        vm.startPrank(account);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.makePersistent(address(factory = new CreateXFactory()));
    }

    function test_fuzz_createX(bool protected, address deployer, uint96 identifier, uint256 value)
        public
        impersonate(deployer, value)
    {
        bytes memory initCode = type(MockTarget).creationCode;
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 salt = generateSalt(deployer, identifier, protected);

        address implementation = address(new MockTarget());
        address instance;
        address predicted;

        revertToState();

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(
            predicted = factory.computeCreateAddress(vm.getNonce(address(factory))), deployer
        );

        instance = factory.createX{value: value}(ICreateXFactory.CreationType.CREATE, initCode, salt);
        assertEq(instance, predicted);
        assertEq(instance.balance, value);
        revertToState();

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(
            predicted = factory.computeCreate2Address(initCodeHash, salt), deployer, salt
        );

        instance = factory.createX{value: value}(ICreateXFactory.CreationType.CREATE2, initCode, salt);
        assertEq(instance, predicted);
        assertEq(instance.balance, value);
        revertToState();

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted = factory.computeCreate3Address(salt), deployer, salt);

        instance = factory.createX{value: value}(ICreateXFactory.CreationType.CREATE3, initCode, salt);
        assertEq(instance, predicted);
        assertEq(instance.balance, value);
        revertToState();

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(
            predicted = factory.computeCreateAddress(vm.getNonce(address(factory))), deployer
        );

        initCode = abi.encodePacked(implementation);
        instance = factory.createX{value: value}(ICreateXFactory.CreationType.Clone, initCode, salt);
        assertEq(instance, predicted);
        assertEq(instance.balance, value);
        revertToState();

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(
            predicted = factory.computeCloneDeterministicAddress(implementation, salt), deployer, salt
        );

        instance = factory.createX{value: value}(ICreateXFactory.CreationType.CloneDeterministic, initCode, salt);
        assertEq(instance, predicted);
        assertEq(instance.balance, value);
    }

    function test_fuzz_computeCreateXAddress(bool protected, address deployer, uint96 identifier, bytes32 hash) public {
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

        bytes32 salt = generateSalt(deployer, identifier, protected);

        assertEq(
            factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE2, hash, salt),
            vm.computeCreate2Address(salt, hash, address(factory))
        );

        assertEq(
            factory.computeCreateXAddress(ICreateXFactory.CreationType.CREATE3, hash, salt),
            computeCreate3Address(address(factory), salt)
        );

        address implementation = vm.addr(boundPrivateKey(uint256(hash)));

        assertEq(
            factory.computeCreateXAddress(
                ICreateXFactory.CreationType.CloneDeterministic, bytes32(bytes20(implementation)), salt
            ),
            computeCloneDeterministicAddress(address(factory), implementation, salt)
        );
    }

    function test_fuzz_create(address deployer, uint256 value) public impersonate(deployer, value) {
        bytes memory initCode = type(MockTarget).creationCode;
        address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, deployer);

        MockTarget instance = MockTarget(factory.create{value: value}(initCode));
        assertEq(address(instance), predicted);
        assertEq(address(instance).balance, value);
        assertEq(instance.getValue(), uint256(0));
        assertEq(instance.setValue(value), value);
    }

    function test_create_deployERC20() public {
        bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));
        address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, address(this));

        MockERC20 token = MockERC20(factory.create(initCode));
        assertEq(address(token), predicted);
        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.decimals(), 18);
    }

    function test_fuzz_create2(bool protected, address deployer, uint96 identifier, uint256 value)
        public
        impersonate(deployer, value)
    {
        bytes memory initCode = type(MockTarget).creationCode;
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 salt = generateSalt(deployer, identifier, protected);
        address predicted = computeCreate2Address(address(factory), initCodeHash, salt);

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, deployer, salt);

        MockTarget instance = MockTarget(factory.create2{value: value}(initCode, salt));
        assertEq(address(instance), predicted);
        assertEq(address(instance).balance, value);
        assertEq(instance.getValue(), uint256(0));
        assertEq(instance.setValue(value), value);
    }

    function test_create2_deployERC20() public {
        bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 salt = generateSalt(address(0), uint96(0));
        address predicted = computeCreate2Address(address(factory), initCodeHash, salt);

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, address(this), salt);

        MockERC20 token = MockERC20(factory.create2(initCode, salt));
        assertEq(address(token), predicted);
        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.decimals(), 18);
    }

    function test_fuzz_create3(bool protected, address deployer, uint96 identifier, uint256 value)
        public
        impersonate(deployer, value)
    {
        bytes memory initCode = type(MockTarget).creationCode;
        bytes32 salt = generateSalt(deployer, identifier, protected);
        address predicted = computeCreate3Address(address(factory), salt);

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, deployer, salt);

        MockTarget instance = MockTarget(factory.create3{value: value}(initCode, salt));
        assertEq(address(instance), predicted);
        assertEq(address(instance).balance, value);
        assertEq(instance.getValue(), uint256(0));
        assertEq(instance.setValue(value), value);
    }

    function test_create3_deployERC20() public {
        bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));
        bytes32 salt = generateSalt(address(0), uint96(0));
        address predicted = computeCreate3Address(address(factory), salt);

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, address(this), salt);

        MockERC20 token = MockERC20(factory.create3(initCode, salt));
        assertEq(address(token), predicted);
        assertEq(token.name(), "Mock Token");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.decimals(), 18);
    }

    function test_create3_chainAgnosticDeployment() public {
        _loadConfigAndForks("./config/test.toml", false);

        uint256[] memory chains = config.getChainIds();
        assertGt(chains.length, 0);

        bytes memory initCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));
        bytes32 salt = generateSalt(address(this));

        vm.selectFork(forkOf[chains[0]]);
        address instance = factory.create3(initCode, salt);

        for (uint256 i = 1; i < chains.length; ++i) {
            vm.selectFork(forkOf[chains[i]]);
            assertEq(instance, factory.create3(initCode, salt));
        }
    }

    function test_create3_revertsOnSameSaltDeployments() public {
        bytes memory mockInitCode = type(MockTarget).creationCode;
        bytes memory erc20InitCode = bytes.concat(type(MockERC20).creationCode, abi.encode("Mock Token", "MOCK", 18));
        bytes32 salt = generateSalt(address(this));

        factory.create3(mockInitCode, salt);
        vm.expectRevert(CreateX.ProxyCreationFailed.selector);
        factory.create3(mockInitCode, salt);
        vm.expectRevert(CreateX.ProxyCreationFailed.selector);
        factory.create3(erc20InitCode, salt);
    }

    function test_fuzz_clone(address deployer, uint256 value) public impersonate(deployer, value) {
        address implementation = address(new MockTarget());
        address predicted = vm.computeCreateAddress(address(factory), vm.getNonce(address(factory)));

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, deployer);

        MockTarget instance = MockTarget(factory.clone{value: value}(implementation));
        assertEq(address(instance), predicted);
        assertEq(address(instance).balance, value);
        assertEq(instance.getValue(), uint256(0));
        assertEq(instance.setValue(value), value);
    }

    function test_clone_revertsIfInvalidImplementationGiven() public {
        vm.expectRevert(CreateX.InvalidImplementation.selector);
        factory.clone(address(0));

        vm.expectRevert(CreateX.InvalidImplementation.selector);
        factory.clone(address(0xdeadbeef));
    }

    function test_fuzz_cloneDeterministic(bool protected, address deployer, uint96 identifier, uint256 value)
        public
        impersonate(deployer, value)
    {
        bytes32 salt = generateSalt(deployer, identifier, protected);
        address implementation = address(new MockTarget());
        address predicted = computeCloneDeterministicAddress(address(factory), implementation, salt);

        vm.expectEmit(true, true, true, true);
        emit ICreateXFactory.ContractCreation(predicted, deployer, salt);

        MockTarget instance = MockTarget(factory.cloneDeterministic{value: value}(implementation, salt));
        assertEq(address(instance), predicted);
        assertEq(address(instance).balance, value);
        assertEq(instance.getValue(), uint256(0));
        assertEq(instance.setValue(value), value);
    }

    function test_cloneDeterministic_revertsIfInvalidImplementationGiven() public {
        vm.expectRevert(CreateX.InvalidImplementation.selector);
        factory.cloneDeterministic(address(0), bytes32(0));

        vm.expectRevert(CreateX.InvalidImplementation.selector);
        factory.cloneDeterministic(address(0xdeadbeef), bytes32(0));
    }

    function test_fuzz_computeCreateAddress(address deployer, uint256 nonce) public {
        if (nonce >= type(uint64).max) {
            vm.expectRevert(CreateX.InvalidNonce.selector);
            factory.computeCreateAddress(nonce);
        } else {
            assertEq(CreateX.computeCreateAddress(deployer, nonce), vm.computeCreateAddress(deployer, nonce));
        }
    }

    function test_fuzz_computeCreate2Address(address deployer, bytes32 hash, bytes32 salt) public pure {
        assertEq(CreateX.computeCreate2Address(deployer, hash, salt), computeCreate2Address(deployer, hash, salt));
    }

    function test_fuzz_computeCreate3Address(address deployer, bytes32 salt) public pure {
        assertEq(CreateX.computeCreate3Address(deployer, salt), computeCreate3Address(deployer, salt));
    }

    function test_fuzz_computeCloneDeterministicAddress(address deployer, address implementation, bytes32 salt)
        public
        pure
    {
        assertEq(
            CreateX.computeCloneDeterministicAddress(deployer, implementation, salt),
            computeCloneDeterministicAddress(deployer, implementation, salt)
        );
    }

    function computeCreate2Address(address deployer, bytes32 initCodeHash, bytes32 salt)
        internal
        pure
        returns (address predicted)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", deployer, salt, initCodeHash)))));
    }

    function computeCreate3Address(address deployer, bytes32 salt) internal pure returns (address predicted) {
        bytes32 initCodeHash = 0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;
        address proxy = computeCreate2Address(deployer, initCodeHash, salt);
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"d694", proxy, hex"01")))));
    }

    function computeCloneDeterministicAddress(address deployer, address implementation, bytes32 salt)
        internal
        pure
        returns (address predicted)
    {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
                bytes20(implementation),
                hex"5af43d82803e903d91602b57fd5bf3"
            )
        );
        return computeCreate2Address(deployer, initCodeHash, salt);
    }

    function generateSalt(address caller) internal view returns (bytes32 salt) {
        return generateSalt(caller, uint96(vm.randomUint(type(uint96).min, type(uint96).max)));
    }

    function generateSalt(address caller, uint96 identifier) internal pure returns (bytes32 salt) {
        return bytes32((uint256(uint160(caller)) << 96) | uint256(identifier));
    }

    function generateSalt(address caller, uint96 identifier, bool protected) internal pure returns (bytes32 salt) {
        return generateSalt(protected ? caller : address(0), identifier);
    }

    function revertToState() internal {
        if (snapshotId != type(uint256).max) vm.revertToState(snapshotId);
        snapshotId = vm.snapshotState();
    }
}

# CreateX

`CreateX` provides a comprehensive solution for deploying smart contracts using various creation opcodes and patterns, offering both a standalone library and a unified factory contract for traditional and deterministic deployment methods.

## Features

-   **CREATE**: Traditional contract deployment
-   **CREATE2**: Deterministic contract deployment
-   **CREATE3**: Chain-agnostic deterministic deployment
-   **EIP-1167 Clone**: Minimal proxy pattern deployment
-   **EIP-1167 CloneDeterministic**: Deterministic minimal proxy deployment
-   **Address Prediction**: Compute contract addresses before deployment
-   **Dual Approach**: Use as a library in your contracts or interact with the deployed factory

## Directory

```text
createx/
├── deployments/...
├── script/
│   ├── CreateX.s.sol
│   └── Deploy.s.sol
├── src/
│   ├── CreateX.sol
│   ├── CreateXFactory.sol
│   └── ICreateXFactory.sol
└── test/
    ├── mocks/...
    └── CreateXFactory.t.sol
```

## Usage

### Installation

```bash
forge install fomoweth/createx
```

### Build

```shell
forge build --sizes
```

### Test

```bash
# Run all tests
forge test

# Run with detailed traces
forge test -vvv

# Run with gas reporting
forge test --gas-report
```

### Deploy

```bash
forge script script/Deploy.s.sol:DeployScript \
    --broadcast \
    --multi \
    --slow \
    --verify \
    -vvvv
```

## Deployments

`CreateXFactory` is deployed on the following networks:

| Network      | Chain ID | Address                                                                                                                          |
| ------------ | -------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Ethereum     | 1        | [0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf](https://etherscan.io/address/0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf)            |
| Optimism     | 10       | [0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf](https://optimistic.etherscan.io/address/0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf) |
| Polygon      | 137      | [0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf](https://polygonscan.com/address/0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf)         |
| Base         | 8453     | [0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf](https://basescan.org/address/0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf)            |
| Arbitrum One | 42161    | [0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf](https://arbiscan.io/address/0xfC5D1D7b066730fC403C994365205a96fE1d8Bcf)             |

---

# CreateX Library

> A low-level library that enables deterministic contract deployments and proxy clones using various creation patterns with gas efficiency.

## Library API Reference

### Deployment Functions

```solidity
function create(bytes memory initCode) internal returns (address);
function create(bytes memory initCode, uint256 value) internal returns (address);

function create2(bytes memory initCode, bytes32 salt) internal returns (address);
function create2(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address);

function create3(bytes memory initCode, bytes32 salt) internal returns (address);
function create3(bytes memory initCode, bytes32 salt, uint256 value) internal returns (address);

function clone(address implementation) internal returns (address);
function clone(address implementation, uint256 value) internal returns (address);

function cloneDeterministic(address implementation, bytes32 salt) internal returns (address);
function cloneDeterministic(address implementation, bytes32 salt, uint256 value) internal returns (address);
```

### Address Prediction Functions

```solidity
function computeCreateAddress(uint256 nonce) internal view returns (address);
function computeCreateAddress(address deployer, uint256 nonce) internal pure returns (address);

function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) internal view returns (address);
function computeCreate2Address(address deployer, bytes32 initCodeHash, bytes32 salt) internal pure returns (address);

function computeCreate3Address(bytes32 salt) internal view returns (address);
function computeCreate3Address(address deployer, bytes32 salt) internal pure returns (address);

function computeCloneDeterministicAddress(address implementation, bytes32 salt) internal view returns (address);
function computeCloneDeterministicAddress(address deployer, address implementation, bytes32 salt) internal pure returns (address);
```

### Example Usage

Import and use the library functions directly:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateX} from "lib/createx/src/CreateX.sol";

contract MyContract {
    function deployCreate(bytes calldata initCode) external payable returns (address) {
        return CreateX.create(initCode, msg.value);
    }

    function deployCreate2(bytes calldata initCode, bytes32 salt) external payable returns (address) {
        return CreateX.create2(initCode, salt, msg.value);
    }

    function deployCreate3(bytes calldata initCode, bytes32 salt) external payable returns (address) {
        return CreateX.create3(initCode, salt, msg.value);
    }

    function deployClone(address implementation) external payable returns (address) {
        return CreateX.clone(implementation, msg.value);
    }

    function deployCloneDeterministic(address implementation, bytes32 salt) external payable returns (address) {
        return CreateX.cloneDeterministic(implementation, salt, msg.value);
    }

    function computeAddress(uint256 nonce) public view returns (address) {
        return CreateX.computeCreateAddress(nonce);
    }

    function computeAddress(bytes32 initCodeHash, bytes32 salt) public view returns (address) {
        return CreateX.computeCreate2Address(initCodeHash, salt);
    }

    function computeAddress(bytes32 salt) public view returns (address) {
        return CreateX.computeCreate3Address(salt);
    }

    function computeAddress(address implementation, bytes32 salt) public view returns (address) {
        return CreateX.computeCloneDeterministicAddress(implementation, salt);
    }
}
```

---

# CreateX Factory

> A public deployment contract that exposes CreateX capabilities via a unified interface with salt guard.

## Factory API Reference

### Creation Types

```solidity
enum CreationType {
    CREATE,              // 0 – traditional deployment
    CREATE2,             // 1 – deterministic deployment
    CREATE3,             // 2 – chain-agnostic deployment
    Clone,               // 3 – EIP-1167 via CREATE
    CloneDeterministic   // 4 – EIP-1167 via CREATE2
}
```

### Deployment Functions

```solidity
function createX(
    CreationType creationType,
    bytes calldata initCode,
    bytes32 salt
) external payable returns (address);

function create(bytes calldata initCode) external payable returns (address);

function create2(bytes calldata initCode, bytes32 salt) external payable returns (address);

function create3(bytes calldata initCode, bytes32 salt) external payable returns (address);

function clone(address implementation) external payable returns (address);

function cloneDeterministic(address implementation, bytes32 salt) external payable returns (address);
```

### Address Prediction Functions

```solidity
function computeCreateXAddress(CreationType creationType, bytes32 initCodeHash, bytes32 salt) external view returns (address);

function computeCreateAddress(uint256 nonce) external view returns (address);

function computeCreate2Address(bytes32 initCodeHash, bytes32 salt) external view returns (address);

function computeCreate3Address(bytes32 salt) external view returns (address);

function computeCloneDeterministicAddress(address implementation, bytes32 salt) external view returns (address);
```

### Events

The factory emits events for all deployments:

```solidity
event ContractCreation(address indexed instance, address indexed deployer);

event ContractCreation(address indexed instance, address indexed deployer, bytes32 indexed salt);
```

### Custom Errors

Both the library and factory include comprehensive error handling:

```solidity
error ContractCreationFailed();    // Deployment failed
error ProxyCreationFailed();       // CREATE3 proxy deployment failed
error InsufficientBalance();       // Insufficient ETH balance
error InvalidImplementation();     // Invalid implementation address for proxies
error InvalidNonce();              // Nonce exceeds EIP-2681 limit
error InvalidCreationType();       // Unsupported creation type (factory only)
error InvalidSalt();               // Salt validation failed (factory only)
```

### Example Usage

Import the interface and interact with the deployed factory:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ICreateXFactory} from "lib/createx/src/ICreateXFactory.sol";

contract MyContract {
    ICreateXFactory public immutable factory;

	constructor(address _factory) {
		factory = ICreateXFactory(_factory);
	}

    function deployCreate(bytes calldata initCode) external payable returns (address) {
        return factory.create{value: msg.value}(initCode);
    }

    function deployCreate2(bytes calldata initCode, bytes32 salt) external payable returns (address) {
        return factory.create2{value: msg.value}(initCode, salt);
    }

    function deployCreate3(bytes calldata initCode, bytes32 salt) external payable returns (address) {
        return factory.create3{value: msg.value}(initCode, salt);
    }

    function deployClone(address implementation) external payable returns (address) {
        return factory.clone{value: msg.value}(implementation);
    }

    function deployCloneDeterministic(address implementation, bytes32 salt) external payable returns (address) {
        return factory.cloneDeterministic{value: msg.value}(implementation, salt);
    }

    function computeAddress(uint256 nonce) public view returns (address) {
        return factory.computeCreateAddress(nonce);
    }

    function computeAddress(bytes32 initCodeHash, bytes32 salt) public view returns (address) {
        return factory.computeCreate2Address(initCodeHash, salt);
    }

    function computeAddress(bytes32 salt) public view returns (address) {
        return factory.computeCreate3Address(salt);
    }

    function computeAddress(address implementation, bytes32 salt) public view returns (address) {
        return factory.computeCloneDeterministicAddress(implementation, salt);
    }
}
```

### Unified Deployment Interface

The factory provides a single function that supports all deployment methods:

```solidity
function deployCreateX(
    ICreateXFactory.CreationType creationType,
    bytes calldata initCode,
    bytes32 salt
) external payable returns (address) {
    return factory.createX{value: msg.value}(creationType, initCode, salt);
}
```

### Salt Validation

The factory includes built-in access control through salt validation:

-   For salted deployments (CREATE2, CREATE3, CloneDeterministic), the first 20 bytes of the salt must match either:
    -   The caller's address (for user-specific deployments)
    -   Zero address (for open deployments)

---

## Acknowledgements

The following repositories served as key references during the development of this project:

-   [Solady](https://github.com/Vectorized/solady)
-   [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts)

## Author

-   [fomoweth](https://github.com/fomoweth)

# CreateX & CreateXFactory

A modular deployment toolkit for Ethereum smart contracts, supporting multiple creation strategies including `CREATE`, `CREATE2`, `CREATE3`, and `EIP-1167` minimal proxy clones.

---

## CreateX

> Deployment Primitives Library

`CreateX` is a gas‑optimized Solidity library that exposes low‑level helpers for every major contract‑creation opcode and pattern.

### Features

- Minimal and gas-optimized assembly implementations – no external dependencies
- Deterministic address computation
- Forward ETH with any deployment type
- Reverts on failure using custom errors instead of returning zero addresses

### API Surface

| Method                                                             | Purpose                                         |
| ------------------------------------------------------------------ | ----------------------------------------------- |
| `create(initCode, value)`                                          | Deploy with `CREATE`                            |
| `computeCreateAddress(deployer, nonce)`                            | Predict address for `CREATE`                    |
| `create2(initCode, salt, value)`                                   | Deploy with `CREATE2`                           |
| `computeCreate2Address(deployer, hash, salt)`                      | Predict address for `CREATE2`                   |
| `create3(initCode, salt, value)`                                   | Deploy via proxy + `CREATE` (`CREATE3` pattern) |
| `computeCreate3Address(deployer, salt)`                            | Predict address for `CREATE3`                   |
| `clone(implementation, value)`                                     | Deploy minimal proxy via `CREATE`               |
| `cloneDeterministic(implementation, salt, value)`                  | Deploy minimal proxy via `CREATE2`              |
| `computeCloneDeterministicAddress(deployer, implementation, salt)` | Predict clone address                           |

### Usage

```solidity
// deterministic CREATE2 deployment
bytes memory initCode = type(MyContract).creationCode;
bytes32 initCodeHash = keccak256(initCode);
bytes32 salt = keccak256("example");

address predicted = CreateX.computeCreate2Address(address(this), initCodeHash, salt);
address instance = CreateX.create2(initCode, salt, 0);
require(instance == predicted, "unexpected address");
```

---

## CreateXFactory

> Public Deployment Contract

The `CreateXFactory` is a multi-chain compatible factory for deploying contracts using the `CreateX` primitives. It enables external users and protocols to deploy smart contracts deterministically with salt protection and creation type abstraction.

### Key Features

- Unified deployment entrypoint via `deployCreateX()`
- Unified address prediction via `computeCreateXAddress()`
- Supports `CREATE`, `CREATE2`, `CREATE3`, and `EIP-1167` minimal proxy clones
- Strict and guarded salt protection (anti-front-running)
- Compatible with multi-chain deployments

### Salt Protection Mechanism

```solidity
// Salt Layout: [0..19] caller prefix | [20..29] identifier | [30] guard | [31] mode

enum Mode {
	Raw,		// 0 – uses original salt without modification
	Strict,		// 1 – enforces salt prefix matches caller or zero address
	Guarded 	// 2 – apply guard logic (Caller / Chain / CallerAndChain)
}

enum Guard {
	None,			// 0 – no guard, uses original salt
	Caller,			// 1 – combines caller address with salt
	Chain,			// 2 – combines chain ID with salt
	CallerAndChain	// 3 – combines caller address, chain ID, and salt
}
```

### Deployment Functions

```solidity
function deployCreateX(CreationType creationType, bytes calldata initCode, bytes32 salt) external returns (address);

function deployCreate(bytes calldata initCode) external returns (address);
function deployCreate2(bytes calldata initCode, bytes32 salt) external returns (address);
function deployCreate3(bytes calldata initCode, bytes32 salt) external returns (address);

function deployClone(address implementation) external returns (address);
function deployCloneDeterministic(address implementation, bytes32 salt) external returns (address);
```

### Address Prediction Helpers

```solidity
function computeCreateXAddress(CreationType creationType, bytes32 hash, bytes32 salt) external view returns (address);

function computeCreateAddress(uint256 nonce) external view returns (address);
function computeCreate2Address(bytes32 hash, bytes32 salt) external view returns (address);
function computeCreate3Address(bytes32 salt) external view returns (address);

function computeCloneDeterministicAddress(address implementation, bytes32 salt) external view returns (address);
```

### Usage Snippet

```solidity
// deterministic CREATE3 deployment
ICreateXFactory factory = ICreateXFactory(FACTORY);

bytes memory initCode = type(MyContract).creationCode;

bytes32 salt  = bytes32(
	abi.encodePacked(
		msg.sender,
		uint80(0x00), // identifier
		ICreateXFactory.Guard.CallerAndChain,
		ICreateXFactory.Mode.Guarded
	)
);

address predicted = factory.computeCreateXAddress(
	ICreateXFactory.CreationType.CREATE3,
	bytes32(0),
	salt
);

address instance = factory.deployCreateX{value: msg.value}(
	ICreateXFactory.CreationType.CREATE3,
	initCode,
	salt
);

require(instance == predicted, "unexpected address");
```

### Deployments

| Chain ID | Network Name     | Address                                                                                                                       |
| -------- | ---------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 84532    | Base Sepolia     | [0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF](https://sepolia.basescan.org/address/0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF) |
| 421614   | Arbitrum Sepolia | [0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF](https://sepolia.arbiscan.io/address/0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF)  |
| 11155111 | Sepolia          | [0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF](https://sepolia.etherscan.io/address/0xaeE0e8254d6AAA8335c575FBfB0cb39AFcdae0bF) |

---

## Author

- [@fomoweth](https://github.com/fomoweth)

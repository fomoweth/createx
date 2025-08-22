// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2 as console, stdJson} from "forge-std/Script.sol";
import {CreateXFactory} from "src/CreateXFactory.sol";

contract Deploy is Script {
	using stdJson for string;

	string private constant DEFAULT_MNEMONIC = "test test test test test test test test test test test junk";
	bytes32 private constant DEFAULT_SALT = 0x0000000000000000000000000000000000000000000000000000000000000000;

	address internal broadcaster;
	bytes32 internal salt;

	modifier broadcast(string memory chainAlias) {
		vm.createSelectFork(chainAlias);
		vm.startBroadcast(broadcaster);
		_;
		vm.stopBroadcast();
	}

	function setUp() public {
		uint256 privateKey = vm.envOr({
			name: "PRIVATE_KEY",
			defaultValue: vm.deriveKey({
				mnemonic: vm.envOr({name: "MNEMONIC", defaultValue: DEFAULT_MNEMONIC}),
				index: uint8(vm.envOr({name: "EOA_INDEX", defaultValue: uint256(0)}))
			})
		});

		broadcaster = vm.rememberKey(privateKey);
		salt = vm.envOr({name: "SALT", defaultValue: DEFAULT_SALT});
	}

	function run() external {
		string[] memory chainAliases = vm.envString({name: "CHAINS", delim: ","});
		for (uint256 i; i < chainAliases.length; ++i) deployToChain(chainAliases[i]);
	}

	function deployToChain(string memory chainAlias) internal broadcast(chainAlias) {
		string memory path = string.concat("./deployments/", vm.toString(block.chainid), ".json");

		console.log();
		console.log("======================================================================");
		console.log("Chain ID:", block.chainid);

		CreateXFactory createXFactory = new CreateXFactory{salt: salt}();

		string memory json = "deployment";
		json.serialize("address", address(createXFactory));
		json.serialize("block", block.number);
		json.serialize("salt", salt);
		json = json.serialize("timestamp", block.timestamp);
		json.write(path);

		console.log("Deployed at:", address(createXFactory));
		console.log("======================================================================");
		console.log();
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2 as console, stdJson} from "forge-std/Script.sol";
import {CreateXFactory} from "src/CreateXFactory.sol";

contract Deploy is Script {
	using stdJson for string;

	string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";

	modifier broadcast(string memory chainAlias, address broadcaster) {
		vm.createSelectFork(chainAlias);
		vm.startBroadcast(broadcaster);
		_;
		vm.stopBroadcast();
	}

	function run() external {
		address deployer = configureBroadcaster();
		bytes32 salt = vm.envBytes32("SALT");

		string[] memory chains = vm.envString("CHAINS", ",");

		for (uint256 i; i < chains.length; ++i) {
			deployToChain(chains[i], deployer, salt);
		}
	}

	function deployToChain(
		string memory chainAlias,
		address deployer,
		bytes32 salt
	) internal broadcast(chainAlias, deployer) {
		Chain memory chain = getChain(block.chainid);
		string memory path = string.concat("./deployments/", vm.toString(chain.chainId), ".json");

		console.log("======================================================================");
		console.log("Deploying on:", chain.name);

		CreateXFactory createXFactory = new CreateXFactory{salt: salt}();

		string memory obj = "chain";
		obj.serialize("id", chain.chainId);
		obj.serialize("alias", chainAlias);
		obj = obj.serialize("name", chain.name);

		string memory json = "deployment";
		json.serialize("address", address(createXFactory));
		json.serialize("deployer", deployer);
		json.serialize("salt", salt);
		json.serialize("block", block.number);
		json.serialize("timestamp", block.timestamp);
		json = json.serialize("chain", obj);
		json.write(path);

		console.log("Deployed at:", address(createXFactory));
		console.log("File Path:", path);
		console.log("======================================================================");
	}

	function configureBroadcaster() internal virtual returns (address) {
		uint256 privateKey = vm.envOr({
			name: "PRIVATE_KEY",
			defaultValue: vm.deriveKey({
				mnemonic: vm.envOr({name: "MNEMONIC", defaultValue: TEST_MNEMONIC}),
				index: uint8(vm.envOr({name: "EOA_INDEX", defaultValue: uint256(0)}))
			})
		});

		return vm.rememberKey(privateKey);
	}
}

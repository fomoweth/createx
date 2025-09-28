// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateXFactory} from "src/CreateXFactory.sol";
import {BaseScript} from "./BaseScript.sol";

contract Deploy is BaseScript {
    bytes32 internal salt;

    function setUp() public virtual override {
        super.setUp();
        salt = vm.envOr({name: "SALT", defaultValue: defaultSalt()});
    }

    function run() external {
        string[] memory chainAliases = promptChains();
        for (uint256 i; i < chainAliases.length; ++i) {
            deployOnChain(chainAliases[i]);
        }
    }

    function deployOnChain(string memory chainAlias) internal fork(chainAlias) broadcast {
        string memory path = string.concat(vm.projectRoot(), "/deployments/", vm.toString(block.chainid), ".json");
        generateJson(path, "CreateXFactory", address(new CreateXFactory{salt: salt}()), salt);
    }
}

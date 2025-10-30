// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CreateXFactory} from "src/CreateXFactory.sol";
import {BaseScript} from "./BaseScript.sol";

contract DeployScript is BaseScript {
    bytes32 internal salt;

    function setUp() public virtual override {
        super.setUp();
        salt = vm.envOr({name: "SALT", defaultValue: bytes32(0)});
    }

    function run(uint256 chainId) external {
        deployToChain(chainId);
    }

    function run(uint256[] memory chains) external {
        for (uint256 i = 0; i < chains.length; ++i) {
            deployToChain(chains[i]);
        }
    }

    function run() external {
        uint256[] memory chains = config.getChainIds();
        for (uint256 i = 0; i < chains.length; ++i) {
            deployToChain(chains[i]);
        }
    }

    function deployToChain(uint256 chainId) internal fork(chainId) broadcast {
        string memory path = string.concat(vm.projectRoot(), "/deployments/", vm.toString(chainId), ".json");
        generateJson(path, "CreateXFactory", address(new CreateXFactory{salt: salt}()), salt);
    }
}

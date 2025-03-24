// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {stdJson} from "forge-std/StdJson.sol";
import "forge-std/Vm.sol";

library Utils {
    using stdJson for string;

    /**
     * @dev Get the service manager address from the deployments.json file.
     * @param vm The VM instance.
     * @return serviceManager The service manager address.
     */
    function getServiceManager(Vm vm) public returns (address serviceManager) {
        string memory deploymentsPath = string.concat(
            vm.projectRoot(),
            "/.docker/deployments.json"
        );

        serviceManager = vm.readFile(deploymentsPath).readAddress(
            ".eigen_service_managers.local[0]"
        );
    }

    /**
     * @dev Get the Hats protocol address from environment or default.
     * @param vm The VM instance.
     * @return hatsAddress The Hats protocol address.
     */
    function getHatsProtocol(Vm vm) public returns (address hatsAddress) {
        hatsAddress = vm.envOr("HATS_PROTOCOL_ADDRESS", address(0));
    }

    /**
     * @dev Get the Hats module factory address from environment or default.
     * @param vm The VM instance.
     * @return factoryAddress The Hats module factory address.
     */
    function getHatsModuleFactory(
        Vm vm
    ) public returns (address factoryAddress) {
        factoryAddress = vm.envOr("HATS_MODULE_FACTORY_ADDRESS", address(0));
    }

    /**
     * @dev Get the private key and deployer address for the local Anvil network.
     * @param vm The VM instance.
     * @return privateKey The private key.
     * @return deployer The deployer address.
     */
    function getPrivateKey(
        Vm vm
    ) public returns (uint256 privateKey, address deployer) {
        // Anvil's first default account private key
        privateKey = vm.envOr(
            "ANVIL_PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );
        deployer = vm.addr(privateKey);
    }

    /**
     * @dev Append the given content to the .env file.
     * @param vm The VM instance.
     * @param content The content to append.
     */
    function saveEnvVars(Vm vm, string memory content) public {
        vm.writeLine(string.concat(vm.projectRoot(), "/.env"), content);
    }
}

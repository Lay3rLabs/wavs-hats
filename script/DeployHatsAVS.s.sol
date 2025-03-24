// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {HatsModuleFactory} from "@hats-module/src/HatsModuleFactory.sol";
// Import Hats Protocol and Hats Module Factory for deployment
import {Hats} from "hats-protocol/Hats.sol";
import {Utils} from "./Utils.sol";

import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {HatsAVSHatter} from "../src/contracts/HatsAVSHatter.sol";
import {HatsAVSManager} from "../src/contracts/HatsAVSManager.sol";
import {IHatsEligibilityServiceHandler} from "../src/interfaces/IHatsEligibilityServiceHandler.sol";
import {IHatsToggleServiceHandler} from "../src/interfaces/IHatsToggleServiceHandler.sol";

/**
 * @title DeployHatsAVS
 * @notice Deployment script for the Hats Protocol WAVS AVS integration
 */
contract DeployHatsAVS is Script {
    // Default values for constructor parameters
    uint256 public constant DEFAULT_ELIGIBILITY_CHECK_COOLDOWN = 1 hours;
    uint256 public constant DEFAULT_STATUS_CHECK_COOLDOWN = 4 hours;
    string public constant VERSION = "0.1.0";

    /**
     * @notice Run the deployment script
     */
    function run() public {
        // Get deployment parameters from environment
        address serviceManagerAddr = vm.envOr(
            "SERVICE_MANAGER_ADDRESS",
            Utils.getServiceManager(vm)
        );

        // Get or deploy Hats Protocol
        address hatsAddr = getOrDeployHatsProtocol();

        // Get or deploy Hats Module Factory
        address moduleFactoryAddr = getOrDeployHatsModuleFactory(hatsAddr);

        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        console.log("Deployer address:", deployer);
        console.log("Service Manager address:", serviceManagerAddr);
        console.log("Hats Protocol address:", hatsAddr);
        console.log("Hats Module Factory address:", moduleFactoryAddr);

        // Create instances of the external contracts
        // Keeping the service manager reference for future use (suppress unused warning)
        IWavsServiceManager serviceManager;
        serviceManager = IWavsServiceManager(serviceManagerAddr);
        IHats hats = IHats(hatsAddr);
        HatsModuleFactory moduleFactory = HatsModuleFactory(moduleFactoryAddr);

        // Start broadcasting transactions with the private key
        vm.startBroadcast(privateKey);

        // Deploy the module implementations
        HatsEligibilityServiceHandler eligibilityImpl = new HatsEligibilityServiceHandler(
                hats,
                serviceManagerAddr,
                VERSION
            );
        console.log(
            "HatsEligibilityServiceHandler implementation deployed at: %s",
            address(eligibilityImpl)
        );

        HatsToggleServiceHandler toggleImpl = new HatsToggleServiceHandler(
            hats,
            serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsToggleServiceHandler implementation deployed at: %s",
            address(toggleImpl)
        );

        HatsAVSHatter hatterImpl = new HatsAVSHatter(
            hats,
            serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAVSHatter implementation deployed at: %s",
            address(hatterImpl)
        );

        // Create module instances via factory
        address eligibilityHandler = moduleFactory.createHatsModule(
            address(eligibilityImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // immutable flag as uint256 (0 for false, 1 for true)
        );
        console.log(
            "HatsEligibilityServiceHandler instance deployed at: %s",
            eligibilityHandler
        );

        address toggleHandler = moduleFactory.createHatsModule(
            address(toggleImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // immutable flag as uint256 (0 for false, 1 for true)
        );
        console.log(
            "HatsToggleServiceHandler instance deployed at: %s",
            toggleHandler
        );

        address hatter = moduleFactory.createHatsModule(
            address(hatterImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // immutable flag as uint256 (0 for false, 1 for true)
        );
        console.log("HatsAVSHatter instance deployed at: %s", hatter);

        // Deploy the manager contract with the correct interface casts
        HatsAVSManager manager = new HatsAVSManager(
            hats,
            IHatsEligibilityServiceHandler(eligibilityHandler),
            IHatsToggleServiceHandler(toggleHandler),
            DEFAULT_ELIGIBILITY_CHECK_COOLDOWN,
            DEFAULT_STATUS_CHECK_COOLDOWN
        );
        console.log("HatsAVSManager deployed at: %s", address(manager));

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Save addresses to .env file
        string memory envVars = string.concat(
            "# Hats Protocol AVS Integration Addresses\n",
            "HATS_PROTOCOL_ADDRESS=",
            addressToString(hatsAddr),
            "\n",
            "HATS_MODULE_FACTORY_ADDRESS=",
            addressToString(moduleFactoryAddr),
            "\n",
            "HATS_ELIGIBILITY_SERVICE_HANDLER_IMPL=",
            addressToString(address(eligibilityImpl)),
            "\n",
            "HATS_TOGGLE_SERVICE_HANDLER_IMPL=",
            addressToString(address(toggleImpl)),
            "\n",
            "HATS_AVS_HATTER_IMPL=",
            addressToString(address(hatterImpl)),
            "\n",
            "HATS_ELIGIBILITY_SERVICE_HANDLER=",
            addressToString(eligibilityHandler),
            "\n",
            "HATS_TOGGLE_SERVICE_HANDLER=",
            addressToString(toggleHandler),
            "\n",
            "HATS_AVS_HATTER=",
            addressToString(hatter),
            "\n",
            "HATS_AVS_MANAGER=",
            addressToString(address(manager)),
            "\n"
        );

        Utils.saveEnvVars(vm, envVars);
        console.log("Addresses saved to .env file");

        // Log deployment completion
        console.log("Hats Protocol WAVS AVS integration deployed successfully");
    }

    /**
     * @notice Get or deploy the Hats Protocol contract
     * @return hatsAddr The address of the Hats Protocol contract
     */
    function getOrDeployHatsProtocol() internal returns (address hatsAddr) {
        // Try to get the Hats Protocol address from env
        hatsAddr = vm.envOr("HATS_PROTOCOL_ADDRESS", address(0));

        // If not set, deploy a new instance
        if (hatsAddr == address(0)) {
            console.log(
                "Hats Protocol address not set, deploying new instance..."
            );

            (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);
            vm.startBroadcast(privateKey);

            // Deploy Hats Protocol
            // Check constructor parameters based on the latest version
            Hats hatsProtocol = new Hats(
                "Hats Protocol Local", // name
                "https://app.hatsprotocol.xyz/trees/" // baseImageURI
            );

            hatsAddr = address(hatsProtocol);
            vm.stopBroadcast();

            console.log("Deployed new Hats Protocol at:", hatsAddr);
        } else {
            console.log("Using existing Hats Protocol at:", hatsAddr);
        }
    }

    /**
     * @notice Get or deploy the Hats Module Factory contract
     * @param _hatsAddr The address of the Hats Protocol contract
     * @return factoryAddr The address of the Hats Module Factory contract
     */
    function getOrDeployHatsModuleFactory(
        address _hatsAddr
    ) internal returns (address factoryAddr) {
        // Try to get the Hats Module Factory address from env
        factoryAddr = vm.envOr("HATS_MODULE_FACTORY_ADDRESS", address(0));

        // If not set, deploy a new instance
        if (factoryAddr == address(0)) {
            console.log(
                "Hats Module Factory address not set, deploying new instance..."
            );

            (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);
            vm.startBroadcast(privateKey);

            // Deploy Hats Module Factory
            HatsModuleFactory factory = new HatsModuleFactory(
                IHats(_hatsAddr),
                "1.0.0" // version
            );

            factoryAddr = address(factory);
            vm.stopBroadcast();

            console.log("Deployed new Hats Module Factory at:", factoryAddr);
        } else {
            console.log("Using existing Hats Module Factory at:", factoryAddr);
        }
    }

    /**
     * @dev Convert an address to a string
     * @param _addr The address to convert
     * @return The string representation of the address
     */
    function addressToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_addr);
        bytes memory stringBytes = new bytes(42);

        stringBytes[0] = "0";
        stringBytes[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            uint8 leftNibble = uint8(addressBytes[i]) / 16;
            uint8 rightNibble = uint8(addressBytes[i]) % 16;

            stringBytes[2 + i * 2] = leftNibble < 10
                ? bytes1(leftNibble + 48)
                : bytes1(leftNibble + 87);
            stringBytes[2 + i * 2 + 1] = rightNibble < 10
                ? bytes1(rightNibble + 48)
                : bytes1(rightNibble + 87);
        }

        return string(stringBytes);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {HatsModuleFactory} from "@hats-module/src/HatsModuleFactory.sol";

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
     * @param _serviceManagerAddr The address of the WAVS service manager
     * @param _hatsAddr The address of the Hats protocol contract
     * @param _moduleFactoryAddr The address of the Hats module factory
     */
    function run(
        string memory _serviceManagerAddr,
        string memory _hatsAddr,
        string memory _moduleFactoryAddr
    ) public {
        // Convert addresses from strings
        address serviceManagerAddr = vm.parseAddress(_serviceManagerAddr);
        address hatsAddr = vm.parseAddress(_hatsAddr);
        address moduleFactoryAddr = vm.parseAddress(_moduleFactoryAddr);

        // Create instances of the external contracts
        IWavsServiceManager serviceManager = IWavsServiceManager(
            serviceManagerAddr
        );
        IHats hats = IHats(hatsAddr);
        HatsModuleFactory moduleFactory = HatsModuleFactory(moduleFactoryAddr);

        // Start broadcasting transactions
        vm.startBroadcast();

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
        // Check the correct parameters for the factory from the hats-module docs
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

        // Log deployment completion
        console.log("Hats Protocol WAVS AVS integration deployed successfully");
    }
}

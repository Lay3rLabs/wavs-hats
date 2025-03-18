// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/src/Interfaces/IHats.sol";

import {HatsAVSTrigger} from "../src/contracts/HatsAVSTrigger.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {HatsAVSManager} from "../src/contracts/HatsAVSManager.sol";

/**
 * @title DeployHatsAVS
 * @notice Deployment script for the Hats Protocol WAVS AVS integration
 */
contract DeployHatsAVS is Script {
    // Default values for constructor parameters
    uint256 public constant DEFAULT_ELIGIBILITY_CHECK_COOLDOWN = 1 hours;
    uint256 public constant DEFAULT_STATUS_CHECK_COOLDOWN = 4 hours;

    /**
     * @notice Run the deployment script
     * @param _serviceManagerAddr The address of the WAVS service manager
     * @param _hatsAddr The address of the Hats protocol contract
     */
    function run(
        string memory _serviceManagerAddr,
        string memory _hatsAddr
    ) public {
        // Convert addresses from strings
        address serviceManagerAddr = vm.parseAddress(_serviceManagerAddr);
        address hatsAddr = vm.parseAddress(_hatsAddr);

        // Create instances of the external contracts
        IWavsServiceManager serviceManager = IWavsServiceManager(
            serviceManagerAddr
        );
        IHats hats = IHats(hatsAddr);

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the trigger contract
        HatsAVSTrigger trigger = new HatsAVSTrigger();
        console.log("HatsAVSTrigger deployed at: %s", address(trigger));

        // Deploy the eligibility service handler
        HatsEligibilityServiceHandler eligibilityHandler = new HatsEligibilityServiceHandler(
                serviceManager,
                trigger
            );
        console.log(
            "HatsEligibilityServiceHandler deployed at: %s",
            address(eligibilityHandler)
        );

        // Deploy the toggle service handler
        HatsToggleServiceHandler toggleHandler = new HatsToggleServiceHandler(
            serviceManager,
            trigger
        );
        console.log(
            "HatsToggleServiceHandler deployed at: %s",
            address(toggleHandler)
        );

        // Deploy the manager contract
        HatsAVSManager manager = new HatsAVSManager(
            hats,
            eligibilityHandler,
            toggleHandler,
            trigger,
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

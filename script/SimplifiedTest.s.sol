// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title SimplifiedTest
 * @notice Simplified script to test the Hats Protocol WAVS AVS integration
 */
contract SimplifiedTest is Script {
    // Define constants
    address constant DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /**
     * @notice Run the simplified test script
     */
    function run() public {
        // Get deployment addresses from environment
        address eligibilityHandlerAddr = vm.envAddress(
            "HATS_ELIGIBILITY_SERVICE_HANDLER"
        );
        address toggleHandlerAddr = vm.envAddress(
            "HATS_TOGGLE_SERVICE_HANDLER"
        );

        console.log(
            "Hats Eligibility Service Handler address:",
            eligibilityHandlerAddr
        );
        console.log("Hats Toggle Service Handler address:", toggleHandlerAddr);

        // Create contract instances
        HatsEligibilityServiceHandler eligibilityHandler = HatsEligibilityServiceHandler(
                eligibilityHandlerAddr
            );
        HatsToggleServiceHandler toggleHandler = HatsToggleServiceHandler(
            toggleHandlerAddr
        );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test with hardcoded hat ID - using a simple value for testing
        uint256 testHatId = 1; // Just use a simple ID for testing

        // 1. Test eligibility check
        console.log("\n1. Testing eligibility check");
        try
            eligibilityHandler.requestEligibilityCheck(
                DEFAULT_ACCOUNT,
                testHatId
            )
        returns (ITypes.TriggerId eligibilityTriggerId) {
            console.log(
                "Eligibility check requested with triggerId:",
                uint64(ITypes.TriggerId.unwrap(eligibilityTriggerId))
            );
        } catch Error(string memory reason) {
            console.log("Eligibility check request failed:", reason);
        } catch {
            console.log("Eligibility check request failed with unknown error");
        }

        // 2. Test status check
        console.log("\n2. Testing status check");
        try toggleHandler.requestStatusCheck(testHatId) returns (
            ITypes.TriggerId statusTriggerId
        ) {
            console.log(
                "Status check requested with triggerId:",
                uint64(ITypes.TriggerId.unwrap(statusTriggerId))
            );
        } catch Error(string memory reason) {
            console.log("Status check request failed:", reason);
        } catch {
            console.log("Status check request failed with unknown error");
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nSimplified test script completed.");
    }
}

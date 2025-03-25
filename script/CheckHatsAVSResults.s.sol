// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {Utils} from "./Utils.sol";

/**
 * @title CheckHatsAVSResults
 * @notice Script to check the results of the Hats Protocol WAVS AVS integration
 */
contract CheckHatsAVSResults is Script {
    /**
     * @notice Run the check script with parameters
     * @param _wearer The address of the wearer to check eligibility for
     * @param _eligibilityHatId The hat ID to check eligibility for
     * @param _toggleHatId The hat ID to check status for
     */
    function run(
        address _wearer,
        uint256 _eligibilityHatId,
        uint256 _toggleHatId
    ) public {
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
        console.log("Checking results for wearer:", _wearer);
        console.log("Eligibility Hat ID:", _eligibilityHatId);
        console.log("Toggle Hat ID:", _toggleHatId);

        // Create contract instances
        HatsEligibilityServiceHandler eligibilityHandler = HatsEligibilityServiceHandler(
                eligibilityHandlerAddr
            );
        HatsToggleServiceHandler toggleHandler = HatsToggleServiceHandler(
            toggleHandlerAddr
        );

        // Check eligibility status
        console.log("\nEligibility status:");
        (bool eligible, bool standing, uint256 timestamp) = eligibilityHandler
            .getLatestEligibilityResult(_wearer, _eligibilityHatId);
        console.log("Eligible:", eligible);
        console.log("Standing:", standing);
        console.log("Timestamp:", timestamp);
        console.log("Human timestamp:", _formatTimestamp(timestamp));

        // Check hat status
        console.log("\nHat status:");
        (bool active, uint256 statusTimestamp) = toggleHandler
            .getLatestStatusResult(_toggleHatId);
        console.log("Active:", active);
        console.log("Timestamp:", statusTimestamp);
        console.log("Human timestamp:", _formatTimestamp(statusTimestamp));
    }

    /**
     * @notice Format a timestamp into a readable date
     * @param _timestamp The timestamp to format
     */
    function _formatTimestamp(
        uint256 _timestamp
    ) internal pure returns (string memory) {
        if (_timestamp == 0) {
            return "No result yet";
        }
        return vm.toString(_timestamp);
    }
}

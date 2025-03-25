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
    // Test modes
    uint8 constant MODE_ALL = 0;
    uint8 constant MODE_ELIGIBILITY_ONLY = 1;
    uint8 constant MODE_TOGGLE_ONLY = 2;

    /**
     * @notice Run the check script with default parameters
     */
    function run() external {
        run(MODE_ALL, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 1, 1);
    }

    /**
     * @notice Run the check script with parameters
     * @param _mode The check mode (0=all, 1=eligibility only, 2=toggle only)
     * @param _wearer The address of the wearer to check eligibility for
     * @param _eligibilityHatId The hat ID to check eligibility for
     * @param _toggleHatId The hat ID to check status for
     */
    function run(
        uint8 _mode,
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
        console.log("Check mode:", _getModeName(_mode));
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

        // Check eligibility status if mode is ALL or ELIGIBILITY_ONLY
        if (_mode == MODE_ALL || _mode == MODE_ELIGIBILITY_ONLY) {
            _checkEligibility(eligibilityHandler, _wearer, _eligibilityHatId);
        }

        // Check hat status if mode is ALL or TOGGLE_ONLY
        if (_mode == MODE_ALL || _mode == MODE_TOGGLE_ONLY) {
            _checkToggle(toggleHandler, _toggleHatId);
        }
    }

    /**
     * @notice Get the name of the check mode
     * @param _mode The check mode
     * @return mode The name of the check mode
     */
    function _getModeName(uint8 _mode) internal pure returns (string memory) {
        if (_mode == MODE_ALL) {
            return "ALL";
        } else if (_mode == MODE_ELIGIBILITY_ONLY) {
            return "ELIGIBILITY_ONLY";
        } else if (_mode == MODE_TOGGLE_ONLY) {
            return "TOGGLE_ONLY";
        } else {
            return "UNKNOWN";
        }
    }

    /**
     * @notice Check eligibility status
     * @param _handler The eligibility service handler
     * @param _wearer The address of the wearer
     * @param _hatId The hat ID
     */
    function _checkEligibility(
        HatsEligibilityServiceHandler _handler,
        address _wearer,
        uint256 _hatId
    ) internal {
        console.log("\nEligibility status:");
        (bool eligible, bool standing, uint256 timestamp) = _handler
            .getLatestEligibilityResult(_wearer, _hatId);
        console.log("Eligible:", eligible);
        console.log("Standing:", standing);
        console.log("Timestamp:", timestamp);
        console.log("Human timestamp:", _formatTimestamp(timestamp));

        // Also check via the IHatsEligibility interface
        (bool eligibleViaInterface, bool standingViaInterface) = _handler
            .getWearerStatus(_wearer, _hatId);
        console.log("\nEligibility status via interface:");
        console.log("Eligible:", eligibleViaInterface);
        console.log("Standing:", standingViaInterface);
    }

    /**
     * @notice Check hat toggle status
     * @param _handler The toggle service handler
     * @param _hatId The hat ID
     */
    function _checkToggle(
        HatsToggleServiceHandler _handler,
        uint256 _hatId
    ) internal {
        console.log("\nHat status:");
        (bool active, uint256 statusTimestamp) = _handler.getLatestStatusResult(
            _hatId
        );
        console.log("Active:", active);
        console.log("Timestamp:", statusTimestamp);
        console.log("Human timestamp:", _formatTimestamp(statusTimestamp));

        // Also check via the IHatsToggle interface
        bool activeViaInterface = _handler.getHatStatus(_hatId);
        console.log("\nHat status via interface:");
        console.log("Active:", activeViaInterface);
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

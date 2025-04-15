// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAvsEligibilityModule} from "../src/contracts/HatsAvsEligibilityModule.sol";
import {HatsAvsToggleModule} from "../src/contracts/HatsAvsToggleModule.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title SimplifiedTest
 * @notice Simplified script to test the Hats Protocol WAVS AVS integration
 */
contract SimplifiedTest is Script {
    // Define constants
    address constant DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Test modes
    uint8 constant MODE_ALL = 0;
    uint8 constant MODE_ELIGIBILITY_ONLY = 1;
    uint8 constant MODE_TOGGLE_ONLY = 2;

    /**
     * @notice Run the simplified test script with all tests
     */
    function run() public {
        run(MODE_ALL, DEFAULT_ACCOUNT, 1);
    }

    /**
     * @notice Run the simplified test script with specific parameters
     * @param _mode The test mode (0=all, 1=eligibility only, 2=toggle only)
     * @param _account The account to use for eligibility checks
     * @param _hatId The hat ID to use for tests
     */
    function run(uint8 _mode, address _account, uint256 _hatId) public {
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
        console.log("Test mode:", _getModeName(_mode));
        console.log("Test account:", _account);
        console.log("Test hat ID:", _hatId);

        // Create contract instances
        HatsAvsEligibilityModule eligibilityHandler = HatsAvsEligibilityModule(
            eligibilityHandlerAddr
        );
        HatsAvsToggleModule toggleHandler = HatsAvsToggleModule(
            toggleHandlerAddr
        );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test eligibility if mode is ALL or ELIGIBILITY_ONLY
        if (_mode == MODE_ALL || _mode == MODE_ELIGIBILITY_ONLY) {
            _testEligibility(eligibilityHandler, _account, _hatId);
        }

        // Test toggle if mode is ALL or TOGGLE_ONLY
        if (_mode == MODE_ALL || _mode == MODE_TOGGLE_ONLY) {
            _testToggle(toggleHandler, _hatId);
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nSimplified test script completed.");
        console.log(
            "Note: Wait for WAVS services to process these requests before checking results."
        );
        console.log(
            "Run script/CheckHatsAVSResults.s.sol to check the results after a few seconds."
        );
    }

    /**
     * @notice Get the name of the test mode
     * @param _mode The test mode
     * @return mode The name of the test mode
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
     * @notice Test the eligibility service
     * @param _handler The eligibility service handler
     * @param _account The account to use for eligibility checks
     * @param _hatId The hat ID to use
     */
    function _testEligibility(
        HatsAvsEligibilityModule _handler,
        address _account,
        uint256 _hatId
    ) internal {
        console.log("\n1. Testing eligibility check");
        try _handler.requestEligibilityCheck(_account, _hatId) returns (
            IHatsAvsTypes.TriggerId eligibilityTriggerId
        ) {
            console.log(
                "Eligibility check requested with triggerId:",
                uint64(IHatsAvsTypes.TriggerId.unwrap(eligibilityTriggerId))
            );
        } catch Error(string memory reason) {
            console.log("Eligibility check request failed:", reason);
        } catch {
            console.log("Eligibility check request failed with unknown error");
        }
    }

    /**
     * @notice Test the toggle service
     * @param _handler The toggle service handler
     * @param _hatId The hat ID to use
     */
    function _testToggle(
        HatsAvsToggleModule _handler,
        uint256 _hatId
    ) internal {
        console.log("\n2. Testing status check");
        try _handler.requestStatusCheck(_hatId) returns (
            IHatsAvsTypes.TriggerId statusTriggerId
        ) {
            console.log(
                "Status check requested with triggerId:",
                uint64(IHatsAvsTypes.TriggerId.unwrap(statusTriggerId))
            );
        } catch Error(string memory reason) {
            console.log("Status check request failed:", reason);
        } catch {
            console.log("Status check request failed with unknown error");
        }
    }
}

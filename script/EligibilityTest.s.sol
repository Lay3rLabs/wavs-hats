// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title EligibilityTest
 * @notice Script to test the Hats Protocol WAVS AVS eligibility integration
 */
contract EligibilityTest is Script {
    // Define constants
    address constant DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant DEFAULT_HAT_ID = 1;

    /**
     * @notice Run the eligibility test script with default values
     */
    function run() public {
        run(DEFAULT_ACCOUNT, DEFAULT_HAT_ID);
    }

    /**
     * @notice Run the eligibility test script with specific parameters
     * @param _account The account to use for eligibility checks
     * @param _hatId The hat ID to use for tests
     */
    function run(address _account, uint256 _hatId) public {
        // Get deployment addresses from environment
        address eligibilityHandlerAddr = vm.envAddress(
            "HATS_ELIGIBILITY_SERVICE_HANDLER"
        );

        console.log(
            "Hats Eligibility Service Handler address:",
            eligibilityHandlerAddr
        );
        console.log("Test account:", _account);
        console.log("Test hat ID:", _hatId);

        // Create contract instance
        HatsEligibilityServiceHandler eligibilityHandler = HatsEligibilityServiceHandler(
                eligibilityHandlerAddr
            );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test eligibility
        _testEligibility(eligibilityHandler, _account, _hatId);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nEligibility test script completed.");
        console.log(
            "Note: Wait for WAVS services to process this request before checking results."
        );
        console.log(
            string.concat(
                'Run script/CheckHatsAVSResults.s.sol --sig "run(uint8,address,uint256,uint256)" 1 ',
                vm.toString(_account),
                " ",
                vm.toString(_hatId),
                " 0 to check the results after a few seconds."
            )
        );
    }

    /**
     * @notice Test the eligibility service
     * @param _handler The eligibility service handler
     * @param _account The account to use for eligibility checks
     * @param _hatId The hat ID to use
     */
    function _testEligibility(
        HatsEligibilityServiceHandler _handler,
        address _account,
        uint256 _hatId
    ) internal {
        console.log("\nTesting eligibility check");
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title TestEligibilityService
 * @notice Script to test the Hats Eligibility Service functionality in particular
 */
contract TestEligibilityService is Script {
    /**
     * @notice Run the eligibility service test
     */
    function run() public {
        // Get deployment addresses from environment
        address eligibilityHandlerAddr = vm.envAddress(
            "HATS_ELIGIBILITY_SERVICE_HANDLER"
        );

        console.log(
            "Hats Eligibility Service Handler address:",
            eligibilityHandlerAddr
        );

        // Create contract instances
        HatsEligibilityServiceHandler eligibilityHandler = HatsEligibilityServiceHandler(
                eligibilityHandlerAddr
            );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test with multiple wearers to show the eligibility behavior
        address[] memory wearers = new address[](4);
        wearers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default account
        wearers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Another account
        wearers[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Another account
        wearers[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Another account

        // Use a consistent hat ID for all tests
        uint256 hatId = 1;

        // Request eligibility checks directly from the eligibilityHandler
        console.log(
            "\nRequesting eligibility checks for multiple wearers (directly from handler):"
        );
        for (uint i = 0; i < wearers.length; i++) {
            address wearer = wearers[i];
            try
                eligibilityHandler.requestEligibilityCheck(wearer, hatId)
            returns (ITypes.TriggerId triggerId) {
                console.log(
                    string.concat(
                        "Wearer ",
                        vm.toString(wearer),
                        " eligibility check requested with triggerId: ",
                        vm.toString(uint64(ITypes.TriggerId.unwrap(triggerId)))
                    )
                );
            } catch Error(string memory reason) {
                console.log(
                    string.concat(
                        "Wearer ",
                        vm.toString(wearer),
                        " eligibility check request failed: ",
                        reason
                    )
                );
            } catch {
                console.log(
                    string.concat(
                        "Wearer ",
                        vm.toString(wearer),
                        " eligibility check request failed with unknown error"
                    )
                );
            }
        }

        // Get current eligibility for each wearer directly from the handler
        console.log(
            "\nCurrent eligibility statuses from handler (may take time to update):"
        );
        for (uint i = 0; i < wearers.length; i++) {
            address wearer = wearers[i];
            (
                bool eligible,
                bool standing,
                uint256 timestamp
            ) = eligibilityHandler.getLatestEligibilityResult(wearer, hatId);
            console.log(
                string.concat(
                    "Wearer ",
                    vm.toString(wearer),
                    " - Eligible: ",
                    eligible ? "true" : "false",
                    " - Standing: ",
                    standing ? "true" : "false",
                    " - Timestamp: ",
                    timestamp > 0
                        ? string.concat(
                            vm.toString(timestamp),
                            " (",
                            vm.toString(block.timestamp - timestamp),
                            " seconds ago)"
                        )
                        : "No result yet"
                )
            );
        }

        // Also get eligibility status from IHatsEligibility interface
        console.log("\nEligibility statuses from IHatsEligibility interface:");
        for (uint i = 0; i < wearers.length; i++) {
            address wearer = wearers[i];
            (bool eligible, bool standing) = eligibilityHandler.getWearerStatus(
                wearer,
                hatId
            );
            console.log(
                string.concat(
                    "Wearer ",
                    vm.toString(wearer),
                    " - Eligible: ",
                    eligible ? "true" : "false",
                    " - Standing: ",
                    standing ? "true" : "false"
                )
            );
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nEligibility service test completed.");
        console.log(
            "Transaction completed. AVS results should now be processed."
        );
        console.log(
            "According to the implementation, accounts should be eligibile."
        );
    }
}

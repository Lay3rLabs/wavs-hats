// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title TestToggleService
 * @notice Script to test the Hats Toggle Service functionality in particular
 */
contract TestToggleService is Script {
    /**
     * @notice Run the toggle service test
     */
    function run() public {
        // Get deployment addresses from environment
        address toggleHandlerAddr = vm.envAddress(
            "HATS_TOGGLE_SERVICE_HANDLER"
        );

        console.log("Hats Toggle Service Handler address:", toggleHandlerAddr);

        // Create contract instances
        HatsToggleServiceHandler toggleHandler = HatsToggleServiceHandler(
            toggleHandlerAddr
        );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test with multiple hat IDs to show the toggle behavior
        uint256[] memory hatIds = new uint256[](4);
        hatIds[0] = 1; // odd ID
        hatIds[1] = 2; // even ID
        hatIds[2] = 3; // odd ID
        hatIds[3] = 4; // even ID

        // Request status checks directly from the toggleHandler
        console.log(
            "\nRequesting status checks for multiple hat IDs (directly from handler):"
        );
        for (uint i = 0; i < hatIds.length; i++) {
            uint256 hatId = hatIds[i];
            try toggleHandler.requestStatusCheck(hatId) returns (
                ITypes.TriggerId triggerId
            ) {
                console.log(
                    string.concat(
                        "Hat ID ",
                        vm.toString(hatId),
                        " status check requested with triggerId: ",
                        vm.toString(uint64(ITypes.TriggerId.unwrap(triggerId)))
                    )
                );
            } catch Error(string memory reason) {
                console.log(
                    string.concat(
                        "Hat ID ",
                        vm.toString(hatId),
                        " status check request failed: ",
                        reason
                    )
                );
            } catch {
                console.log(
                    string.concat(
                        "Hat ID ",
                        vm.toString(hatId),
                        " status check request failed with unknown error"
                    )
                );
            }
        }

        // Get current status for each hat ID directly from the handler
        console.log(
            "\nCurrent hat statuses from handler (may take time to update):"
        );
        for (uint i = 0; i < hatIds.length; i++) {
            uint256 hatId = hatIds[i];
            (bool active, uint256 timestamp) = toggleHandler
                .getLatestStatusResult(hatId);
            console.log(
                string.concat(
                    "Hat ID ",
                    vm.toString(hatId),
                    " - Active: ",
                    active ? "true" : "false",
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

        // Also get hat status from IHatsToggle interface
        console.log("\nHat statuses from IHatsToggle interface:");
        for (uint i = 0; i < hatIds.length; i++) {
            uint256 hatId = hatIds[i];
            bool active = toggleHandler.getHatStatus(hatId);
            console.log(
                string.concat(
                    "Hat ID ",
                    vm.toString(hatId),
                    " - Active: ",
                    active ? "true" : "false"
                )
            );
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nToggle service test completed.");
        console.log(
            "Transaction completed. AVS results should now be processed."
        );
        console.log(
            "According to the implementation, even-numbered hats should be active, and odd-numbered hats should be active only on even days."
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAvsToggleModule} from "../src/contracts/HatsAvsToggleModule.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title ToggleTest
 * @notice Script to test the Hats Protocol WAVS AVS toggle integration
 */
contract ToggleTest is Script {
    // Define constants
    uint256 constant DEFAULT_HAT_ID = 1;

    /**
     * @notice Run the toggle test script with default values
     */
    function run() public {
        run(DEFAULT_HAT_ID);
    }

    /**
     * @notice Run the toggle test script with specific parameters
     * @param _hatId The hat ID to use for tests
     */
    function run(uint256 _hatId) public {
        // Get deployment addresses from environment
        address toggleHandlerAddr = vm.envAddress(
            "HATS_TOGGLE_SERVICE_HANDLER"
        );

        console.log("Hats Toggle Service Handler address:", toggleHandlerAddr);
        console.log("Test hat ID:", _hatId);

        // Create contract instance
        HatsAvsToggleModule toggleHandler = HatsAvsToggleModule(
            toggleHandlerAddr
        );

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test toggle
        _testToggle(toggleHandler, _hatId);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nToggle test script completed.");
        console.log(
            "Note: Wait for WAVS services to process this request before checking results."
        );
        console.log(
            string.concat(
                'Run script/CheckHatsAVSResults.s.sol --sig "run(uint8,address,uint256,uint256)" 2 0x0000000000000000000000000000000000000000 0 ',
                vm.toString(_hatId),
                " to check the results after a few seconds."
            )
        );
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
        console.log("\nTesting status check");
        try _handler.requestStatusCheck(_hatId) returns (
            uint64 statusTriggerId
        ) {
            console.log(
                "Status check requested with triggerId:",
                uint64(statusTriggerId)
            );
        } catch Error(string memory reason) {
            console.log("Status check request failed:", reason);
        } catch {
            console.log("Status check request failed with unknown error");
        }
    }
}

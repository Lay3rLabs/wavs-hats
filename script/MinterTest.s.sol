// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAVSMinter} from "../src/contracts/HatsAVSMinter.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title MinterTest
 * @notice Script to test the HatsAVSMinter contract
 */
contract MinterTest is Script {
    // Define constants
    address constant DEFAULT_WEARER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant DEFAULT_HAT_ID = 1;

    /**
     * @notice Run the minter test script with default values
     */
    function run() public {
        run(DEFAULT_WEARER, DEFAULT_HAT_ID);
    }

    /**
     * @notice Run the minter test script with specific parameters
     * @param _wearer The address that will wear the hat
     * @param _hatId The hat ID to mint
     */
    function run(address _wearer, uint256 _hatId) public {
        // Get deployment address from environment
        address minterAddr = vm.envAddress("HATS_AVS_MINTER");

        console.log("Hats AVS Minter address:", minterAddr);
        console.log("Test wearer:", _wearer);
        console.log("Test hat ID:", _hatId);

        // Create contract instance
        HatsAVSMinter minter = HatsAVSMinter(minterAddr);

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // Test hat minting
        try minter.requestHatMinting(_hatId, _wearer) returns (
            ITypes.TriggerId mintingTriggerId
        ) {
            console.log(
                "Hat minting requested with triggerId:",
                uint64(ITypes.TriggerId.unwrap(mintingTriggerId))
            );
        } catch Error(string memory reason) {
            console.log("Hat minting request failed:", reason);
        } catch {
            console.log("Hat minting request failed with unknown error");
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log("\nMinter test script completed.");
        console.log(
            "Note: Wait for WAVS services to process this request before checking results."
        );
        console.log(
            "Run script/CheckMinterResults.s.sol to check the results after a few seconds."
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAVSMinter} from "../src/contracts/HatsAVSMinter.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {Utils} from "./Utils.sol";

/**
 * @title CheckMinterResults
 * @notice Script to check the results of HatsAVSMinter operations
 */
contract CheckMinterResults is Script {
    // Define constants
    address constant DEFAULT_WEARER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Use the same hat ID format as in MinterTest
    uint256 constant TOP_HAT_DOMAIN = 1;
    uint256 constant DEFAULT_HAT_ID = TOP_HAT_DOMAIN << 224;

    /**
     * @notice Run the check results script with default values
     */
    function run() public {
        run(DEFAULT_WEARER, DEFAULT_HAT_ID);
    }

    /**
     * @notice Run the check results script with specific parameters
     * @param _wearer The wearer address to check
     * @param _hatId The hat ID to check
     */
    function run(address _wearer, uint256 _hatId) public view {
        // Get deployment addresses from environment
        address minterAddr = vm.envAddress("HATS_AVS_MINTER");
        address hatsAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");

        console.log("Checking hat minting results:");
        console.log("Hats AVS Minter address:", minterAddr);
        console.log("Hats Protocol address:", hatsAddr);
        console.log("Wearer address:", _wearer);
        console.log("Hat ID (formatted):", _hatId);

        // Create contract instances
        IHats hats = IHats(hatsAddr);

        // Check if the wearer is wearing the hat
        bool isWearing = hats.isWearerOfHat(_wearer, _hatId);

        console.log("\nResults:");
        console.log("Is address wearing the hat?", isWearing ? "YES" : "NO");

        if (isWearing) {
            console.log("Hat was successfully minted to the wearer!");
        } else {
            console.log("Hat was not minted to the wearer yet.");
            console.log(
                "- This may be because WAVS operators haven't processed the request yet"
            );
            console.log("- Or the address might not be eligible for the hat");
            console.log(
                "- Wait a few seconds and try running this check again"
            );
        }
    }
}

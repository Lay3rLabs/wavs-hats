// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAvsMinter} from "../src/contracts/HatsAvsMinter.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {Utils} from "./Utils.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";

/**
 * @title Mint
 * @notice Script to test the HatsAvsMinter contract
 */
contract Mint is Script {
    // Define constants
    address constant DEFAULT_WEARER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Don't use 1 as the hatId, use a properly formatted top hat ID
    // Top hat IDs in Hats Protocol are formatted as `uint256(topHatDomain) << 224`
    // Let's use domain 1 to create a proper top hat ID
    uint256 constant TOP_HAT_DOMAIN = 1;
    uint256 constant DEFAULT_HAT_ID = TOP_HAT_DOMAIN << 224; // Convert to proper hat ID format

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
        address hatsAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");

        console.log("Hats AVS Minter address:", minterAddr);
        console.log("Hats Protocol address:", hatsAddr);
        console.log("Test wearer:", _wearer);
        console.log("Test hat ID (formatted):", _hatId);

        // Create contract instances
        HatsAvsMinter minter = HatsAvsMinter(minterAddr);
        IHats hats = IHats(hatsAddr);

        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // First, check if the hat exists - if not, let's create a top hat
        try hats.mintTopHat(deployer, "Test Top Hat", "") returns (
            uint256 newHatId
        ) {
            console.log("Created new top hat with ID:", newHatId);
            // Use the newly created hat ID
            _hatId = newHatId;
        } catch {
            console.log(
                "Hat ID likely already exists, continuing with:",
                _hatId
            );
        }

        // Test hat minting
        try minter.requestHatMinting(_hatId, _wearer) returns (
            uint64 mintingTriggerId
        ) {
            console.log(
                "Hat minting requested with triggerId:",
                uint64(mintingTriggerId)
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

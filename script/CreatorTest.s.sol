// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAVSHatter} from "../src/contracts/HatsAVSHatter.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {Utils} from "./Utils.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";

/**
 * @title CreatorTest
 * @notice Simplified script to test the HatsAVSHatter contract
 */
contract CreatorTest is Script {
    // Define constants
    string constant DEFAULT_DETAILS = "Child Hat created via WAVS AVS";
    uint32 constant DEFAULT_MAX_SUPPLY = 100;
    bool constant DEFAULT_MUTABLE = true;
    string constant DEFAULT_IMAGE_URI = "ipfs://QmHash";

    function run() public {
        // Get the necessary addresses
        address eligibilityHandler = vm.envAddress(
            "HATS_ELIGIBILITY_SERVICE_HANDLER"
        );
        address toggleHandler = vm.envAddress("HATS_TOGGLE_SERVICE_HANDLER");
        address hatterAddr = vm.envAddress("HATS_AVS_HATTER");
        address hatsAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");

        // Get deployer address and start broadcast
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);
        vm.startBroadcast(privateKey);

        // Get contract instances
        IHats hats = IHats(hatsAddr);
        HatsAVSHatter hatter = HatsAVSHatter(hatterAddr);

        // Create a new top hat
        console.log("Creating a new top hat...");
        uint256 topHatId = hats.mintTopHat(
            deployer,
            "Test Top Hat",
            "ipfs://QmTopHat"
        );
        console.log("Created top hat with ID:", topHatId);

        // DEBUG: Check if deployer has the top hat
        bool deployerHasTopHat = hats.isWearerOfHat(deployer, topHatId);
        console.log("Deployer is wearing top hat?", deployerHasTopHat);

        // DEBUG: Check if HatsAVSHatter is authorized as an admin
        bool hatterIsAdmin;
        try hats.isAdminOfHat(hatterAddr, topHatId) returns (bool result) {
            hatterIsAdmin = result;
        } catch {
            hatterIsAdmin = false;
        }
        console.log("HatsAVSHatter is admin of top hat?", hatterIsAdmin);

        // Give admin rights to hatter if needed
        if (!hatterIsAdmin) {
            console.log("Attempting to transfer top hat to HatsAVSHatter...");
            try hats.transferHat(topHatId, deployer, hatterAddr) {
                console.log(
                    "Successfully transferred top hat to HatsAVSHatter"
                );
            } catch Error(string memory reason) {
                console.log("Transfer failed:", reason);
            } catch {
                console.log("Transfer failed with unknown error");
            }
        }

        // Now try to request hat creation
        console.log("Requesting child hat creation for top hat ID:", topHatId);
        try
            hatter.requestHatCreation(
                topHatId,
                DEFAULT_DETAILS,
                DEFAULT_MAX_SUPPLY,
                eligibilityHandler,
                toggleHandler,
                DEFAULT_MUTABLE,
                DEFAULT_IMAGE_URI
            )
        returns (IHatsAvsTypes.TriggerId triggerId) {
            console.log(
                "Hat creation requested with triggerId:",
                uint64(IHatsAvsTypes.TriggerId.unwrap(triggerId))
            );
        } catch Error(string memory reason) {
            console.log("requestHatCreation failed:", reason);
        } catch {
            console.log("requestHatCreation failed with unknown error");
        }

        vm.stopBroadcast();

        // Print final message
        console.log("\nTest completed.");
    }
}

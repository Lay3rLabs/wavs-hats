// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAVSHatter} from "../src/contracts/HatsAVSHatter.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {Utils} from "./Utils.sol";

/**
 * @title CheckCreatorResults
 * @notice Script to check the results of HatsAVSHatter operations
 */
contract CheckCreatorResults is Script {
    // Define constants
    // Use the same hat ID format as in CreatorTest
    uint256 constant TOP_HAT_DOMAIN = 1;
    uint256 constant DEFAULT_ADMIN_HAT_ID = TOP_HAT_DOMAIN << 224;

    // Store the hats contract as a state variable
    IHats private hats;

    /**
     * @notice Run the check results script with default values
     */
    function run() public {
        // Get the deployer address to check hats for
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        // First try checking the latest hat we tried to create
        // If that's not provided, check all hats for the deployer
        address hatWearer = deployer;
        run(DEFAULT_ADMIN_HAT_ID, hatWearer);
    }

    /**
     * @notice Run the check results script with specific parameters
     * @param _adminHatId The admin hat ID to check for child hats
     * @param _wearer The address to check for hats
     */
    function run(uint256 _adminHatId, address _wearer) public {
        // Get deployment addresses from environment
        address hatterAddr = vm.envAddress("HATS_AVS_HATTER");
        address hatsAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");

        console.log("Checking hat creation results:");
        console.log("Hats AVS Hatter address:", hatterAddr);
        console.log("Hats Protocol address:", hatsAddr);
        console.log("Admin Hat ID:", _adminHatId);
        console.log("Checking hats for wearer:", _wearer);

        // Create contract instance
        hats = IHats(hatsAddr);

        // Check if the wearer is valid
        if (_wearer == address(0)) {
            console.log("Invalid wearer address");
            return;
        }

        // If a specific admin hat ID was provided, check it directly
        if (_adminHatId != 0) {
            console.log("\nChecking specific admin hat:", _adminHatId);
            checkAdminHat(_adminHatId);
            return;
        }

        // Otherwise, find top hats for the address
        console.log("\nFinding top hats worn by this wearer...");
        uint256[] memory topHats = findTophatsForAddress(_wearer);

        if (topHats.length == 0) {
            console.log("No top hats found for this wearer");
            return;
        }

        // Check each top hat and its children
        for (uint256 i = 0; i < topHats.length; i++) {
            uint256 topHatId = topHats[i];
            console.log("\nExamining Top Hat #", i + 1, "ID:", topHatId);
            checkAdminHat(topHatId);
        }
    }

    /**
     * @notice Find all top hats worn by an address
     * @param _wearer The address to check
     * @return Array of top hat IDs worn by the address
     */
    function findTophatsForAddress(
        address _wearer
    ) private view returns (uint256[] memory) {
        // This is just a mock implementation since we can't easily query all hats
        // Instead, we'll check if the wearer wears any of the first few top hats
        uint256[] memory potentialTopHats = new uint256[](10);
        uint256 count = 0;

        // Check the first 10 potential top hat domains
        for (uint256 domain = 1; domain <= 10; domain++) {
            uint256 topHatId = domain << 224;
            if (hats.isWearerOfHat(_wearer, topHatId)) {
                potentialTopHats[count] = topHatId;
                count++;
            }
        }

        // Resize the array to the actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = potentialTopHats[i];
        }

        return result;
    }

    /**
     * @notice Check the admin hat and its children
     * @param _adminHatId The admin hat ID to check
     */
    function checkAdminHat(uint256 _adminHatId) private {
        // Get the details for this admin hat
        (
            string memory details,
            uint32 maxSupply,
            uint32 supply,
            address eligibility,
            address toggle,
            string memory imageURI,
            uint16 lastHatId,
            bool mutable_,
            bool active
        ) = hats.viewHat(_adminHatId);

        console.log("\nAdmin Hat Details:");
        console.log("Details:", details);
        console.log("Image URI:", imageURI);
        console.log("Max Supply:", maxSupply);
        console.log("Current Supply:", supply);
        console.log("Last Child Hat ID:", lastHatId);
        console.log("Mutable:", mutable_);
        console.log("Active:", active);
        console.log("Eligibility:", eligibility);
        console.log("Toggle:", toggle);

        // Check if there are any children by looking at lastHatId
        if (lastHatId > 0) {
            console.log("\nChild Hats Found:");

            // Iterate through each child hat
            for (uint16 i = 1; i <= lastHatId; i++) {
                checkChildHat(_adminHatId, i);
            }

            console.log("\nHat creation was successful!");
        } else {
            console.log("\nNo child hats found for this admin hat.");
            console.log(
                "- This may be because WAVS operators haven't processed the request yet"
            );
            console.log(
                "- Wait a few seconds and try running this check again"
            );
        }
    }

    /**
     * @notice Check a specific child hat
     * @param _adminHatId The admin hat ID
     * @param _childIndex The child index
     */
    function checkChildHat(uint256 _adminHatId, uint16 _childIndex) private {
        // Build the child hat ID
        uint256 childId = hats.buildHatId(_adminHatId, _childIndex);

        // Get the child hat details
        (
            string memory childDetails,
            uint32 childMaxSupply,
            uint32 childSupply,
            address childEligibility,
            address childToggle,
            string memory childImageURI, // lastChildHatId (unused)
            ,
            bool childMutable,
            bool childActive
        ) = hats.viewHat(childId);

        console.log("\nChild Hat ID:", childId);
        console.log("Details:", childDetails);
        console.log("Image URI:", childImageURI);
        console.log("Max Supply:", childMaxSupply);
        console.log("Current Supply:", childSupply);
        console.log("Eligibility Module:", childEligibility);
        console.log("Toggle Module:", childToggle);
        console.log("Mutable:", childMutable);
        console.log("Active:", childActive);

        // Check if any addresses are wearing this hat
        if (childSupply > 0) {
            console.log("Hat is being worn by at least one address");
        } else {
            console.log("Hat is not being worn by any address");
        }
    }
}

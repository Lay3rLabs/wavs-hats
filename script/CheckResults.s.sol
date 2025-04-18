// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HatsAvsEligibilityModule} from "../src/contracts/HatsAvsEligibilityModule.sol";
import {HatsAvsToggleModule} from "../src/contracts/HatsAvsToggleModule.sol";
import {HatsAvsMinter} from "../src/contracts/HatsAvsMinter.sol";
import {HatsAvsHatter} from "../src/contracts/HatsAvsHatter.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {Utils} from "./Utils.sol";

/**
 * @title CheckResults
 * @notice Script to check results of Hats Protocol WAVS AVS operations
 */
contract CheckResults is Script {
    // Test modes
    uint8 constant MODE_ALL = 0;
    uint8 constant MODE_ELIGIBILITY_ONLY = 1;
    uint8 constant MODE_TOGGLE_ONLY = 2;
    uint8 constant MODE_MINTER = 3;
    uint8 constant MODE_CREATOR = 4;

    // Default constants
    address constant DEFAULT_WEARER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant TOP_HAT_DOMAIN = 1;
    uint256 constant DEFAULT_HAT_ID = TOP_HAT_DOMAIN << 224;
    uint256 constant DEFAULT_ADMIN_HAT_ID = TOP_HAT_DOMAIN << 224;

    // Store the hats contract as a state variable
    IHats private hats;

    /**
     * @notice Run the check script with default parameters
     */
    function run() external {
        run(MODE_ALL, DEFAULT_WEARER, DEFAULT_HAT_ID, DEFAULT_HAT_ID);
    }

    /**
     * @notice Run the check script with parameters
     * @param _mode The check mode (0=all, 1=eligibility only, 2=toggle only, 3=minter, 4=creator)
     * @param _wearer The address of the wearer to check
     * @param _eligibilityHatId The hat ID to check eligibility for
     * @param _toggleHatId The hat ID to check status for
     */
    function run(
        uint8 _mode,
        address _wearer,
        uint256 _eligibilityHatId,
        uint256 _toggleHatId
    ) public {
        // Get deployment addresses from environment
        address eligibilityHandlerAddr = vm.envAddress(
            "HATS_AVS_ELIGIBILITY_MODULE"
        );
        address toggleHandlerAddr = vm.envAddress("HATS_AVS_TOGGLE_MODULE");
        address minterAddr = vm.envAddress("HATS_AVS_MINTER");
        address hatterAddr = vm.envAddress("HATS_AVS_HATTER");
        address hatsAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");

        console.log("\n=== Hats Protocol WAVS AVS Results Checker ===");
        console.log("Mode:", _getModeName(_mode));
        console.log("Wearer address:", _wearer);
        console.log("Eligibility Hat ID:", _eligibilityHatId);
        console.log("Toggle Hat ID:", _toggleHatId);

        // Create contract instances
        HatsAvsEligibilityModule eligibilityHandler = HatsAvsEligibilityModule(
            eligibilityHandlerAddr
        );
        HatsAvsToggleModule toggleHandler = HatsAvsToggleModule(
            toggleHandlerAddr
        );
        hats = IHats(hatsAddr);

        // Run the appropriate check based on mode
        if (_mode == MODE_ALL || _mode == MODE_ELIGIBILITY_ONLY) {
            _checkEligibility(eligibilityHandler, _wearer, _eligibilityHatId);
        }

        if (_mode == MODE_ALL || _mode == MODE_TOGGLE_ONLY) {
            _checkToggle(toggleHandler, _toggleHatId);
        }

        if (_mode == MODE_ALL || _mode == MODE_MINTER) {
            _checkMinter(_wearer, _eligibilityHatId);
        }

        if (_mode == MODE_ALL || _mode == MODE_CREATOR) {
            _checkCreator(DEFAULT_ADMIN_HAT_ID, _wearer);
        }
    }

    /**
     * @notice Run the check for minter results with specific parameters
     * @param _wearer The wearer address to check
     * @param _hatId The hat ID to check
     */
    function runMinter(address _wearer, uint256 _hatId) public {
        run(MODE_MINTER, _wearer, _hatId, 0);
    }

    /**
     * @notice Run the check for creator results with specific parameters
     * @param _adminHatId The admin hat ID to check for child hats
     * @param _wearer The address to check for hats
     */
    function runCreator(uint256 _adminHatId, address _wearer) public {
        run(MODE_CREATOR, _wearer, 0, 0);
        _checkCreator(_adminHatId, _wearer);
    }

    /**
     * @notice Get the name of the check mode
     * @param _mode The check mode
     * @return mode The name of the check mode
     */
    function _getModeName(uint8 _mode) internal pure returns (string memory) {
        if (_mode == MODE_ALL) {
            return "ALL";
        } else if (_mode == MODE_ELIGIBILITY_ONLY) {
            return "ELIGIBILITY_ONLY";
        } else if (_mode == MODE_TOGGLE_ONLY) {
            return "TOGGLE_ONLY";
        } else if (_mode == MODE_MINTER) {
            return "MINTER";
        } else if (_mode == MODE_CREATOR) {
            return "CREATOR";
        } else {
            return "UNKNOWN";
        }
    }

    /**
     * @notice Check eligibility status
     * @param _handler The eligibility service handler
     * @param _wearer The address of the wearer
     * @param _hatId The hat ID
     */
    function _checkEligibility(
        HatsAvsEligibilityModule _handler,
        address _wearer,
        uint256 _hatId
    ) internal {
        console.log("\n=== Eligibility Status ===");

        (bool eligible, bool standing) = _handler.getWearerStatus(
            _wearer,
            _hatId
        );
        console.log("Eligible:", eligible);
        console.log("Standing:", standing);
    }

    /**
     * @notice Check hat toggle status
     * @param _handler The toggle service handler
     * @param _hatId The hat ID
     */
    function _checkToggle(
        HatsAvsToggleModule _handler,
        uint256 _hatId
    ) internal {
        console.log("\n=== Hat Status ===");

        bool active = _handler.getHatStatus(_hatId);
        console.log("Active:", active);
    }

    /**
     * @notice Check hat minting results
     * @param _wearer The wearer address
     * @param _hatId The hat ID
     */
    function _checkMinter(address _wearer, uint256 _hatId) internal view {
        console.log("\n=== Hat Minting Results ===");

        // Check if the wearer is wearing the hat
        bool isWearing = hats.isWearerOfHat(_wearer, _hatId);

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

    /**
     * @notice Check hat creation results
     * @param _adminHatId The admin hat ID to check
     * @param _wearer The wearer address to check
     */
    function _checkCreator(uint256 _adminHatId, address _wearer) internal {
        console.log("\n=== Hat Creation Results ===");
        console.log("Admin Hat ID:", _adminHatId);
        console.log("Checking hats for wearer:", _wearer);

        // If a specific admin hat ID was provided, check it directly
        if (_adminHatId != 0) {
            console.log("\nChecking specific admin hat:", _adminHatId);
            _checkAdminHat(_adminHatId);
            return;
        }

        // Otherwise, find top hats for the address
        console.log("\nFinding top hats worn by this wearer...");
        uint256[] memory topHats = _findTophatsForAddress(_wearer);

        if (topHats.length == 0) {
            console.log("No top hats found for this wearer");
            return;
        }

        // Check each top hat and its children
        for (uint256 i = 0; i < topHats.length; i++) {
            uint256 topHatId = topHats[i];
            console.log("\nExamining Top Hat #", i + 1, "ID:", topHatId);
            _checkAdminHat(topHatId);
        }
    }

    /**
     * @notice Find all top hats worn by an address
     * @param _wearer The address to check
     * @return Array of top hat IDs worn by the address
     */
    function _findTophatsForAddress(
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
    function _checkAdminHat(uint256 _adminHatId) private {
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
                _checkChildHat(_adminHatId, i);
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
    function _checkChildHat(uint256 _adminHatId, uint16 _childIndex) private {
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {HatsModuleFactory} from "@hats-module/src/HatsModuleFactory.sol";
// Import Hats Protocol and Hats Module Factory for deployment
import {Hats} from "hats-protocol/Hats.sol";
import {Utils} from "./Utils.sol";

import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {HatsAVSHatter} from "../src/contracts/HatsAVSHatter.sol";
import {IHatsEligibilityServiceHandler} from "../src/interfaces/IHatsEligibilityServiceHandler.sol";
import {IHatsToggleServiceHandler} from "../src/interfaces/IHatsToggleServiceHandler.sol";

/**
 * @title DeployHatsAVS
 * @notice Deployment script for the Hats Protocol WAVS AVS integration
 */
contract DeployHatsAVS is Script {
    // Default values for constructor parameters
    uint256 public constant DEFAULT_ELIGIBILITY_CHECK_COOLDOWN = 1 hours;
    uint256 public constant DEFAULT_STATUS_CHECK_COOLDOWN = 4 hours;
    string public constant VERSION = "0.1.0";

    /**
     * @notice Run the deployment script
     */
    function run() public {
        // Get deployment parameters from environment
        address serviceManagerAddr = vm.envOr(
            "SERVICE_MANAGER_ADDRESS",
            Utils.getServiceManager(vm)
        );

        // Get or deploy Hats Protocol
        address hatsAddr = getOrDeployHatsProtocol();

        // Get or deploy Hats Module Factory
        address moduleFactoryAddr = getOrDeployHatsModuleFactory(hatsAddr);

        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        console.log("Deployer address:", deployer);
        console.log("Service Manager address:", serviceManagerAddr);
        console.log("Hats Protocol address:", hatsAddr);
        console.log("Hats Module Factory address:", moduleFactoryAddr);

        // Create instances of the external contracts
        // Keeping the service manager reference for future use (suppress unused warning)
        IWavsServiceManager serviceManager;
        serviceManager = IWavsServiceManager(serviceManagerAddr);
        IHats hats = IHats(hatsAddr);
        HatsModuleFactory moduleFactory = HatsModuleFactory(moduleFactoryAddr);

        // Start broadcasting transactions with the private key
        vm.startBroadcast(privateKey);

        // Deploy the module implementations
        HatsEligibilityServiceHandler eligibilityImpl = new HatsEligibilityServiceHandler(
                hats,
                serviceManagerAddr,
                VERSION,
                DEFAULT_ELIGIBILITY_CHECK_COOLDOWN
            );
        console.log(
            "HatsEligibilityServiceHandler implementation deployed at: %s",
            address(eligibilityImpl)
        );

        HatsToggleServiceHandler toggleImpl = new HatsToggleServiceHandler(
            hats,
            serviceManagerAddr,
            VERSION,
            DEFAULT_STATUS_CHECK_COOLDOWN
        );
        console.log(
            "HatsToggleServiceHandler implementation deployed at: %s",
            address(toggleImpl)
        );

        HatsAVSHatter hatterImpl = new HatsAVSHatter(
            hats,
            serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAVSHatter implementation deployed at: %s",
            address(hatterImpl)
        );

        // Create module instances via factory
        address eligibilityHandler = moduleFactory.createHatsModule(
            address(eligibilityImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // saltNonce
        );
        console.log(
            "HatsEligibilityServiceHandler instance deployed at: %s",
            eligibilityHandler
        );

        address toggleHandler = moduleFactory.createHatsModule(
            address(toggleImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // saltNonce
        );
        console.log(
            "HatsToggleServiceHandler instance deployed at: %s",
            toggleHandler
        );

        address hatter = moduleFactory.createHatsModule(
            address(hatterImpl), // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // saltNonce
        );
        console.log("HatsAVSHatter instance deployed at: %s", hatter);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Update or add addresses to .env file
        updateEnvVars(
            hatsAddr,
            moduleFactoryAddr,
            address(eligibilityImpl),
            address(toggleImpl),
            address(hatterImpl),
            eligibilityHandler,
            toggleHandler,
            hatter
        );

        // Log deployment completion
        console.log("Hats Protocol WAVS AVS integration deployed successfully");
    }

    /**
     * @notice Get or deploy the Hats Protocol contract
     * @return hatsAddr The address of the Hats Protocol contract
     */
    function getOrDeployHatsProtocol() internal returns (address hatsAddr) {
        // Try to get the Hats Protocol address from env
        hatsAddr = vm.envOr("HATS_PROTOCOL_ADDRESS", address(0));

        // If not set, deploy a new instance
        if (hatsAddr == address(0)) {
            console.log(
                "Hats Protocol address not set, deploying new instance..."
            );

            (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);
            vm.startBroadcast(privateKey);

            // Deploy Hats Protocol
            // Check constructor parameters based on the latest version
            Hats hatsProtocol = new Hats(
                "Hats Protocol Local", // name
                "https://app.hatsprotocol.xyz/trees/" // baseImageURI
            );

            hatsAddr = address(hatsProtocol);
            vm.stopBroadcast();

            console.log("Deployed new Hats Protocol at:", hatsAddr);
        } else {
            console.log("Using existing Hats Protocol at:", hatsAddr);
        }
    }

    /**
     * @notice Get or deploy the Hats Module Factory contract
     * @param _hatsAddr The address of the Hats Protocol contract
     * @return factoryAddr The address of the Hats Module Factory contract
     */
    function getOrDeployHatsModuleFactory(
        address _hatsAddr
    ) internal returns (address factoryAddr) {
        // Try to get the Hats Module Factory address from env
        factoryAddr = vm.envOr("HATS_MODULE_FACTORY_ADDRESS", address(0));

        // If not set, deploy a new instance
        if (factoryAddr == address(0)) {
            console.log(
                "Hats Module Factory address not set, deploying new instance..."
            );

            (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);
            vm.startBroadcast(privateKey);

            // Deploy Hats Module Factory
            HatsModuleFactory factory = new HatsModuleFactory(
                IHats(_hatsAddr),
                "1.0.0" // version
            );

            factoryAddr = address(factory);
            vm.stopBroadcast();

            console.log("Deployed new Hats Module Factory at:", factoryAddr);
        } else {
            console.log("Using existing Hats Module Factory at:", factoryAddr);
        }
    }

    /**
     * @notice Update or add Hats AVS addresses to the .env file
     * @param hatsAddr Hats Protocol address
     * @param moduleFactoryAddr Hats Module Factory address
     * @param eligibilityImplAddr Eligibility Service Handler Implementation address
     * @param toggleImplAddr Toggle Service Handler Implementation address
     * @param hatterImplAddr AVS Hatter Implementation address
     * @param eligibilityHandlerAddr Eligibility Service Handler Instance address
     * @param toggleHandlerAddr Toggle Service Handler Instance address
     * @param hatterAddr AVS Hatter Instance address
     */
    function updateEnvVars(
        address hatsAddr,
        address moduleFactoryAddr,
        address eligibilityImplAddr,
        address toggleImplAddr,
        address hatterImplAddr,
        address eligibilityHandlerAddr,
        address toggleHandlerAddr,
        address hatterAddr
    ) internal {
        string memory projectRoot = vm.projectRoot();
        string memory envPath = string.concat(projectRoot, "/.env");
        string memory backupPath = string.concat(projectRoot, "/.env.bak");
        string
            memory sectionMarker = "# Hats Protocol AVS Integration Addresses";

        // Create a backup of the .env file by reading and writing
        string memory envContent = vm.readFile(envPath);
        vm.writeFile(backupPath, envContent);
        console.log("Created backup of .env file at:", backupPath);

        // Create a new section with the latest addresses
        string memory newSection = string.concat(
            sectionMarker,
            "\n",
            "HATS_PROTOCOL_ADDRESS=",
            addressToString(hatsAddr),
            "\n",
            "HATS_MODULE_FACTORY_ADDRESS=",
            addressToString(moduleFactoryAddr),
            "\n",
            "HATS_ELIGIBILITY_SERVICE_HANDLER_IMPL=",
            addressToString(eligibilityImplAddr),
            "\n",
            "HATS_TOGGLE_SERVICE_HANDLER_IMPL=",
            addressToString(toggleImplAddr),
            "\n",
            "HATS_AVS_HATTER_IMPL=",
            addressToString(hatterImplAddr),
            "\n",
            "HATS_ELIGIBILITY_SERVICE_HANDLER=",
            addressToString(eligibilityHandlerAddr),
            "\n",
            "HATS_TOGGLE_SERVICE_HANDLER=",
            addressToString(toggleHandlerAddr),
            "\n",
            "HATS_AVS_HATTER=",
            addressToString(hatterAddr),
            "\n"
        );

        // Clean and update the .env file
        // Read file content and manually parse lines
        string memory content = vm.readFile(envPath);

        // Process the content line by line manually
        bytes memory contentBytes = bytes(content);
        bool sectionFound = false;
        bool skipLines = false;
        string memory cleanedContent = "";
        string memory currentLine = "";

        for (uint i = 0; i < contentBytes.length; i++) {
            bytes1 char = contentBytes[i];

            // Handle line endings (both \n and \r\n)
            if (char == "\n") {
                // Process the line
                if (stringsEqual(currentLine, sectionMarker)) {
                    if (!sectionFound) {
                        // First occurrence - replace with new section
                        sectionFound = true;
                        cleanedContent = string.concat(
                            cleanedContent,
                            newSection
                        );
                    }
                    // Skip this section (marker and following lines)
                    skipLines = true;
                }
                // Check if we hit an empty line or new section (starting with #)
                else if (
                    bytes(currentLine).length == 0 ||
                    (bytes(currentLine).length > 0 &&
                        bytes(currentLine)[0] == "#")
                ) {
                    // Stop skipping lines
                    skipLines = false;
                    cleanedContent = string.concat(
                        cleanedContent,
                        currentLine,
                        "\n"
                    );
                }
                // Regular line
                else if (!skipLines) {
                    cleanedContent = string.concat(
                        cleanedContent,
                        currentLine,
                        "\n"
                    );
                }

                // Reset current line
                currentLine = "";
            } else if (char != "\r") {
                // Skip carriage returns
                currentLine = string.concat(
                    currentLine,
                    string(abi.encodePacked(char))
                );
            }
        }

        // Handle the last line if not empty and doesn't end with newline
        if (bytes(currentLine).length > 0) {
            if (stringsEqual(currentLine, sectionMarker)) {
                if (!sectionFound) {
                    // First occurrence - replace with new section
                    sectionFound = true;
                    cleanedContent = string.concat(cleanedContent, newSection);
                }
                // Skip this line (it's our marker)
            }
            // Check if it's an empty line or new section (starting with #)
            else if (
                bytes(currentLine).length == 0 ||
                (bytes(currentLine).length > 0 && bytes(currentLine)[0] == "#")
            ) {
                cleanedContent = string.concat(
                    cleanedContent,
                    currentLine,
                    "\n"
                );
            }
            // Regular line
            else if (!skipLines) {
                cleanedContent = string.concat(
                    cleanedContent,
                    currentLine,
                    "\n"
                );
            }
        }

        // If section wasn't found, append it to the end
        if (!sectionFound) {
            // Add a newline if the file doesn't end with one
            if (
                bytes(cleanedContent).length > 0 &&
                bytes(cleanedContent)[bytes(cleanedContent).length - 1] != "\n"
            ) {
                cleanedContent = string.concat(cleanedContent, "\n");
            }
            cleanedContent = string.concat(cleanedContent, "\n", newSection);
        }

        // Write the cleaned content back to the .env file
        vm.writeFile(envPath, cleanedContent);
        console.log("Updated .env file with new deployment addresses");
    }

    /**
     * @dev Custom function to compare two strings for equality
     * @param a The first string
     * @param b The second string
     * @return True if the strings are equal, false otherwise
     */
    function stringsEqual(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /**
     * @dev Convert an address to a string
     * @param _addr The address to convert
     * @return The string representation of the address
     */
    function addressToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes memory addressBytes = abi.encodePacked(_addr);
        bytes memory stringBytes = new bytes(42);

        stringBytes[0] = "0";
        stringBytes[1] = "x";

        for (uint256 i = 0; i < 20; i++) {
            uint8 leftNibble = uint8(addressBytes[i]) / 16;
            uint8 rightNibble = uint8(addressBytes[i]) % 16;

            stringBytes[2 + i * 2] = leftNibble < 10
                ? bytes1(leftNibble + 48)
                : bytes1(leftNibble + 87);
            stringBytes[2 + i * 2 + 1] = rightNibble < 10
                ? bytes1(rightNibble + 48)
                : bytes1(rightNibble + 87);
        }

        return string(stringBytes);
    }
}

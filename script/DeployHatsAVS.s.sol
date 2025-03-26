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
import {HatsAVSMinter} from "../src/contracts/HatsAVSMinter.sol";
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

        // Deploy implementation contracts
        ImplementationAddresses memory implAddrs = deployImplementations(
            privateKey,
            hatsAddr,
            serviceManagerAddr
        );

        // Deploy instances
        InstanceAddresses memory instanceAddrs = deployInstances(
            privateKey,
            moduleFactoryAddr,
            implAddrs
        );

        // Update or add addresses to .env file
        CoreAddresses memory core = CoreAddresses({
            hatsAddr: hatsAddr,
            moduleFactoryAddr: moduleFactoryAddr
        });

        updateEnvVars(core, implAddrs, instanceAddrs);

        // Log deployment completion
        console.log("Hats Protocol WAVS AVS integration deployed successfully");
    }

    /**
     * @notice Deploy implementation contracts
     * @param _privateKey The private key to use for broadcasting transactions
     * @param _hatsAddr The address of the Hats Protocol contract
     * @param _serviceManagerAddr The address of the WAVS Service Manager
     * @return implAddrs The addresses of the deployed implementation contracts
     */
    function deployImplementations(
        uint256 _privateKey,
        address _hatsAddr,
        address _serviceManagerAddr
    ) internal returns (ImplementationAddresses memory implAddrs) {
        // Create instance of the Hats contract
        IHats hats = IHats(_hatsAddr);

        // Start broadcasting transactions
        vm.startBroadcast(_privateKey);

        // Deploy the eligibility service handler implementation
        HatsEligibilityServiceHandler eligibilityImpl = new HatsEligibilityServiceHandler(
                hats,
                _serviceManagerAddr,
                VERSION,
                DEFAULT_ELIGIBILITY_CHECK_COOLDOWN
            );
        console.log(
            "HatsEligibilityServiceHandler implementation deployed at: %s",
            address(eligibilityImpl)
        );

        // Deploy the toggle service handler implementation
        HatsToggleServiceHandler toggleImpl = new HatsToggleServiceHandler(
            hats,
            _serviceManagerAddr,
            VERSION,
            DEFAULT_STATUS_CHECK_COOLDOWN
        );
        console.log(
            "HatsToggleServiceHandler implementation deployed at: %s",
            address(toggleImpl)
        );

        // Deploy the hatter implementation
        HatsAVSHatter hatterImpl = new HatsAVSHatter(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAVSHatter implementation deployed at: %s",
            address(hatterImpl)
        );

        // Deploy the minter implementation
        HatsAVSMinter minterImpl = new HatsAVSMinter(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAVSMinter implementation deployed at: %s",
            address(minterImpl)
        );

        // Stop broadcasting
        vm.stopBroadcast();

        // Return the addresses
        return
            ImplementationAddresses({
                eligibilityImplAddr: address(eligibilityImpl),
                toggleImplAddr: address(toggleImpl),
                hatterImplAddr: address(hatterImpl),
                minterImplAddr: address(minterImpl)
            });
    }

    /**
     * @notice Deploy instance contracts
     * @param _privateKey The private key to use for broadcasting transactions
     * @param _moduleFactoryAddr The address of the Hats Module Factory
     * @param _implAddrs The addresses of the implementation contracts
     * @return instanceAddrs The addresses of the deployed instance contracts
     */
    function deployInstances(
        uint256 _privateKey,
        address _moduleFactoryAddr,
        ImplementationAddresses memory _implAddrs
    ) internal returns (InstanceAddresses memory instanceAddrs) {
        // Create instance of the factory
        HatsModuleFactory moduleFactory = HatsModuleFactory(_moduleFactoryAddr);

        // Start broadcasting transactions
        vm.startBroadcast(_privateKey);

        // Create module instances via factory
        address eligibilityHandler = _createModuleInstance(
            moduleFactory,
            _implAddrs.eligibilityImplAddr,
            "HatsEligibilityServiceHandler"
        );

        address toggleHandler = _createModuleInstance(
            moduleFactory,
            _implAddrs.toggleImplAddr,
            "HatsToggleServiceHandler"
        );

        address hatter = _createModuleInstance(
            moduleFactory,
            _implAddrs.hatterImplAddr,
            "HatsAVSHatter"
        );

        address minter = _createModuleInstance(
            moduleFactory,
            _implAddrs.minterImplAddr,
            "HatsAVSMinter"
        );

        // Stop broadcasting
        vm.stopBroadcast();

        // Return the addresses
        return
            InstanceAddresses({
                eligibilityHandlerAddr: eligibilityHandler,
                toggleHandlerAddr: toggleHandler,
                hatterAddr: hatter,
                minterAddr: minter
            });
    }

    /**
     * @notice Create a module instance via the factory
     * @param _factory The Hats Module Factory
     * @param _implementation The address of the implementation contract
     * @param _name The name of the module (for logging)
     * @return instance The address of the deployed instance
     */
    function _createModuleInstance(
        HatsModuleFactory _factory,
        address _implementation,
        string memory _name
    ) internal returns (address instance) {
        instance = _factory.createHatsModule(
            _implementation, // implementation
            0, // hatId (0 means no hat associated)
            abi.encode(""), // parameters encoded as bytes
            abi.encode(address(0)), // owner encoded as bytes
            0 // saltNonce
        );
        console.log("%s instance deployed at: %s", _name, instance);
        return instance;
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

    // Define a struct to hold all the addresses, but split into smaller groups
    struct CoreAddresses {
        address hatsAddr;
        address moduleFactoryAddr;
    }

    struct ImplementationAddresses {
        address eligibilityImplAddr;
        address toggleImplAddr;
        address hatterImplAddr;
        address minterImplAddr;
    }

    struct InstanceAddresses {
        address eligibilityHandlerAddr;
        address toggleHandlerAddr;
        address hatterAddr;
        address minterAddr;
    }

    /**
     * @notice Update or add Hats AVS addresses to the .env file
     */
    function updateEnvVars(
        CoreAddresses memory _core,
        ImplementationAddresses memory _impls,
        InstanceAddresses memory _instances
    ) internal {
        string memory projectRoot = vm.projectRoot();
        string memory envPath = string.concat(projectRoot, "/.env");
        string memory backupPath = string.concat(projectRoot, "/.env.bak");

        // Create a backup of the .env file
        _backupEnvFile(envPath, backupPath);

        // Create sections individually to avoid stack depth issues
        string memory coreSection = _createCoreSection(_core);
        string memory implSection = _createImplSection(_impls);
        string memory instanceSection = _createInstanceSection(_instances);

        // Combine all sections
        string
            memory sectionMarker = "# Hats Protocol AVS Integration Addresses";
        string memory newSection = string.concat(
            coreSection,
            implSection,
            instanceSection
        );

        // Process and update the file
        _processEnvFile(envPath, sectionMarker, newSection);
    }

    // Break out section creation into dedicated functions
    function _createCoreSection(
        CoreAddresses memory _core
    ) internal pure returns (string memory) {
        string
            memory sectionMarker = "# Hats Protocol AVS Integration Addresses";
        return
            string.concat(
                sectionMarker,
                "\n",
                "HATS_PROTOCOL_ADDRESS=",
                addressToString(_core.hatsAddr),
                "\n",
                "HATS_MODULE_FACTORY_ADDRESS=",
                addressToString(_core.moduleFactoryAddr),
                "\n"
            );
    }

    function _createImplSection(
        ImplementationAddresses memory _impls
    ) internal pure returns (string memory) {
        return
            string.concat(
                "HATS_ELIGIBILITY_SERVICE_HANDLER_IMPL=",
                addressToString(_impls.eligibilityImplAddr),
                "\n",
                "HATS_TOGGLE_SERVICE_HANDLER_IMPL=",
                addressToString(_impls.toggleImplAddr),
                "\n",
                "HATS_AVS_HATTER_IMPL=",
                addressToString(_impls.hatterImplAddr),
                "\n",
                "HATS_AVS_MINTER_IMPL=",
                addressToString(_impls.minterImplAddr),
                "\n"
            );
    }

    function _createInstanceSection(
        InstanceAddresses memory _instances
    ) internal pure returns (string memory) {
        return
            string.concat(
                "HATS_ELIGIBILITY_SERVICE_HANDLER=",
                addressToString(_instances.eligibilityHandlerAddr),
                "\n",
                "HATS_TOGGLE_SERVICE_HANDLER=",
                addressToString(_instances.toggleHandlerAddr),
                "\n",
                "HATS_AVS_HATTER=",
                addressToString(_instances.hatterAddr),
                "\n",
                "HATS_AVS_MINTER=",
                addressToString(_instances.minterAddr),
                "\n"
            );
    }

    /**
     * @notice Create a backup of the env file
     */
    function _backupEnvFile(
        string memory _envPath,
        string memory _backupPath
    ) internal {
        string memory envContent = vm.readFile(_envPath);
        vm.writeFile(_backupPath, envContent);
        console.log("Created backup of .env file at:", _backupPath);
    }

    /**
     * @notice Process the env file and update it with the new section
     */
    function _processEnvFile(
        string memory _envPath,
        string memory _sectionMarker,
        string memory _newSection
    ) internal {
        // Read file content
        string memory content = vm.readFile(_envPath);

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
                if (stringsEqual(currentLine, _sectionMarker)) {
                    if (!sectionFound) {
                        // First occurrence - replace with new section
                        sectionFound = true;
                        cleanedContent = string.concat(
                            cleanedContent,
                            _newSection
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

        // Handle the last line
        cleanedContent = _processLastLine(
            currentLine,
            _sectionMarker,
            sectionFound,
            skipLines,
            cleanedContent,
            _newSection
        );

        // Write the cleaned content back to the .env file
        vm.writeFile(_envPath, cleanedContent);
        console.log("Updated .env file with new deployment addresses");
    }

    /**
     * @notice Process the last line of the env file
     */
    function _processLastLine(
        string memory _currentLine,
        string memory _sectionMarker,
        bool _sectionFound,
        bool _skipLines,
        string memory _cleanedContent,
        string memory _newSection
    ) internal pure returns (string memory) {
        string memory result = _cleanedContent;

        // Handle the last line if not empty and doesn't end with newline
        if (bytes(_currentLine).length > 0) {
            if (stringsEqual(_currentLine, _sectionMarker)) {
                if (!_sectionFound) {
                    // First occurrence - replace with new section
                    result = string.concat(result, _newSection);
                }
                // Skip this line (it's our marker)
            }
            // Check if it's an empty line or new section (starting with #)
            else if (
                bytes(_currentLine).length == 0 ||
                (bytes(_currentLine).length > 0 &&
                    bytes(_currentLine)[0] == "#")
            ) {
                result = string.concat(result, _currentLine, "\n");
            }
            // Regular line
            else if (!_skipLines) {
                result = string.concat(result, _currentLine, "\n");
            }
        }

        // If section wasn't found, append it to the end
        if (!_sectionFound) {
            // Add a newline if the file doesn't end with one
            if (
                bytes(result).length > 0 &&
                bytes(result)[bytes(result).length - 1] != "\n"
            ) {
                result = string.concat(result, "\n");
            }
            result = string.concat(result, "\n", _newSection);
        }

        return result;
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

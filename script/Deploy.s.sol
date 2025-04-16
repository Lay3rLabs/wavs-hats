// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {HatsModuleFactory} from "@hats-module/src/HatsModuleFactory.sol";
// Import Hats Protocol and Hats Module Factory for deployment
import {Hats} from "hats-protocol/Hats.sol";
import {Utils} from "./Utils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {HatsAvsEligibilityModule} from "../src/contracts/HatsAvsEligibilityModule.sol";
import {HatsAvsToggleModule} from "../src/contracts/HatsAvsToggleModule.sol";
import {HatsAvsHatter} from "../src/contracts/HatsAvsHatter.sol";
import {HatsAvsMinter} from "../src/contracts/HatsAvsMinter.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";

/**
 * @title Deploy
 * @notice Deployment script for the Hats Protocol WAVS AVS integration
 */
contract Deploy is Script {
    using stdJson for string;

    // Default values for constructor parameters
    string public constant VERSION = "0.1.0";

    // Add at the top of your run() function or as a class variable
    string public root = vm.projectRoot();
    string public script_output_path =
        string.concat(root, "/.docker/script_deploy.json");

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

        // Write addresses to JSON file
        writeAddressesToFile(
            deployer,
            serviceManagerAddr,
            hatsAddr,
            moduleFactoryAddr,
            implAddrs,
            instanceAddrs
        );

        // Log deployment completion
        console.log("Hats Protocol WAVS AVS integration deployed successfully");
    }

    /**
     * @notice Write addresses to JSON file in smaller chunks to avoid stack too deep errors
     */
    function writeAddressesToFile(
        address deployer,
        address serviceManagerAddr,
        address hatsAddr,
        address moduleFactoryAddr,
        ImplementationAddresses memory implAddrs,
        InstanceAddresses memory instanceAddrs
    ) internal {
        // Write address pairs to file iteratively to avoid stack depth issues
        vm.writeFile(script_output_path, "{");

        appendAddressPair("deployer", deployer, true);
        appendAddressPair("serviceManager", serviceManagerAddr, false);
        appendAddressPair("hatsProtocol", hatsAddr, false);
        appendAddressPair("moduleFactory", moduleFactoryAddr, false);

        appendAddressPair(
            "eligibilityModuleImpl",
            implAddrs.eligibilityImplAddr,
            false
        );
        appendAddressPair("toggleModuleImpl", implAddrs.toggleImplAddr, false);
        appendAddressPair("hatterImpl", implAddrs.hatterImplAddr, false);
        appendAddressPair("minterImpl", implAddrs.minterImplAddr, false);

        appendAddressPair(
            "eligibilityModule",
            instanceAddrs.eligibilityHandlerAddr,
            false
        );
        appendAddressPair(
            "toggleModule",
            instanceAddrs.toggleHandlerAddr,
            false
        );
        appendAddressPair("hatter", instanceAddrs.hatterAddr, false);
        appendAddressPair("minter", instanceAddrs.minterAddr, false);

        appendToFile("}");
    }

    /**
     * @notice Append an address pair to the JSON file
     * @param key The key for the JSON object
     * @param addr The address to write
     * @param isFirst Whether this is the first pair (no leading comma)
     */
    function appendAddressPair(
        string memory key,
        address addr,
        bool isFirst
    ) internal {
        string memory prefix = isFirst ? "" : ",";
        string memory pair = string.concat(
            prefix,
            '"',
            key,
            '":"',
            Strings.toHexString(addr),
            '"'
        );
        appendToFile(pair);
    }

    /**
     * @notice Append a string to the JSON file
     * @param content The content to append
     */
    function appendToFile(string memory content) internal {
        string memory currentContent = vm.readFile(script_output_path);
        vm.writeFile(
            script_output_path,
            string.concat(currentContent, content)
        );
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
        HatsAvsEligibilityModule eligibilityImpl = new HatsAvsEligibilityModule(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAvsEligibilityModule implementation deployed at: %s",
            address(eligibilityImpl)
        );

        // Deploy the toggle service handler implementation
        HatsAvsToggleModule toggleImpl = new HatsAvsToggleModule(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAvsToggleModule implementation deployed at: %s",
            address(toggleImpl)
        );

        // Deploy the hatter implementation
        HatsAvsHatter hatterImpl = new HatsAvsHatter(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAvsHatter implementation deployed at: %s",
            address(hatterImpl)
        );

        // Deploy the minter implementation
        HatsAvsMinter minterImpl = new HatsAvsMinter(
            hats,
            _serviceManagerAddr,
            VERSION
        );
        console.log(
            "HatsAvsMinter implementation deployed at: %s",
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
            "HatsAvsEligibilityModule"
        );

        address toggleHandler = _createModuleInstance(
            moduleFactory,
            _implAddrs.toggleImplAddr,
            "HatsAvsToggleModule"
        );

        address hatter = _createModuleInstance(
            moduleFactory,
            _implAddrs.hatterImplAddr,
            "HatsAvsHatter"
        );

        address minter = _createModuleInstance(
            moduleFactory,
            _implAddrs.minterImplAddr,
            "HatsAvsMinter"
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
}

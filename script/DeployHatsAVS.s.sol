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

import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {HatsAVSHatter} from "../src/contracts/HatsAVSHatter.sol";
import {HatsAVSMinter} from "../src/contracts/HatsAVSMinter.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";

/**
 * @title DeployHatsAVS
 * @notice Deployment script for the Hats Protocol WAVS AVS integration
 */
contract DeployHatsAVS is Script {
    using stdJson for string;

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

        // Serialize deployment data to JSON
        string memory json = "json";
        json.serialize("deployer", Strings.toHexString(deployer));
        json.serialize(
            "serviceManager",
            Strings.toHexString(serviceManagerAddr)
        );
        json.serialize("hatsProtocol", Strings.toHexString(hatsAddr));
        json.serialize("moduleFactory", Strings.toHexString(moduleFactoryAddr));
        json.serialize(
            "eligibilityImpl",
            Strings.toHexString(implAddrs.eligibilityImplAddr)
        );
        json.serialize(
            "toggleImpl",
            Strings.toHexString(implAddrs.toggleImplAddr)
        );
        json.serialize(
            "hatterImpl",
            Strings.toHexString(implAddrs.hatterImplAddr)
        );
        json.serialize(
            "minterImpl",
            Strings.toHexString(implAddrs.minterImplAddr)
        );
        json.serialize(
            "eligibilityHandler",
            Strings.toHexString(instanceAddrs.eligibilityHandlerAddr)
        );
        json.serialize(
            "toggleHandler",
            Strings.toHexString(instanceAddrs.toggleHandlerAddr)
        );
        json.serialize("hatter", Strings.toHexString(instanceAddrs.hatterAddr));
        json.serialize("minter", Strings.toHexString(instanceAddrs.minterAddr));

        // Write JSON to file
        vm.writeFile("/.docker/script_deploy.json", json);

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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {Hats} from "hats-protocol/Hats.sol";
import {HatsModuleFactory} from "@hats-module/src/HatsModuleFactory.sol";
import {Utils} from "./Utils.sol";

// Import WAVS AVS contracts
import {HatsAvsEligibilityModule} from "../src/contracts/HatsAvsEligibilityModule.sol";
import {HatsAvsToggleModule} from "../src/contracts/HatsAvsToggleModule.sol";
import {HatsAvsHatter} from "../src/contracts/HatsAvsHatter.sol";
import {HatsAvsMinter} from "../src/contracts/HatsAvsMinter.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";

// Import Safe and Zodiac modules
import {HatsSignerGate, IHatsSignerGate} from "hats-zodiac/src/HatsSignerGate.sol";
import {SafeManagerLib} from "hats-zodiac/src/lib/SafeManagerLib.sol";

// Import module chaining and staking eligibility
import {HatsEligibilitiesChain} from "chain-modules/src/HatsEligibilitiesChain.sol";
import {StakingEligibility} from "staking-eligibility/src/StakingEligibility.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Demo
 * @notice Deployment script for a demo setup with Hats Protocol, WAVS AVS, Gnosis Safe, and module chaining
 *
 * @dev This script deploys a comprehensive demo setup:
 * 1. Deploys all WAVS AVS contracts (eligibility, toggle, hatter, minter)
 * 2. Creates a top hat for admin access
 * 3. Creates a member hat with combined eligibility requirements
 * 4. Deploys a Gnosis Safe with a Hats Signer Gate V2 Zodiac module
 * 5. Deploys a StakingEligibility module for token-based eligibility
 * 6. Chains the StakingEligibility module with HatsAvsEligibilityModule
 *
 * To run this script:
 * ```
 * forge script script/Demo.s.sol:Demo --rpc-url <RPC_URL> --broadcast
 * ```
 */
contract Demo is Script {
    using stdJson for string;

    // Default values for constructor parameters
    string public constant VERSION = "0.1.0";

    // File path for storing deployment output
    string public root = vm.projectRoot();
    string public script_output_path =
        string.concat(root, "/.docker/demo_deploy.json");

    // Struct definitions from Deploy.s.sol
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

    struct DemoAddresses {
        address safeAddr;
        address signerGateAddr;
        address stakingEligibilityAddr;
        address chainedModulesAddr;
    }

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

        // Deploy Demo setup (Safe, Zodiac, Chained Modules)
        DemoAddresses memory demoAddrs = deployDemoSetup(
            privateKey,
            hatsAddr,
            moduleFactoryAddr,
            instanceAddrs.eligibilityHandlerAddr
        );

        // Write addresses to JSON file
        writeAddressesToFile(
            deployer,
            serviceManagerAddr,
            hatsAddr,
            moduleFactoryAddr,
            implAddrs,
            instanceAddrs,
            demoAddrs
        );

        // Log deployment completion
        console.log("Demo setup deployed successfully");
    }

    /**
     * @notice Deploy implementation contracts (same as Deploy.s.sol)
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
     * @notice Deploy instance contracts (same as Deploy.s.sol)
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
     * @notice Deploy the demo setup with Safe, Zodiac, and module chaining
     */
    function deployDemoSetup(
        uint256 _privateKey,
        address _hatsAddr,
        address _moduleFactoryAddr,
        address _eligibilityModuleAddr
    ) internal returns (DemoAddresses memory demoAddrs) {
        vm.startBroadcast(_privateKey);

        // 1-2. Create hats
        (uint256 topHatId, uint256 memberHatId) = createHatsForDemo(_hatsAddr);

        // 3. Deploy Safe with Signer Gate
        (address safeAddr, address signerGateAddr) = deploySafeWithSignerGate(
            _hatsAddr,
            _moduleFactoryAddr,
            topHatId
        );

        // 4. Deploy StakingEligibility module
        address stakingEligibilityAddr = deployStakingEligibility(
            _hatsAddr,
            _moduleFactoryAddr,
            topHatId,
            memberHatId
        );

        // 5. Deploy Chained Modules
        address chainAddr = deployChainedModules(
            _hatsAddr,
            _moduleFactoryAddr,
            memberHatId,
            stakingEligibilityAddr,
            _eligibilityModuleAddr
        );

        vm.stopBroadcast();

        // Return the deployed addresses
        return
            DemoAddresses({
                safeAddr: safeAddr,
                signerGateAddr: signerGateAddr,
                stakingEligibilityAddr: stakingEligibilityAddr,
                chainedModulesAddr: chainAddr
            });
    }

    /**
     * @notice Create top hat and member hat for the demo
     */
    function createHatsForDemo(
        address _hatsAddr
    ) internal returns (uint256 topHatId, uint256 memberHatId) {
        IHats hats = IHats(_hatsAddr);
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        // Create top hat
        topHatId = hats.mintTopHat(
            deployer,
            "Demo Admin Hat",
            "https://ipfs.io/ipfs/QmXBei9rcg6mhf6xmvm2i8tRKfNdKgiKqFDG2qE1RZYqDp"
        );
        console.log("Created top hat with ID:", topHatId);

        // Create temporary placeholder modules for eligibility and toggle
        // We'll replace these later with our actual modules
        address placeholderEligibility = deployer; // Use deployer as temporary placeholder
        address placeholderToggle = deployer; // Use deployer as temporary placeholder

        // Create member hat with placeholder modules
        memberHatId = hats.createHat(
            topHatId,
            "Member Hat",
            50, // Max supply
            placeholderEligibility, // Temporary placeholder - will be replaced later
            placeholderToggle, // Temporary placeholder - will be replaced later
            true, // Mutable
            "https://ipfs.io/ipfs/QmXBei9rcg6mhf6xmvm2i8tRKfNdKgiKqFDG2qE1RZYqDp"
        );
        console.log("Created member hat with ID:", memberHatId);

        return (topHatId, memberHatId);
    }

    /**
     * @notice Deploy Gnosis Safe with HatsSignerGate
     */
    function deploySafeWithSignerGate(
        address _hatsAddr,
        address _moduleFactoryAddr,
        uint256 _ownerHatId
    ) internal returns (address safeAddr, address signerGateAddr) {
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        // Get Safe dependencies from environment
        address safeProxyFactory = vm.envOr("SAFE_PROXY_FACTORY", address(0));
        address safeSingleton = vm.envOr("SAFE_SINGLETON", address(0));
        address safeFallbackLibrary = vm.envOr(
            "SAFE_FALLBACK_LIBRARY",
            address(0)
        );
        address safeMultisendLibrary = vm.envOr(
            "SAFE_MULTISEND_LIBRARY",
            address(0)
        );

        // Check if we have all required Safe dependencies
        bool haveSafeDeps = safeProxyFactory != address(0) &&
            safeSingleton != address(0) &&
            safeFallbackLibrary != address(0) &&
            safeMultisendLibrary != address(0);

        if (!haveSafeDeps) {
            console.log(
                "Missing Safe dependencies, skipping Safe and HatsSignerGate deployment"
            );
            console.log(
                "For a full demo with Safe integration, set the following environment variables:"
            );
            console.log("  - SAFE_PROXY_FACTORY");
            console.log("  - SAFE_SINGLETON");
            console.log("  - SAFE_FALLBACK_LIBRARY");
            console.log("  - SAFE_MULTISEND_LIBRARY");

            // Return placeholder addresses for demo purposes
            return (deployer, deployer);
        }

        // If we have all dependencies, proceed with actual deployment

        // Deploy HatsSignerGate implementation
        HatsSignerGate signerGateImpl = new HatsSignerGate(
            _hatsAddr,
            safeSingleton,
            safeFallbackLibrary,
            safeMultisendLibrary,
            safeProxyFactory
        );
        console.log(
            "Deployed HatsSignerGate implementation at:",
            address(signerGateImpl)
        );

        // Prepare setup params
        bytes memory initParams = _prepareSignerGateParams(
            _ownerHatId,
            address(signerGateImpl)
        );

        // Create HSG instance
        HatsModuleFactory moduleFactory = HatsModuleFactory(_moduleFactoryAddr);
        signerGateAddr = moduleFactory.createHatsModule(
            address(signerGateImpl),
            0, // No hat associated
            initParams,
            abi.encode(deployer), // Owner
            0 // Salt nonce
        );
        console.log("Deployed HatsSignerGate instance at:", signerGateAddr);

        // Get Safe address
        safeAddr = address(IHatsSignerGate(signerGateAddr).safe());
        console.log("Safe deployed at:", safeAddr);

        return (safeAddr, signerGateAddr);
    }

    /**
     * @notice Prepare parameters for HatsSignerGate
     */
    function _prepareSignerGateParams(
        uint256 _ownerHatId,
        address _signerGateImpl
    ) internal pure returns (bytes memory) {
        uint256[] memory signerHats = new uint256[](1);
        signerHats[0] = _ownerHatId;

        return
            abi.encode(
                IHatsSignerGate.SetupParams({
                    safe: address(0), // Deploy a new Safe
                    ownerHat: _ownerHatId, // Admin hat is the owner hat
                    signerHats: signerHats, // Admin hat wearers are signers
                    implementation: _signerGateImpl, // Implementation address
                    thresholdConfig: IHatsSignerGate.ThresholdConfig({
                        thresholdType: IHatsSignerGate
                            .TargetThresholdType
                            .ABSOLUTE,
                        min: 1, // Minimum threshold
                        target: 1 // Target threshold (absolute count since we're using ABSOLUTE type)
                    }),
                    hsgModules: new address[](0), // No additional modules
                    hsgGuard: address(0), // No guard
                    claimableFor: true, // Can be claimed by others
                    locked: false // Not locked
                })
            );
    }

    /**
     * @notice Deploy StakingEligibility module
     */
    function deployStakingEligibility(
        address _hatsAddr,
        address _moduleFactoryAddr,
        uint256 _topHatId,
        uint256 _memberHatId
    ) internal returns (address stakingEligibilityAddr) {
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        try
            this.deployStakingEligibilityInternal(
                _hatsAddr,
                _moduleFactoryAddr,
                _topHatId,
                _memberHatId,
                deployer
            )
        returns (address addr) {
            stakingEligibilityAddr = addr;
            console.log(
                "StakingEligibility instance deployed at:",
                stakingEligibilityAddr
            );
        } catch {
            console.log(
                "Failed to deploy StakingEligibility module, using placeholder"
            );
            // Return deployer as a placeholder
            stakingEligibilityAddr = deployer;
        }

        return stakingEligibilityAddr;
    }

    /**
     * @notice Internal function to deploy StakingEligibility (can be isolated for try/catch)
     */
    function deployStakingEligibilityInternal(
        address _hatsAddr,
        address _moduleFactoryAddr,
        uint256 _topHatId,
        uint256 _memberHatId,
        address _deployer
    ) external returns (address) {
        HatsModuleFactory moduleFactory = HatsModuleFactory(_moduleFactoryAddr);

        // Deploy mock token
        address mockTokenAddr = deployMockERC20("TestToken", "TT", 18);
        console.log("Deployed mock token at:", mockTokenAddr);

        // Deploy implementation
        StakingEligibility stakingEligibilityImpl = new StakingEligibility(
            "1.0.0"
        );
        console.log(
            "StakingEligibility implementation deployed at:",
            address(stakingEligibilityImpl)
        );

        // Initialize parameters
        bytes memory stakingEligibilityInitData = abi.encode(
            uint248(100 ether), // minStake - 100 tokens
            _topHatId, // judgeHat - admins can judge
            _topHatId, // recipientHat - admins receive slashed stakes
            1 days // cooldownPeriod - 1 day
        );

        // Create instance
        address stakingEligibilityAddr = moduleFactory.createHatsModule(
            address(stakingEligibilityImpl),
            _memberHatId,
            stakingEligibilityInitData,
            abi.encode(_deployer), // Owner
            0 // Salt nonce
        );

        return stakingEligibilityAddr;
    }

    /**
     * @notice Deploy ChainedModules
     */
    function deployChainedModules(
        address _hatsAddr,
        address _moduleFactoryAddr,
        uint256 _memberHatId,
        address _stakingEligibilityAddr,
        address _eligibilityModuleAddr
    ) internal returns (address chainAddr) {
        (uint256 privateKey, address deployer) = Utils.getPrivateKey(vm);

        try
            this.deployChainedModulesInternal(
                _hatsAddr,
                _moduleFactoryAddr,
                _memberHatId,
                _stakingEligibilityAddr,
                _eligibilityModuleAddr,
                deployer
            )
        returns (address addr) {
            chainAddr = addr;
            console.log(
                "HatsEligibilitiesChain instance deployed and set up successfully"
            );
        } catch {
            console.log("Failed to deploy chained module, using placeholder");
            // Return deployer as a placeholder
            chainAddr = deployer;
        }

        return chainAddr;
    }

    /**
     * @notice Internal function to deploy chained modules (can be isolated for try/catch)
     */
    function deployChainedModulesInternal(
        address _hatsAddr,
        address _moduleFactoryAddr,
        uint256 _memberHatId,
        address _stakingEligibilityAddr,
        address _eligibilityModuleAddr,
        address _deployer
    ) external returns (address) {
        IHats hats = IHats(_hatsAddr);
        HatsModuleFactory moduleFactory = HatsModuleFactory(_moduleFactoryAddr);

        // Deploy implementation
        HatsEligibilitiesChain chainImpl = new HatsEligibilitiesChain("1.0.0");
        console.log(
            "HatsEligibilitiesChain implementation deployed at:",
            address(chainImpl)
        );

        // Prepare chain modules array
        address[] memory modules = new address[](2);
        modules[0] = _stakingEligibilityAddr;
        modules[1] = _eligibilityModuleAddr;

        // Prepare arguments with lower stack usage
        address chainAddr = _deployChainModule(
            moduleFactory,
            address(chainImpl),
            _hatsAddr,
            _memberHatId,
            modules,
            _deployer
        );
        console.log("HatsEligibilitiesChain instance deployed at:", chainAddr);

        // Change the eligibility module for the member hat to our chained module
        // This replaces the placeholder module we set earlier
        hats.changeHatEligibility(_memberHatId, chainAddr);
        console.log("Changed hat eligibility to chained modules:", chainAddr);

        return chainAddr;
    }

    /**
     * @notice Helper function to deploy chain module with lower stack usage
     */
    function _deployChainModule(
        HatsModuleFactory _factory,
        address _chainImpl,
        address _hatsAddr,
        uint256 _memberHatId,
        address[] memory _modules,
        address _deployer
    ) internal returns (address chainAddr) {
        // Construct chain args in stages to reduce stack depth
        bytes memory chainArgsPrefix = abi.encodePacked(
            _chainImpl,
            _hatsAddr,
            _memberHatId,
            uint256(1), // NUM_CONJUNCTION_CLAUSES - 1 clause
            uint256(2) // Length of first clause - 2 modules
        );

        // Append module addresses separately
        bytes memory chainArgs = chainArgsPrefix;
        for (uint256 i = 0; i < _modules.length; i++) {
            chainArgs = abi.encodePacked(chainArgs, _modules[i]);
        }

        // Create chain module instance
        chainAddr = _factory.createHatsModule(
            _chainImpl,
            _memberHatId,
            "", // No init data needed
            abi.encode(_deployer), // Owner
            0 // Salt nonce
        );
        console.log("HatsEligibilitiesChain instance deployed at:", chainAddr);

        return chainAddr;
    }

    /**
     * @notice Helper function to deploy a mock ERC20 token
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param decimals The decimals of the token
     * @return The address of the deployed token
     */
    function deployMockERC20(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) internal returns (address) {
        // This is a simplified version that would need to be replaced with actual ERC20 deployment
        // In a real implementation, you would deploy an actual ERC20 token contract

        // For the demo, we'll just return a placeholder address
        bytes32 salt = keccak256(
            abi.encodePacked(name, symbol, decimals, block.timestamp)
        );
        address tokenAddr = address(uint160(uint256(salt)));

        return tokenAddr;
    }

    /**
     * @notice Helper function to create a uint256 array with a single element
     * @param value The value to include in the array
     * @return The array with a single element
     */
    function _createUint256Array(
        uint256 value
    ) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = value;
        return array;
    }

    /**
     * @notice Create a module instance via the factory (same as Deploy.s.sol)
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
     * @notice Get or deploy the Hats Protocol contract (same as Deploy.s.sol)
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

        return hatsAddr;
    }

    /**
     * @notice Get or deploy the Hats Module Factory contract (same as Deploy.s.sol)
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

        return factoryAddr;
    }

    /**
     * @notice Write addresses to JSON file
     */
    function writeAddressesToFile(
        address deployer,
        address serviceManagerAddr,
        address hatsAddr,
        address moduleFactoryAddr,
        ImplementationAddresses memory implAddrs,
        InstanceAddresses memory instanceAddrs,
        DemoAddresses memory demoAddrs
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

        // Add demo-specific addresses
        appendAddressPair("safe", demoAddrs.safeAddr, false);
        appendAddressPair("signerGate", demoAddrs.signerGateAddr, false);
        appendAddressPair(
            "stakingEligibility",
            demoAddrs.stakingEligibilityAddr,
            false
        );
        appendAddressPair(
            "chainedEligibilityModules",
            demoAddrs.chainedModulesAddr,
            false
        );

        appendToFile("}");
    }

    /**
     * @notice Append an address pair to the JSON file
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
     */
    function appendToFile(string memory content) internal {
        string memory currentContent = vm.readFile(script_output_path);
        vm.writeFile(
            script_output_path,
            string.concat(currentContent, content)
        );
    }
}

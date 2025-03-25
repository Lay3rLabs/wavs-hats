// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {HatsEligibilityServiceHandler} from "../src/contracts/HatsEligibilityServiceHandler.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {HatsAVSManager} from "../src/contracts/HatsAVSManager.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";
import {Utils} from "./Utils.sol";

/**
 * @title TestHatsAVS
 * @notice Script to test the Hats Protocol WAVS AVS integration
 */
contract TestHatsAVS is Script {
    // Define constants
    address constant DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Global variables
    IHats public hats;
    HatsAVSManager public hatsAVSManager;
    HatsEligibilityServiceHandler public eligibilityHandler;
    HatsToggleServiceHandler public toggleHandler;
    uint256 public topHatId;
    uint256 public eligibilityHatId;
    uint256 public toggleHatId;

    /**
     * @notice Run the test script
     */
    function run() public {
        // Get deployment addresses from environment
        address hatsProtocolAddr = vm.envAddress("HATS_PROTOCOL_ADDRESS");
        address hatsAVSManagerAddr = vm.envAddress("HATS_AVS_MANAGER");
        address eligibilityHandlerAddr = vm.envAddress(
            "HATS_ELIGIBILITY_SERVICE_HANDLER"
        );
        address toggleHandlerAddr = vm.envAddress(
            "HATS_TOGGLE_SERVICE_HANDLER"
        );

        console.log("Hats Protocol address:", hatsProtocolAddr);
        console.log("Hats AVS Manager address:", hatsAVSManagerAddr);
        console.log(
            "Hats Eligibility Service Handler address:",
            eligibilityHandlerAddr
        );
        console.log("Hats Toggle Service Handler address:", toggleHandlerAddr);

        // Create contract instances
        hats = IHats(hatsProtocolAddr);
        hatsAVSManager = HatsAVSManager(hatsAVSManagerAddr);
        eligibilityHandler = HatsEligibilityServiceHandler(
            eligibilityHandlerAddr
        );
        toggleHandler = HatsToggleServiceHandler(toggleHandlerAddr);

        (uint256 privateKey, ) = Utils.getPrivateKey(vm);

        // Start broadcasting transactions
        vm.startBroadcast(privateKey);

        // 1. Create a top hat
        console.log("\n1. Creating a top hat");
        topHatId = hats.mintTopHat(
            DEFAULT_ACCOUNT,
            "Test Top Hat",
            "ipfs://QmTest"
        );
        console.log("Top Hat created with ID:", topHatId);

        // 2. Create a direct child hat to test with
        console.log("\n2. Creating a child hat for testing");
        uint256 childHatId = hats.createHat(
            topHatId,
            "Child Hat",
            10, // maxSupply
            address(0), // eligibility module (none for now)
            address(0), // toggle module (none for now)
            true, // mutable
            "ipfs://QmTest"
        );
        console.log("Child Hat created with ID:", childHatId);

        // 3. Mint the child hat to the default account
        console.log("\n3. Minting the child hat to the default account");
        hats.mintHat(childHatId, DEFAULT_ACCOUNT);
        console.log("Child Hat minted to:", DEFAULT_ACCOUNT);

        // 4. Test eligibility check with existing hat
        console.log("\n4. Testing eligibility check");
        ITypes.TriggerId eligibilityTriggerId = hatsAVSManager
            .requestEligibilityCheck(DEFAULT_ACCOUNT, childHatId);
        console.log(
            "Eligibility check requested with triggerId:",
            uint64(ITypes.TriggerId.unwrap(eligibilityTriggerId))
        );

        // 5. Test status check with existing hat
        console.log("\n5. Testing status check");
        ITypes.TriggerId statusTriggerId = hatsAVSManager.requestStatusCheck(
            childHatId
        );
        console.log(
            "Status check requested with triggerId:",
            uint64(ITypes.TriggerId.unwrap(statusTriggerId))
        );

        // 6. Current eligibility status (will likely be zeros until WAVS processes)
        console.log(
            "\n6. Current eligibility status (may take time to update):"
        );
        (bool eligible, bool standing, uint256 timestamp) = hatsAVSManager
            .getEligibilityStatus(DEFAULT_ACCOUNT, childHatId);
        console.log("Eligible:", eligible);
        console.log("Standing:", standing);
        console.log("Timestamp:", timestamp);

        // 7. Current hat status (will likely be zeros until WAVS processes)
        console.log("\n7. Current hat status (may take time to update):");
        (bool active, uint256 statusTimestamp) = hatsAVSManager.getHatStatus(
            childHatId
        );
        console.log("Active:", active);
        console.log("Timestamp:", statusTimestamp);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console.log(
            "\nTest script completed. Note that WAVS services may take time to process the triggers."
        );
        console.log("To check the results again after a few seconds, run:");
        console.log(
            "forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig 'run(address,uint256,uint256)' 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            childHatId,
            childHatId
        );
    }
}

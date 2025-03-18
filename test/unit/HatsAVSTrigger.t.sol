// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {HatsAVSTrigger} from "../../src/contracts/HatsAVSTrigger.sol";
import {ITypes} from "../../src/interfaces/ITypes.sol";

/**
 * @title HatsAVSTriggerTest
 * @notice Test for the HatsAVSTrigger contract
 */
contract HatsAVSTriggerTest is Test, ITypes {
    // Contract to test
    HatsAVSTrigger internal trigger;

    // Test addresses
    address internal user1 = address(0x1);
    address internal user2 = address(0x2);

    // Test hat IDs
    uint256 internal hatId1 = 1;
    uint256 internal hatId2 = 2;

    /**
     * @notice Set up the test
     */
    function setUp() public {
        // Deploy the trigger contract
        trigger = new HatsAVSTrigger();
    }

    /**
     * @notice Test creating an eligibility trigger
     */
    function test_CreateEligibilityTrigger() public {
        // Create a trigger
        TriggerId triggerId = trigger.createEligibilityTrigger(user1, hatId1);

        // Check that the trigger ID is not 0
        assertTrue(
            TriggerId.unwrap(triggerId) > 0,
            "Trigger ID should be greater than 0"
        );

        // Check that the trigger data is correct
        (address creator, bytes memory data) = trigger.triggersById(triggerId);

        // Check creator
        assertEq(creator, address(this), "Creator should be the test contract");

        // Decode data
        (address wearer, uint256 hatId) = abi.decode(data, (address, uint256));

        // Check decoded data
        assertEq(wearer, user1, "Wearer should be user1");
        assertEq(hatId, hatId1, "Hat ID should be hatId1");
    }

    /**
     * @notice Test creating a status trigger
     */
    function test_CreateStatusTrigger() public {
        // Create a trigger
        TriggerId triggerId = trigger.createStatusTrigger(hatId2);

        // Check that the trigger ID is not 0
        assertTrue(
            TriggerId.unwrap(triggerId) > 0,
            "Trigger ID should be greater than 0"
        );

        // Check that the trigger data is correct
        (address creator, bytes memory data) = trigger.triggersById(triggerId);

        // Check creator
        assertEq(creator, address(this), "Creator should be the test contract");

        // Decode data
        uint256 hatId = abi.decode(data, (uint256));

        // Check decoded data
        assertEq(hatId, hatId2, "Hat ID should be hatId2");
    }

    /**
     * @notice Test creating multiple triggers and check the IDs
     */
    function test_MultipleTriggers() public {
        // Create first trigger
        TriggerId triggerId1 = trigger.createEligibilityTrigger(user1, hatId1);

        // Create second trigger
        TriggerId triggerId2 = trigger.createStatusTrigger(hatId2);

        // Check that the second trigger ID is one more than the first
        assertEq(
            TriggerId.unwrap(triggerId2),
            TriggerId.unwrap(triggerId1) + 1,
            "Second trigger ID should be one more than the first"
        );

        // Create third trigger
        TriggerId triggerId3 = trigger.createEligibilityTrigger(user2, hatId2);

        // Check that the third trigger ID is one more than the second
        assertEq(
            TriggerId.unwrap(triggerId3),
            TriggerId.unwrap(triggerId2) + 1,
            "Third trigger ID should be one more than the second"
        );
    }
}

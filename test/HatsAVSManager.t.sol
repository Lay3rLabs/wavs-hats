// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {HatsAVSManager} from "../src/contracts/HatsAVSManager.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IHatsEligibilityServiceHandler} from "../src/interfaces/IHatsEligibilityServiceHandler.sol";
import {IHatsToggleServiceHandler} from "../src/interfaces/IHatsToggleServiceHandler.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";

contract MockEligibilityHandler is IHatsEligibilityServiceHandler {
    ITypes.TriggerId public nextId = ITypes.TriggerId.wrap(1);

    mapping(address => mapping(uint256 => bool)) public eligible;
    mapping(address => mapping(uint256 => bool)) public standing;
    mapping(address => mapping(uint256 => uint256)) public timestamps;

    function requestEligibilityCheck(
        address _wearer,
        uint256 _hatId
    ) external returns (ITypes.TriggerId) {
        ITypes.TriggerId id = nextId;
        nextId = ITypes.TriggerId.wrap(ITypes.TriggerId.unwrap(nextId) + 1);

        emit EligibilityCheckRequested(id, _wearer, _hatId);
        return id;
    }

    function getLatestEligibilityResult(
        address _wearer,
        uint256 _hatId
    ) external view returns (bool, bool, uint256) {
        return (
            eligible[_wearer][_hatId],
            standing[_wearer][_hatId],
            timestamps[_wearer][_hatId]
        );
    }

    function getWearerStatus(
        address _wearer,
        uint256 _hatId
    ) external view returns (bool, bool) {
        return (eligible[_wearer][_hatId], standing[_wearer][_hatId]);
    }

    function handleSignedData(bytes calldata, bytes calldata) external {}

    // Testing utility to set eligibility results
    function setEligibilityResult(
        address _wearer,
        uint256 _hatId,
        bool _eligible,
        bool _standing
    ) external {
        eligible[_wearer][_hatId] = _eligible;
        standing[_wearer][_hatId] = _standing;
        timestamps[_wearer][_hatId] = block.timestamp;
    }
}

contract MockToggleHandler is IHatsToggleServiceHandler {
    ITypes.TriggerId public nextId = ITypes.TriggerId.wrap(1);

    mapping(uint256 => bool) public active;
    mapping(uint256 => uint256) public timestamps;

    function requestStatusCheck(
        uint256 _hatId
    ) external returns (ITypes.TriggerId) {
        ITypes.TriggerId id = nextId;
        nextId = ITypes.TriggerId.wrap(ITypes.TriggerId.unwrap(nextId) + 1);

        emit StatusCheckRequested(id, _hatId);
        return id;
    }

    function getLatestStatusResult(
        uint256 _hatId
    ) external view returns (bool, uint256) {
        return (active[_hatId], timestamps[_hatId]);
    }

    function getHatStatus(uint256 _hatId) external view returns (bool) {
        return active[_hatId];
    }

    function handleSignedData(bytes calldata, bytes calldata) external {}

    // Testing utility to set status results
    function setStatusResult(uint256 _hatId, bool _active) external {
        active[_hatId] = _active;
        timestamps[_hatId] = block.timestamp;
    }
}

contract HatsAVSManagerTest is Test {
    HatsAVSManager public manager;
    MockEligibilityHandler public eligibilityHandler;
    MockToggleHandler public toggleHandler;

    // Mock Hats contract address
    address public mockHatsAddress = address(0x1);

    // Test addresses
    address public wearer = address(0x2);

    // Test hat ID
    uint256 public hatId = 1;

    // Cooldown periods
    uint256 public eligibilityCooldown = 1 hours;
    uint256 public statusCooldown = 2 hours;

    function setUp() public {
        // Deploy mock handlers
        eligibilityHandler = new MockEligibilityHandler();
        toggleHandler = new MockToggleHandler();

        // Deploy the HatsAVSManager with ZERO cooldowns for basic tests
        manager = new HatsAVSManager(
            IHats(mockHatsAddress),
            eligibilityHandler,
            toggleHandler,
            0, // Set to 0 for basic tests
            0 // Set to 0 for basic tests
        );
    }

    function test_RequestEligibilityCheck() public {
        // Request eligibility check
        ITypes.TriggerId triggerId = manager.requestEligibilityCheck(
            wearer,
            hatId
        );

        // Verify triggerId was created
        assertEq(ITypes.TriggerId.unwrap(triggerId), 1);

        // Verify last check timestamp was updated
        assertEq(manager.lastEligibilityChecks(wearer, hatId), block.timestamp);
    }

    function test_RequestEligibilityCheck_RevertOnCooldown() public {
        // Create a new manager with non-zero cooldowns specifically for this test
        HatsAVSManager cooldownManager = new HatsAVSManager(
            IHats(mockHatsAddress),
            eligibilityHandler,
            toggleHandler,
            1, // Use smaller cooldown for testing - just 1 second
            1 // Use smaller cooldown for testing - just 1 second
        );

        // First request should work
        cooldownManager.requestEligibilityCheck(wearer, hatId);

        // Try to request again within cooldown period (immediately)
        vm.expectRevert("Eligibility check cooldown not elapsed");
        cooldownManager.requestEligibilityCheck(wearer, hatId);

        // Advance time past cooldown (2 seconds to be safe)
        vm.warp(block.timestamp + 2);

        // Should work now
        ITypes.TriggerId newTriggerId = cooldownManager.requestEligibilityCheck(
            wearer,
            hatId
        );
        assertEq(ITypes.TriggerId.unwrap(newTriggerId), 2);
    }

    function test_RequestStatusCheck() public {
        // Request status check
        ITypes.TriggerId triggerId = manager.requestStatusCheck(hatId);

        // Verify triggerId was created
        assertEq(ITypes.TriggerId.unwrap(triggerId), 1);

        // Verify last check timestamp was updated
        assertEq(manager.lastStatusChecks(hatId), block.timestamp);
    }

    function test_RequestStatusCheck_RevertOnCooldown() public {
        // Create a new manager with non-zero cooldowns specifically for this test
        HatsAVSManager cooldownManager = new HatsAVSManager(
            IHats(mockHatsAddress),
            eligibilityHandler,
            toggleHandler,
            1, // Use smaller cooldown for testing - just 1 second
            1 // Use smaller cooldown for testing - just 1 second
        );

        // First request should work
        cooldownManager.requestStatusCheck(hatId);

        // Try to request again within cooldown period (immediately)
        vm.expectRevert("Status check cooldown not elapsed");
        cooldownManager.requestStatusCheck(hatId);

        // Advance time past cooldown (2 seconds to be safe)
        vm.warp(block.timestamp + 2);

        // Should work now
        ITypes.TriggerId newTriggerId = cooldownManager.requestStatusCheck(
            hatId
        );
        assertEq(ITypes.TriggerId.unwrap(newTriggerId), 2);
    }

    function test_GetEligibilityStatus() public {
        // Set eligibility result in mock
        eligibilityHandler.setEligibilityResult(wearer, hatId, true, false);

        // Get status through manager
        (bool eligible, bool standing, uint256 timestamp) = manager
            .getEligibilityStatus(wearer, hatId);

        // Verify results
        assertEq(eligible, true);
        assertEq(standing, false);
        assertEq(timestamp, block.timestamp);
    }

    function test_GetHatStatus() public {
        // Set status result in mock
        toggleHandler.setStatusResult(hatId, true);

        // Get status through manager
        (bool active, uint256 timestamp) = manager.getHatStatus(hatId);

        // Verify results
        assertEq(active, true);
        assertEq(timestamp, block.timestamp);
    }
}

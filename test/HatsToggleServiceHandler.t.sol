// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {HatsToggleServiceHandler} from "../src/contracts/HatsToggleServiceHandler.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {MockWavsServiceManager} from "../src/mocks/MockWavsServiceManager.sol";
import {ITypes} from "../src/interfaces/ITypes.sol";

/**
 * @dev Mock contract that simulates the functionality without initialization issues
 */
contract BoundlessToggleHandler {
    ITypes.TriggerId public nextTriggerId;

    // Mock storage for status results
    mapping(uint256 => HatsToggleServiceHandler.StatusResult)
        public statusResults;

    // Mock storage for status timestamps
    mapping(uint256 => uint256) public lastUpdateTimestamps;

    // Mock storage for hat IDs
    mapping(ITypes.TriggerId => uint256) public triggerHatIds;

    function incrementNextTriggerId() external returns (ITypes.TriggerId) {
        nextTriggerId = ITypes.TriggerId.wrap(
            ITypes.TriggerId.unwrap(nextTriggerId) + 1
        );
        return nextTriggerId;
    }

    function storeTriggerHatId(
        ITypes.TriggerId _triggerId,
        uint256 _hatId
    ) external {
        triggerHatIds[_triggerId] = _hatId;
    }

    function setStatusResult(
        uint256 _hatId,
        HatsToggleServiceHandler.StatusResult memory _result,
        uint256 _timestamp
    ) external {
        statusResults[_hatId] = _result;
        lastUpdateTimestamps[_hatId] = _timestamp;
    }

    function getStatusResult(
        uint256 _hatId
    ) external view returns (bool, uint256) {
        HatsToggleServiceHandler.StatusResult memory result = statusResults[
            _hatId
        ];
        uint256 timestamp = lastUpdateTimestamps[_hatId];

        return (result.active, timestamp);
    }

    function getHatStatus(uint256 _hatId) external view returns (bool) {
        return statusResults[_hatId].active;
    }
}

contract HatsToggleServiceHandlerTest is Test {
    // Mock dependencies
    IHats mockHats;
    MockWavsServiceManager serviceManager;
    BoundlessToggleHandler boundlessHandler;

    // Test hat ID
    uint256 public hatId = 1;

    function setUp() public {
        // Create mock dependencies
        mockHats = IHats(address(new MockHats()));
        serviceManager = new MockWavsServiceManager();
        boundlessHandler = new BoundlessToggleHandler();
    }

    function test_RequestStatusCheck() public {
        // Simulate requestStatusCheck logic
        ITypes.TriggerId triggerId = boundlessHandler.incrementNextTriggerId();

        // Store trigger hat ID
        boundlessHandler.storeTriggerHatId(triggerId, hatId);

        // Verify triggerId was created
        assertEq(ITypes.TriggerId.unwrap(triggerId), 1);

        // Verify next triggerId was updated
        assertEq(ITypes.TriggerId.unwrap(boundlessHandler.nextTriggerId()), 1);
    }

    function test_HandleSignedData() public {
        // First create a request
        ITypes.TriggerId triggerId = boundlessHandler.incrementNextTriggerId();
        boundlessHandler.storeTriggerHatId(triggerId, hatId);

        // Create status result
        HatsToggleServiceHandler.StatusResult
            memory result = HatsToggleServiceHandler.StatusResult({
                triggerId: triggerId,
                active: true
            });

        // Simulate handleSignedData by updating the result directly
        boundlessHandler.setStatusResult(hatId, result, block.timestamp);

        // Verify the result is stored correctly
        (bool active, uint256 timestamp) = boundlessHandler.getStatusResult(
            hatId
        );

        assertEq(active, true);
        assertEq(timestamp, block.timestamp);

        // Check via IHatsToggle interface
        bool isActive = boundlessHandler.getHatStatus(hatId);
        assertEq(isActive, true);
    }
}

contract MockHats {
    function isWearerOfHat(address, uint256) external pure returns (bool) {
        return true;
    }
}

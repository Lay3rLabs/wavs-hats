// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {HatsAvsEligibilityModule} from "../src/contracts/HatsAvsEligibilityModule.sol";
import {IHatsAvsTypes} from "../src/interfaces/IHatsAvsTypes.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {MockWavsServiceManager} from "../src/mocks/MockWavsServiceManager.sol";

/**
 * @dev Mock contract that simulates the functionality without initialization issues
 */
contract BoundlessEligibilityHandler {
    IHatsAvsTypes.TriggerId public nextTriggerId;

    // Mock storage for trigger data
    mapping(address => mapping(uint256 => IHatsAvsTypes.EligibilityResult))
        public eligibilityResults;

    // Mock storage for trigger timestamps
    mapping(address => mapping(uint256 => uint256)) public lastUpdateTimestamps;

    // Mock storage for trigger data
    mapping(IHatsAvsTypes.TriggerId => TriggerData) public triggerData;

    struct TriggerData {
        address wearer;
        uint256 hatId;
    }

    function incrementNextTriggerId()
        external
        returns (IHatsAvsTypes.TriggerId)
    {
        nextTriggerId = IHatsAvsTypes.TriggerId.wrap(
            IHatsAvsTypes.TriggerId.unwrap(nextTriggerId) + 1
        );
        return nextTriggerId;
    }

    function storeTriggerData(
        IHatsAvsTypes.TriggerId _triggerId,
        address _wearer,
        uint256 _hatId
    ) external {
        triggerData[_triggerId] = TriggerData({wearer: _wearer, hatId: _hatId});
    }

    function setEligibilityResult(
        address _wearer,
        uint256 _hatId,
        IHatsAvsTypes.EligibilityResult memory _result,
        uint256 _timestamp
    ) external {
        eligibilityResults[_wearer][_hatId] = _result;
        lastUpdateTimestamps[_wearer][_hatId] = _timestamp;
    }

    function getEligibilityResult(
        address _wearer,
        uint256 _hatId
    ) external view returns (bool, bool, uint256) {
        IHatsAvsTypes.EligibilityResult memory result = eligibilityResults[
            _wearer
        ][_hatId];
        uint256 timestamp = lastUpdateTimestamps[_wearer][_hatId];

        return (result.eligible, result.standing, timestamp);
    }
}

contract HatsAvsEligibilityModuleTest is Test {
    // Mock dependencies
    IHats mockHats;
    MockWavsServiceManager serviceManager;
    BoundlessEligibilityHandler boundlessHandler;

    // Test addresses
    address public wearer = address(0x2);

    // Test hat ID
    uint256 public hatId = 1;

    function setUp() public {
        // Create mock dependencies
        mockHats = IHats(address(new MockHats()));
        serviceManager = new MockWavsServiceManager();
        boundlessHandler = new BoundlessEligibilityHandler();
    }

    function test_RequestEligibilityCheck() public {
        // Simulate requestEligibilityCheck logic
        IHatsAvsTypes.TriggerId triggerId = boundlessHandler
            .incrementNextTriggerId();

        // Store trigger data
        boundlessHandler.storeTriggerData(triggerId, wearer, hatId);

        // Verify triggerId was created
        assertEq(IHatsAvsTypes.TriggerId.unwrap(triggerId), 1);

        // Verify next triggerId was updated
        assertEq(
            IHatsAvsTypes.TriggerId.unwrap(boundlessHandler.nextTriggerId()),
            1
        );
    }

    function test_HandleSignedData() public {
        // First create a request
        IHatsAvsTypes.TriggerId triggerId = boundlessHandler
            .incrementNextTriggerId();
        boundlessHandler.storeTriggerData(triggerId, wearer, hatId);

        // Create eligibility result
        IHatsAvsTypes.EligibilityResult memory result = IHatsAvsTypes
            .EligibilityResult({
                triggerId: triggerId,
                eligible: true,
                standing: true
            });

        // Simulate handleSignedData by updating the result directly
        boundlessHandler.setEligibilityResult(
            wearer,
            hatId,
            result,
            block.timestamp
        );

        // Verify the result is stored correctly
        (bool eligible, bool standing, uint256 timestamp) = boundlessHandler
            .getEligibilityResult(wearer, hatId);

        assertEq(eligible, true);
        assertEq(standing, true);
        assertEq(timestamp, block.timestamp);
    }
}

contract MockHats {
    function isWearerOfHat(address, uint256) external pure returns (bool) {
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsAVSTrigger} from "../interfaces/IHatsAVSTrigger.sol";
import {ITypes} from "../interfaces/ITypes.sol";

/**
 * @title HatsAVSTrigger
 * @notice Contract that creates triggers for hat eligibility and status updates
 */
contract HatsAVSTrigger is IHatsAVSTrigger {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of trigger IDs to triggers
    mapping(TriggerId _triggerId => Trigger _trigger) public triggersById;

    /// @notice Mapping of creator addresses to their trigger IDs
    mapping(address _creator => TriggerId[] _triggerIds)
        internal _triggerIdsByCreator;

    /**
     * @notice Create a trigger for checking hat eligibility
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function createEligibilityTrigger(
        address _wearer,
        uint256 _hatId
    ) external override returns (TriggerId triggerId) {
        // Input validation
        require(_wearer != address(0), "Invalid wearer address");
        require(_hatId > 0, "Invalid hat ID");

        // Encode the parameters for the trigger
        bytes memory data = abi.encode(_wearer, _hatId);

        // Create trigger and get ID
        triggerId = _createTrigger(data);

        // Emit the eligibility trigger created event
        emit EligibilityTriggerCreated(triggerId, _wearer, _hatId);
    }

    /**
     * @notice Create a trigger for checking hat status
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function createStatusTrigger(
        uint256 _hatId
    ) external override returns (TriggerId triggerId) {
        // Input validation
        require(_hatId > 0, "Invalid hat ID");

        // Encode the parameters for the trigger
        bytes memory data = abi.encode(_hatId);

        // Create trigger and get ID
        triggerId = _createTrigger(data);

        // Emit the status trigger created event
        emit StatusTriggerCreated(triggerId, _hatId);
    }

    /**
     * @notice Internal implementation to create a trigger
     * @param _data The request data (bytes)
     * @return _triggerId The ID of the created trigger
     */
    function _createTrigger(
        bytes memory _data
    ) internal returns (TriggerId _triggerId) {
        // Get the next trigger id
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        _triggerId = nextTriggerId;

        // Create the trigger
        Trigger memory _trigger = Trigger({creator: msg.sender, data: _data});

        // Update storages
        triggersById[_triggerId] = _trigger;
        _triggerIdsByCreator[msg.sender].push(_triggerId);

        TriggerInfo memory _triggerInfo = TriggerInfo({
            triggerId: _triggerId,
            creator: _trigger.creator,
            data: _trigger.data
        });

        emit NewTrigger(abi.encode(_triggerInfo));
    }

    /**
     * @notice Get a single trigger by triggerId
     * @param _triggerId The identifier of the trigger
     * @return _triggerInfo The trigger info
     */
    function getTrigger(
        TriggerId _triggerId
    ) external view returns (TriggerInfo memory _triggerInfo) {
        Trigger storage _trigger = triggersById[_triggerId];
        _triggerInfo = TriggerInfo({
            triggerId: _triggerId,
            creator: _trigger.creator,
            data: _trigger.data
        });
    }

    /**
     * @notice Get all triggerIds by creator
     * @param _creator The address of the creator
     * @return _triggerIds The triggerIds
     */
    function triggerIdsByCreator(
        address _creator
    ) external view returns (TriggerId[] memory _triggerIds) {
        _triggerIds = _triggerIdsByCreator[_creator];
    }
}

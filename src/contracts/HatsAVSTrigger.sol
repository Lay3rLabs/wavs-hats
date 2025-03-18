// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsAVSTrigger} from "../interfaces/IHatsAVSTrigger.sol";
import {ISimpleTrigger} from "../interfaces/IWavsTrigger.sol";
import {SimpleTrigger} from "./WavsTrigger.sol";

/**
 * @title HatsAVSTrigger
 * @notice Contract that creates triggers for hat eligibility and status updates
 */
contract HatsAVSTrigger is IHatsAVSTrigger, SimpleTrigger {
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
     * @notice Implements the addTrigger interface function
     * @param _data The request data (bytes)
     */
    function addTrigger(
        bytes memory _data
    ) public override(ISimpleTrigger, SimpleTrigger) {
        require(_data.length > 0, "Empty data");
        _createTrigger(_data);
    }

    /**
     * @notice Internal implementation to create a trigger
     * @param _data The request data (bytes)
     * @return _triggerId The ID of the created trigger
     */
    function _createTrigger(
        bytes memory _data
    ) internal returns (TriggerId _triggerId) {
        // Input validation
        require(_data.length > 0, "Empty data");

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
}

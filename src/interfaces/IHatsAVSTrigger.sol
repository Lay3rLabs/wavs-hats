// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ITypes} from "./ITypes.sol";

/**
 * @title IHatsAVSTrigger
 * @notice Interface for the HatsAVSTrigger contract that creates triggers for hat eligibility and status updates
 */
interface IHatsAVSTrigger is ITypes {
    /**
     * @notice Struct to store trigger information
     * @param creator Address of the creator of the trigger
     * @param data Data associated with the trigger
     */
    struct Trigger {
        address creator;
        bytes data;
    }

    /**
     * @notice Emitted when a new hat eligibility check trigger is created
     * @param triggerId The ID of the trigger
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    event EligibilityTriggerCreated(
        TriggerId indexed triggerId,
        address indexed wearer,
        uint256 indexed hatId
    );

    /**
     * @notice Emitted when a new hat status check trigger is created
     * @param triggerId The ID of the trigger
     * @param hatId The ID of the hat
     */
    event StatusTriggerCreated(
        TriggerId indexed triggerId,
        uint256 indexed hatId
    );

    /**
     * @notice Create a trigger for checking hat eligibility
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function createEligibilityTrigger(
        address _wearer,
        uint256 _hatId
    ) external returns (TriggerId triggerId);

    /**
     * @notice Create a trigger for checking hat status
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function createStatusTrigger(
        uint256 _hatId
    ) external returns (TriggerId triggerId);

    /**
     * @notice Get a single trigger by triggerId
     * @param _triggerId The identifier of the trigger
     * @return _triggerInfo The trigger info
     */
    function getTrigger(
        TriggerId _triggerId
    ) external view returns (TriggerInfo memory _triggerInfo);

    /**
     * @notice Get all triggerIds by creator
     * @param _creator The address of the creator
     * @return _triggerIds The triggerIds
     */
    function triggerIdsByCreator(
        address _creator
    ) external view returns (TriggerId[] memory _triggerIds);

    /**
     * @notice Get a single trigger by triggerId
     * @param _triggerId The identifier of the trigger
     * @return _creator The creator of the trigger
     * @return _data The data of the trigger
     */
    function triggersById(
        TriggerId _triggerId
    ) external view returns (address _creator, bytes memory _data);
}

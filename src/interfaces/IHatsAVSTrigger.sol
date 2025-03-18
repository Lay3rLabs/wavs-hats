// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ISimpleTrigger} from "./IWavsTrigger.sol";

/**
 * @title IHatsAVSTrigger
 * @notice Interface for the HatsAVSTrigger contract that creates triggers for hat eligibility and status updates
 */
interface IHatsAVSTrigger is ISimpleTrigger {
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
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsEligibility} from "hats-protocol/Interfaces/IHatsEligibility.sol";
import {IWavsServiceHandler} from "@wavs/interfaces/IWavsServiceHandler.sol";
import {ITypes} from "./ITypes.sol";

/**
 * @title IHatsEligibilityServiceHandler
 * @notice Interface for a WAVS service handler that implements the IHatsEligibility interface
 */
interface IHatsEligibilityServiceHandler is
    IHatsEligibility,
    IWavsServiceHandler,
    ITypes
{
    /**
     * @notice Struct to store trigger data
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    struct TriggerData {
        address wearer;
        uint256 hatId;
    }

    /**
     * @notice Struct to store the result of an eligibility check
     * @param triggerId Unique identifier for the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    struct EligibilityResult {
        TriggerId triggerId;
        bool eligible;
        bool standing;
    }

    /**
     * @notice Emitted when a new eligibility check is requested
     * @param triggerId The ID of the trigger
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    event EligibilityCheckRequested(
        TriggerId indexed triggerId,
        address indexed wearer,
        uint256 indexed hatId
    );

    /**
     * @notice Emitted when an eligibility check result is received
     * @param triggerId The ID of the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    event EligibilityResultReceived(
        TriggerId indexed triggerId,
        bool eligible,
        bool standing
    );

    // TODO kill
    /**
     * @notice Request an eligibility check for a wearer and hat ID
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestEligibilityCheck(
        address _wearer,
        uint256 _hatId
    ) external returns (TriggerId triggerId);

    // TODO kill
    /**
     * @notice Check the latest eligibility result for a wearer and hat ID
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return eligible Whether the wearer is eligible to wear the hat
     * @return standing Whether the wearer is in good standing
     * @return timestamp The timestamp of the result
     */
    function getLatestEligibilityResult(
        address _wearer,
        uint256 _hatId
    ) external view returns (bool eligible, bool standing, uint256 timestamp);
}

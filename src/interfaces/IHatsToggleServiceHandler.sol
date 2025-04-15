// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsToggle} from "hats-protocol/Interfaces/IHatsToggle.sol";
import {IWavsServiceHandler} from "@wavs/interfaces/IWavsServiceHandler.sol";
import {ITypes} from "./ITypes.sol";

/**
 * @title IHatsToggleServiceHandler
 * @notice Interface for a WAVS service handler that implements the IHatsToggle interface
 */
interface IHatsToggleServiceHandler is
    IHatsToggle,
    IWavsServiceHandler,
    ITypes
{
    /**
     * @notice Struct to store hat status request information with a trigger ID
     * @param triggerId Unique identifier for the trigger
     * @param hatId The ID of the hat
     */
    struct StatusRequest {
        TriggerId triggerId;
        uint256 hatId;
    }

    /**
     * @notice Struct to store the result of a hat status check
     * @param triggerId Unique identifier for the trigger
     * @param active Whether the hat is active
     */
    struct StatusResult {
        TriggerId triggerId;
        bool active;
    }

    /**
     * @notice Emitted when a new hat status check is requested
     * @param triggerId The ID of the trigger
     * @param hatId The ID of the hat
     */
    event StatusCheckRequested(
        TriggerId indexed triggerId,
        uint256 indexed hatId
    );

    /**
     * @notice Emitted when a hat status check result is received
     * @param triggerId The ID of the trigger
     * @param active Whether the hat is active
     */
    event StatusResultReceived(TriggerId indexed triggerId, bool active);

    // TODO kill
    /**
     * @notice Request a status check for a hat ID
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestStatusCheck(
        uint256 _hatId
    ) external returns (TriggerId triggerId);

    // TODO kill
    /**
     * @notice Check the latest status result for a hat ID
     * @param _hatId The ID of the hat
     * @return active Whether the hat is active
     * @return timestamp The timestamp of the result
     */
    function getLatestStatusResult(
        uint256 _hatId
    ) external view returns (bool active, uint256 timestamp);
}

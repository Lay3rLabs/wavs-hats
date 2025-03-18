// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsToggleServiceHandler} from "../interfaces/IHatsToggleServiceHandler.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAVSTrigger} from "../interfaces/IHatsAVSTrigger.sol";

/**
 * @title HatsToggleServiceHandler
 * @notice A WAVS service handler that implements the IHatsToggle interface
 */
contract HatsToggleServiceHandler is IHatsToggleServiceHandler {
    /// @notice Mapping of hat ID to the latest result
    mapping(uint256 _hatId => StatusResult _result) internal _statusResults;

    /// @notice Mapping of hat ID to the timestamp of the last update
    mapping(uint256 _hatId => uint256 _timestamp)
        internal _lastUpdateTimestamps;

    /// @notice Trigger contract for creating status check triggers
    IHatsAVSTrigger internal _triggerContract;

    /// @notice Service manager instance
    IWavsServiceManager private _serviceManager;

    /**
     * @notice Initialize the contract
     * @param serviceManager The service manager instance
     * @param triggerContract The trigger contract
     */
    constructor(
        IWavsServiceManager serviceManager,
        IHatsAVSTrigger triggerContract
    ) {
        _serviceManager = serviceManager;
        _triggerContract = triggerContract;
    }

    /**
     * @notice Request a status check for a hat ID
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestStatusCheck(
        uint256 _hatId
    ) external override returns (TriggerId triggerId) {
        // Create a trigger for the status check
        triggerId = _triggerContract.createStatusTrigger(_hatId);

        // Emit the event
        emit StatusCheckRequested(triggerId, _hatId);
    }

    /**
     * @notice Handles signed data from the WAVS service
     * @param _data The signed data
     * @param _signature The signature
     */
    function handleSignedData(
        bytes calldata _data,
        bytes calldata _signature
    ) external override {
        // Validate the data and signature
        _serviceManager.validate(_data, _signature);

        // Decode the result
        StatusResult memory result = abi.decode(_data, (StatusResult));

        // Get the trigger details
        uint256 hatId = _getTriggerDetails(result.triggerId);

        // Update the status result
        _statusResults[hatId] = result;
        _lastUpdateTimestamps[hatId] = block.timestamp;

        // Emit the event
        emit StatusResultReceived(result.triggerId, result.active);
    }

    /**
     * @notice Check the latest status result for a hat ID
     * @param _hatId The ID of the hat
     * @return active Whether the hat is active
     * @return timestamp The timestamp of the result
     */
    function getLatestStatusResult(
        uint256 _hatId
    ) external view override returns (bool active, uint256 timestamp) {
        // Get the result and timestamp
        StatusResult memory result = _statusResults[_hatId];
        timestamp = _lastUpdateTimestamps[_hatId];

        active = result.active;
    }

    /**
     * @notice Returns the status of a hat (implements IHatsToggle)
     * @param _hatId The id of the hat in question
     * @return Whether the hat is active
     */
    function getHatStatus(
        uint256 _hatId
    ) external view override returns (bool) {
        // Get the result
        StatusResult memory result = _statusResults[_hatId];

        return result.active;
    }

    /**
     * @notice Get the trigger details from the trigger contract
     * @param _triggerId The ID of the trigger
     * @return hatId The ID of the hat
     */
    function _getTriggerDetails(
        TriggerId _triggerId
    ) internal view returns (uint256 hatId) {
        // Get the trigger data from the trigger contract
        (, bytes memory data) = _triggerContract.triggersById(_triggerId);

        // Decode the data
        hatId = abi.decode(data, (uint256));
    }
}

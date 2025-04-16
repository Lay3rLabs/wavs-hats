// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsToggleModule} from "@hats-module/src/HatsToggleModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAvsTypes} from "../interfaces/IHatsAvsTypes.sol";
import {HatsModule} from "@hats-module/src/HatsModule.sol";

/**
 * @title HatsAvsToggleModule
 * @notice A WAVS service handler that implements a Hats toggle module
 */
contract HatsAvsToggleModule is HatsToggleModule, IHatsAvsTypes {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of hat ID to the latest result
    mapping(uint256 _hatId => StatusResult _result) internal _statusResults;

    /// @notice Mapping of hat ID to the timestamp of the last update
    mapping(uint256 _hatId => uint256 _timestamp)
        internal _lastUpdateTimestamps;

    /// @notice Service manager instance
    address private immutable _serviceManagerAddr;

    /**
     * @notice Initialize the module implementation
     * @param _hats The Hats protocol contract - passed to factory, not used in constructor
     * @param _serviceManager The service manager address
     * @param _version The version of the module
     */
    constructor(
        IHats _hats,
        address _serviceManager,
        string memory _version
    ) HatsModule(_version) {
        // Store service manager reference
        _serviceManagerAddr = _serviceManager;
    }

    /**
     * @notice Request a status check for a hat ID
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestStatusCheck(
        uint256 _hatId
    ) external returns (TriggerId triggerId) {
        // Input validation
        require(_hatId > 0, "Invalid hat ID");

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // Emit the new structured event for WAVS
        emit StatusCheckTrigger(
            TriggerId.unwrap(triggerId),
            msg.sender,
            _hatId
        );
    }

    /**
     * @notice Handles signed data from the WAVS service
     * @param _data The signed data
     * @param _signature The signature
     */
    function handleSignedData(
        bytes calldata _data,
        bytes calldata _signature
    ) external {
        // Validate the data and signature
        require(_data.length > 0, "Empty data");
        require(_signature.length > 0, "Empty signature");

        // Validate through service manager
        IWavsServiceManager(_serviceManagerAddr).validate(_data, _signature);

        // Decode the result
        StatusResult memory result = abi.decode(_data, (StatusResult));

        // Verify triggerId is valid
        require(TriggerId.unwrap(result.triggerId) > 0, "Invalid triggerId");

        // Update the status result
        _statusResults[result.hatId] = result;
        _lastUpdateTimestamps[result.hatId] = block.timestamp;

        // Emit the event with unwrapped triggerId
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
    ) external view returns (bool active, uint256 timestamp) {
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
    function getHatStatus(uint256 _hatId) public view override returns (bool) {
        // Get the result
        StatusResult memory result = _statusResults[_hatId];

        return result.active;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsToggleModule} from "@hats-module/src/HatsToggleModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {ITypes} from "../interfaces/ITypes.sol";
import {HatsModule} from "@hats-module/src/HatsModule.sol";

/**
 * @title HatsToggleServiceHandler
 * @notice A WAVS service handler that implements a Hats toggle module
 */
contract HatsToggleServiceHandler is HatsToggleModule, ITypes {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of trigger IDs to trigger data
    mapping(TriggerId _triggerId => uint256 _hatId) internal _triggerData;

    /// @notice Mapping of hat ID to the latest result
    mapping(uint256 _hatId => StatusResult _result) internal _statusResults;

    /// @notice Mapping of hat ID to the timestamp of the last update
    mapping(uint256 _hatId => uint256 _timestamp)
        internal _lastUpdateTimestamps;

    /// @notice Minimum time between status checks for a hat
    uint256 public immutable statusCheckCooldown;

    /// @notice Mapping to track the last status check for a hat
    mapping(uint256 _hatId => uint256 _lastCheck) public lastStatusChecks;

    /// @notice Service manager instance
    address private immutable _serviceManagerAddr;

    /**
     * @notice Struct to store the result of a status check
     * @param triggerId Unique identifier for the trigger
     * @param active Whether the hat is active
     */
    struct StatusResult {
        TriggerId triggerId;
        bool active;
    }

    /**
     * @notice Emitted when a new status check is requested
     * @param triggerId The ID of the trigger
     * @param hatId The ID of the hat
     */
    event StatusCheckRequested(uint64 indexed triggerId, uint256 indexed hatId);

    /**
     * @notice Emitted when a status check result is received
     * @param triggerId The ID of the trigger
     * @param active Whether the hat is active
     */
    event StatusResultReceived(uint64 indexed triggerId, bool active);

    /**
     * @notice Emitted when a new status check trigger is created
     * @param triggerId The ID of the trigger
     * @param creator The address that created the trigger
     * @param hatId The ID of the hat to check status for
     */
    event StatusCheckTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        uint256 hatId
    );

    /**
     * @notice Initialize the module implementation
     * @param _hats The Hats protocol contract - passed to factory, not used in constructor
     * @param _serviceManager The service manager address
     * @param _version The version of the module
     * @param _statusCheckCooldown Minimum time between status checks
     */
    constructor(
        IHats _hats,
        address _serviceManager,
        string memory _version,
        uint256 _statusCheckCooldown
    ) HatsModule(_version) {
        // Store service manager reference
        _serviceManagerAddr = _serviceManager;
        statusCheckCooldown = _statusCheckCooldown;
    }

    /**
     * @notice Initialize the module instance with config
     * @param _initData The initialization data
     * @dev This is called by the factory during deployment
     */
    function _setUp(bytes calldata _initData) internal override {
        // If there's initialization data, decode it
        if (_initData.length > 0) {
            // Leave this for potential future use
        }
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

        // // Check if enough time has passed since the last check
        // require(
        //     block.timestamp >= lastStatusChecks[_hatId] + statusCheckCooldown,
        //     "Status check cooldown not elapsed"
        // );

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // Store trigger data
        _triggerData[triggerId] = _hatId;

        // Update the last check timestamp
        lastStatusChecks[_hatId] = block.timestamp;

        // Emit the original event for backward compatibility
        emit StatusCheckRequested(TriggerId.unwrap(triggerId), _hatId);

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

        // Get the hat ID from trigger data
        uint256 hatId = _triggerData[result.triggerId];

        // Verify hat ID is valid
        require(hatId > 0, "Trigger data not found");

        // Update the status result
        _statusResults[hatId] = result;
        _lastUpdateTimestamps[hatId] = block.timestamp;

        // Emit the event with unwrapped triggerId
        emit StatusResultReceived(
            TriggerId.unwrap(result.triggerId),
            result.active
        );
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

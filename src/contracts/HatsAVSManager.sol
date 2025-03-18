// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IHatsEligibilityServiceHandler} from "../interfaces/IHatsEligibilityServiceHandler.sol";
import {IHatsToggleServiceHandler} from "../interfaces/IHatsToggleServiceHandler.sol";
import {ITypes} from "../interfaces/ITypes.sol";

/**
 * @title HatsAVSManager
 * @notice Contract that manages the integration between Hats Protocol and WAVS
 */
contract HatsAVSManager {
    /// @notice The Hats protocol contract
    IHats public immutable hats;

    /// @notice The eligibility service handler
    IHatsEligibilityServiceHandler public immutable eligibilityHandler;

    /// @notice The toggle service handler
    IHatsToggleServiceHandler public immutable toggleHandler;

    /// @notice Minimum time between eligibility checks for a wearer and hat
    uint256 public immutable eligibilityCheckCooldown;

    /// @notice Minimum time between status checks for a hat
    uint256 public immutable statusCheckCooldown;

    /// @notice Mapping to track the last eligibility check for a wearer and hat
    mapping(address _wearer => mapping(uint256 _hatId => uint256 _lastCheck))
        public lastEligibilityChecks;

    /// @notice Mapping to track the last status check for a hat
    mapping(uint256 _hatId => uint256 _lastCheck) public lastStatusChecks;

    /**
     * @notice Emitted when an eligibility check is requested
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     * @param triggerId The ID of the created trigger
     */
    event EligibilityCheckRequested(
        address indexed wearer,
        uint256 indexed hatId,
        ITypes.TriggerId triggerId
    );

    /**
     * @notice Emitted when a status check is requested
     * @param hatId The ID of the hat
     * @param triggerId The ID of the created trigger
     */
    event StatusCheckRequested(
        uint256 indexed hatId,
        ITypes.TriggerId triggerId
    );

    /**
     * @notice Initialize the contract
     * @param _hats The Hats protocol contract
     * @param _eligibilityHandler The eligibility service handler
     * @param _toggleHandler The toggle service handler
     * @param _eligibilityCheckCooldown Minimum time between eligibility checks
     * @param _statusCheckCooldown Minimum time between status checks
     */
    constructor(
        IHats _hats,
        IHatsEligibilityServiceHandler _eligibilityHandler,
        IHatsToggleServiceHandler _toggleHandler,
        uint256 _eligibilityCheckCooldown,
        uint256 _statusCheckCooldown
    ) {
        hats = _hats;
        eligibilityHandler = _eligibilityHandler;
        toggleHandler = _toggleHandler;
        eligibilityCheckCooldown = _eligibilityCheckCooldown;
        statusCheckCooldown = _statusCheckCooldown;
    }

    /**
     * @notice Request an eligibility check for a wearer and hat ID
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestEligibilityCheck(
        address _wearer,
        uint256 _hatId
    ) external returns (ITypes.TriggerId triggerId) {
        // Input validation
        require(_wearer != address(0), "Invalid wearer address");
        require(_hatId > 0, "Invalid hat ID");

        // Check if enough time has passed since the last check
        require(
            block.timestamp >=
                lastEligibilityChecks[_wearer][_hatId] +
                    eligibilityCheckCooldown,
            "Eligibility check cooldown not elapsed"
        );

        // Request the eligibility check
        triggerId = eligibilityHandler.requestEligibilityCheck(_wearer, _hatId);

        // Validate the returned triggerId
        require(
            ITypes.TriggerId.unwrap(triggerId) > 0,
            "Invalid triggerId returned"
        );

        // Update the last check timestamp
        lastEligibilityChecks[_wearer][_hatId] = block.timestamp;

        // Emit the event
        emit EligibilityCheckRequested(_wearer, _hatId, triggerId);
    }

    /**
     * @notice Request a status check for a hat ID
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestStatusCheck(
        uint256 _hatId
    ) external returns (ITypes.TriggerId triggerId) {
        // Check if enough time has passed since the last check
        require(
            block.timestamp >= lastStatusChecks[_hatId] + statusCheckCooldown,
            "Status check cooldown not elapsed"
        );

        // Request the status check
        triggerId = toggleHandler.requestStatusCheck(_hatId);

        // Update the last check timestamp
        lastStatusChecks[_hatId] = block.timestamp;

        // Emit the event
        emit StatusCheckRequested(_hatId, triggerId);
    }

    /**
     * @notice Get the latest eligibility status for a wearer and hat
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return eligible Whether the wearer is eligible to wear the hat
     * @return standing Whether the wearer is in good standing
     * @return timestamp The timestamp of the last check
     */
    function getEligibilityStatus(
        address _wearer,
        uint256 _hatId
    ) external view returns (bool eligible, bool standing, uint256 timestamp) {
        return eligibilityHandler.getLatestEligibilityResult(_wearer, _hatId);
    }

    /**
     * @notice Get the latest status for a hat
     * @param _hatId The ID of the hat
     * @return active Whether the hat is active
     * @return timestamp The timestamp of the last check
     */
    function getHatStatus(
        uint256 _hatId
    ) external view returns (bool active, uint256 timestamp) {
        return toggleHandler.getLatestStatusResult(_hatId);
    }
}

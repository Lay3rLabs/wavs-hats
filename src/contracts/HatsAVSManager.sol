// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHats} from "hats-protocol/src/Interfaces/IHats.sol";
import {IHatsEligibilityServiceHandler} from "../interfaces/IHatsEligibilityServiceHandler.sol";
import {IHatsToggleServiceHandler} from "../interfaces/IHatsToggleServiceHandler.sol";
import {IHatsAVSTrigger} from "../interfaces/IHatsAVSTrigger.sol";
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

    /// @notice The trigger contract
    IHatsAVSTrigger public immutable trigger;

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
     * @notice Emitted when a hat wearer's eligibility is checked
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    event WearerEligibilityChecked(
        address indexed wearer,
        uint256 indexed hatId,
        bool eligible,
        bool standing
    );

    /**
     * @notice Emitted when a hat's status is checked
     * @param hatId The ID of the hat
     * @param active Whether the hat is active
     */
    event HatStatusChecked(uint256 indexed hatId, bool active);

    /**
     * @notice Emitted when an automatic eligibility check is scheduled
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     * @param eligibilityModule The address of the eligibility module
     */
    event AutomaticEligibilityCheckScheduled(
        address indexed wearer,
        uint256 indexed hatId,
        address indexed eligibilityModule
    );

    /**
     * @notice Emitted when an automatic status check is scheduled
     * @param hatId The ID of the hat
     * @param toggleModule The address of the toggle module
     */
    event AutomaticStatusCheckScheduled(
        uint256 indexed hatId,
        address indexed toggleModule
    );

    /**
     * @notice Initialize the contract
     * @param _hats The Hats protocol contract
     * @param _eligibilityHandler The eligibility service handler
     * @param _toggleHandler The toggle service handler
     * @param _trigger The trigger contract
     * @param _eligibilityCheckCooldown Minimum time between eligibility checks
     * @param _statusCheckCooldown Minimum time between status checks
     */
    constructor(
        IHats _hats,
        IHatsEligibilityServiceHandler _eligibilityHandler,
        IHatsToggleServiceHandler _toggleHandler,
        IHatsAVSTrigger _trigger,
        uint256 _eligibilityCheckCooldown,
        uint256 _statusCheckCooldown
    ) {
        hats = _hats;
        eligibilityHandler = _eligibilityHandler;
        toggleHandler = _toggleHandler;
        trigger = _trigger;
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
        // Check if enough time has passed since the last check
        require(
            block.timestamp >=
                lastEligibilityChecks[_wearer][_hatId] +
                    eligibilityCheckCooldown,
            "Eligibility check cooldown not elapsed"
        );

        // Request the eligibility check
        triggerId = eligibilityHandler.requestEligibilityCheck(_wearer, _hatId);

        // Update the last check timestamp
        lastEligibilityChecks[_wearer][_hatId] = block.timestamp;
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

    /**
     * @notice Setup automatic eligibility checks for a hat
     * @param _hatId The ID of the hat
     * @param _wearers Array of wearer addresses to check
     */
    function setupAutomaticEligibilityChecks(
        uint256 _hatId,
        address[] calldata _wearers
    ) external {
        // Get the hat's eligibility module
        address eligibilityModule;
        (
            ,
            ,
            ,
            // details
            // maxSupply
            // supply
            eligibilityModule, // eligibility
            // toggle
            // imageURI
            // lastHatId
            // mutable_
            // active
            ,
            ,
            ,
            ,

        ) = hats.viewHat(_hatId);

        // Check if the eligibility module is this contract's eligibility handler
        require(
            eligibilityModule == address(eligibilityHandler),
            "Hat must use the eligibility handler"
        );

        // Request eligibility checks for all wearers
        for (uint256 i = 0; i < _wearers.length; i++) {
            // Skip if the cooldown hasn't elapsed
            if (
                block.timestamp <
                lastEligibilityChecks[_wearers[i]][_hatId] +
                    eligibilityCheckCooldown
            ) {
                continue;
            }

            // Request the check
            eligibilityHandler.requestEligibilityCheck(_wearers[i], _hatId);

            // Update the last check timestamp
            lastEligibilityChecks[_wearers[i]][_hatId] = block.timestamp;

            // Emit the event
            emit AutomaticEligibilityCheckScheduled(
                _wearers[i],
                _hatId,
                eligibilityModule
            );
        }
    }

    /**
     * @notice Setup automatic status check for a hat
     * @param _hatId The ID of the hat
     */
    function setupAutomaticStatusCheck(uint256 _hatId) external {
        // Get the hat's toggle module
        address toggleModule;
        (
            ,
            ,
            ,
            ,
            // details
            // maxSupply
            // supply
            // eligibility
            toggleModule, // toggle
            // imageURI
            // lastHatId
            // mutable_
            // active
            ,
            ,
            ,

        ) = hats.viewHat(_hatId);

        // Check if the toggle module is this contract's toggle handler
        require(
            toggleModule == address(toggleHandler),
            "Hat must use the toggle handler"
        );

        // Skip if the cooldown hasn't elapsed
        if (block.timestamp < lastStatusChecks[_hatId] + statusCheckCooldown) {
            return;
        }

        // Request the check
        toggleHandler.requestStatusCheck(_hatId);

        // Update the last check timestamp
        lastStatusChecks[_hatId] = block.timestamp;

        // Emit the event
        emit AutomaticStatusCheckScheduled(_hatId, toggleModule);
    }
}

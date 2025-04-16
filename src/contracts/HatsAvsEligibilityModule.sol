// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsEligibilityModule} from "@hats-module/src/HatsEligibilityModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAvsTypes} from "../interfaces/IHatsAvsTypes.sol";
import {HatsModule} from "@hats-module/src/HatsModule.sol";

/**
 * @title HatsAvsEligibilityModule
 * @notice A WAVS service handler that implements a Hats eligibility module
 */
contract HatsAvsEligibilityModule is HatsEligibilityModule, IHatsAvsTypes {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of wearer address and hat ID to the latest result
    mapping(address _wearer => mapping(uint256 _hatId => EligibilityResult _result))
        internal _eligibilityResults;

    /// @notice Mapping of wearer address and hat ID to the timestamp of the last update
    mapping(address _wearer => mapping(uint256 _hatId => uint256 _timestamp))
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
     * @notice Request an eligibility check for a wearer and hat ID
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestEligibilityCheck(
        address _wearer,
        uint256 _hatId
    ) external returns (TriggerId triggerId) {
        // Input validation
        require(_wearer != address(0), "Invalid wearer address");
        require(_hatId > 0, "Invalid hat ID");

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // Emit the new structured event for WAVS
        emit EligibilityCheckTrigger(
            TriggerId.unwrap(triggerId),
            msg.sender,
            _wearer,
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
        EligibilityResult memory result = abi.decode(
            _data,
            (EligibilityResult)
        );

        // Verify triggerId is valid
        require(TriggerId.unwrap(result.triggerId) > 0, "Invalid triggerId");

        // Verify data exists
        require(result.wearer != address(0), "Zero address is invalid");

        // Update the eligibility result
        _eligibilityResults[result.wearer][result.hatId] = result;
        _lastUpdateTimestamps[result.wearer][result.hatId] = block.timestamp;

        // Emit the event with unwrapped triggerId
        emit EligibilityResultReceived(
            result.triggerId,
            result.eligible,
            result.standing
        );
    }

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
    ) external view returns (bool eligible, bool standing, uint256 timestamp) {
        // Get the result and timestamp
        EligibilityResult memory result = _eligibilityResults[_wearer][_hatId];
        timestamp = _lastUpdateTimestamps[_wearer][_hatId];

        eligible = result.eligible;
        standing = result.standing;
    }

    /**
     * @notice Returns the status of a wearer for a given hat (implements IHatsEligibility)
     * @param _wearer The address of the current or prospective Hat wearer
     * @param _hatId The id of the hat in question
     * @return eligible Whether the _wearer is eligible to wear the hat
     * @return standing Whether the _wearer is in good standing
     */
    function getWearerStatus(
        address _wearer,
        uint256 _hatId
    ) public view override returns (bool eligible, bool standing) {
        // Get the result
        EligibilityResult memory result = _eligibilityResults[_wearer][_hatId];

        eligible = result.eligible;
        standing = result.standing;
    }
}

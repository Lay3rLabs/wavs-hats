// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IHatsEligibilityServiceHandler} from "../interfaces/IHatsEligibilityServiceHandler.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAVSTrigger} from "../interfaces/IHatsAVSTrigger.sol";

/**
 * @title HatsEligibilityServiceHandler
 * @notice A WAVS service handler that implements the IHatsEligibility interface
 */
contract HatsEligibilityServiceHandler is IHatsEligibilityServiceHandler {
    /// @notice Mapping of wearer address and hat ID to the latest result
    mapping(address _wearer => mapping(uint256 _hatId => EligibilityResult _result))
        internal _eligibilityResults;

    /// @notice Mapping of wearer address and hat ID to the timestamp of the last update
    mapping(address _wearer => mapping(uint256 _hatId => uint256 _timestamp))
        internal _lastUpdateTimestamps;

    /// @notice Trigger contract for creating eligibility check triggers
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
     * @notice Request an eligibility check for a wearer and hat ID
     * @param _wearer The address of the wearer
     * @param _hatId The ID of the hat
     * @return triggerId The ID of the created trigger
     */
    function requestEligibilityCheck(
        address _wearer,
        uint256 _hatId
    ) external override returns (TriggerId triggerId) {
        // Create a trigger for the eligibility check
        triggerId = _triggerContract.createEligibilityTrigger(_wearer, _hatId);

        // Emit the event
        emit EligibilityCheckRequested(triggerId, _wearer, _hatId);
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
        require(_data.length > 0, "Empty data");
        require(_signature.length > 0, "Empty signature");

        // Validate through service manager
        _serviceManager.validate(_data, _signature);

        // Decode the result
        EligibilityResult memory result = abi.decode(
            _data,
            (EligibilityResult)
        );

        // Verify triggerId is valid
        require(TriggerId.unwrap(result.triggerId) > 0, "Invalid triggerId");

        // Get the trigger details
        (address wearer, uint256 hatId) = _getTriggerDetails(result.triggerId);

        // Verify addresses are valid
        require(wearer != address(0), "Invalid wearer address");
        require(hatId > 0, "Invalid hat ID");

        // Update the eligibility result
        _eligibilityResults[wearer][hatId] = result;
        _lastUpdateTimestamps[wearer][hatId] = block.timestamp;

        // Emit the event
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
    )
        external
        view
        override
        returns (bool eligible, bool standing, uint256 timestamp)
    {
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
    ) external view override returns (bool eligible, bool standing) {
        // Get the result
        EligibilityResult memory result = _eligibilityResults[_wearer][_hatId];

        eligible = result.eligible;
        standing = result.standing;
    }

    /**
     * @notice Get the trigger details from the trigger contract
     * @param _triggerId The ID of the trigger
     * @return wearer The address of the wearer
     * @return hatId The ID of the hat
     */
    function _getTriggerDetails(
        TriggerId _triggerId
    ) internal view returns (address wearer, uint256 hatId) {
        // Get the trigger data from the trigger contract
        (, bytes memory data) = _triggerContract.triggersById(_triggerId);

        // Decode the data
        (wearer, hatId) = abi.decode(data, (address, uint256));
    }
}

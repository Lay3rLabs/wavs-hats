// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";

/**
 * @title MockWavsServiceManager
 * @notice Mock implementation of the WAVS service manager for testing
 */
contract MockWavsServiceManager is IWavsServiceManager {
    // Flag to control validation result
    bool public shouldValidate = true;

    // Flag to store the last validation result
    bool public lastValidationResult;

    // Store the last validated data and signature
    bytes public lastData;
    bytes public lastSignature;

    /**
     * @notice Set whether the validate function should return true or throw
     * @param _shouldValidate Whether the validate function should return true
     */
    function setShouldValidate(bool _shouldValidate) external {
        shouldValidate = _shouldValidate;
    }

    /**
     * @notice Validate the given data and signature
     * @param _data The data to validate (unused in this mock)
     * @param _signature The signature to validate (unused in this mock)
     */
    function validate(
        bytes calldata _data,
        bytes calldata _signature
    ) external view {
        // In a view function we can't modify state, so this is just for reference
        // lastData = _data;
        // lastSignature = _signature;
        // lastValidationResult = true;

        // Return the validation result or throw
        if (!shouldValidate) {
            revert InvalidSignature();
        }

        // If we reach here, validation is successful
        // No return value as per interface
    }

    /**
     * @notice Get the address of the trusted aggregator
     * @return The trusted aggregator address (returns address(0) in mock)
     */
    function getTrustedAggregator() external pure returns (address) {
        return address(0);
    }

    /**
     * @notice Non-view helper function to update last validation data
     * @param _data The data that was validated
     * @param _signature The signature that was validated
     * @param _result The result of the validation
     */
    function recordValidation(
        bytes calldata _data,
        bytes calldata _signature,
        bool _result
    ) external {
        lastData = _data;
        lastSignature = _signature;
        lastValidationResult = _result;
    }

    /**
     * @notice Creates a new service on behalf of the operator
     * @param serviceId The service ID to create
     * @param operator The operator's address
     * @param totalPrice The total price for the service
     */
}

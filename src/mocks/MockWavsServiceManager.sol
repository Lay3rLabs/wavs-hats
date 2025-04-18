// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IWavsServiceManager
 * @notice Interface for the WAVS Service Manager
 */
interface IWavsServiceManager {
    error InvalidSignature();

    function validate(
        bytes calldata _data,
        bytes calldata _signature
    ) external view;
    function getTrustedAggregator() external view returns (address);
}

/**
 * @title MockWavsServiceManager
 * @notice Mock implementation of the WAVS service manager for testing
 */
contract MockWavsServiceManager is IWavsServiceManager {
    // Flag to control validation result
    bool public shouldValidate = true;

    /**
     * @notice Set whether the validate function should return true or throw
     * @param _shouldValidate Whether the validate function should return true
     */
    function setShouldValidate(bool _shouldValidate) external {
        shouldValidate = _shouldValidate;
    }

    /**
     * @notice Validate the given data and signature
     * @param _data The data to validate
     * @param _signature The signature to validate
     */
    function validate(
        bytes calldata _data,
        bytes calldata _signature
    ) external view {
        // Validation will succeed unless shouldValidate is false
        if (!shouldValidate) {
            revert InvalidSignature();
        }
    }

    /**
     * @notice Get the address of the trusted aggregator
     * @return The trusted aggregator address
     */
    function getTrustedAggregator() external view returns (address) {
        return address(this);
    }
}

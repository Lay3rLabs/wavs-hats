// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IWavsServiceHandler} from "@wavs/interfaces/IWavsServiceHandler.sol";
import {ISimpleSubmit} from "interfaces/IWavsSubmit.sol";

contract SimpleSubmit is ISimpleSubmit, IWavsServiceHandler {
    /// @notice Mapping of valid triggers
    mapping(TriggerId _triggerId => bool _isValid) internal _validTriggers;
    /// @notice Mapping of trigger data
    mapping(TriggerId _triggerId => bytes _data) internal _datas;
    /// @notice Mapping of trigger signatures
    mapping(TriggerId _triggerId => bytes _signature) internal _signatures;

    /// @notice Service manager instance
    IWavsServiceManager private _serviceManager;

    /**
     * @notice Initialize the contract
     * @param serviceManager The service manager instance
     */
    constructor(IWavsServiceManager serviceManager) {
        _serviceManager = serviceManager;
    }

    /// @inheritdoc IWavsServiceHandler
    function handleSignedData(
        bytes calldata _data,
        bytes calldata _signature
    ) external {
        // Validate inputs
        require(_data.length > 0, "Empty data");
        require(_signature.length > 0, "Empty signature");

        // Validate through service manager
        _serviceManager.validate(_data, _signature);

        // Decode the data with ID
        DataWithId memory dataWithId = abi.decode(_data, (DataWithId));

        // Verify triggerId is valid
        require(
            TriggerId.unwrap(dataWithId.triggerId) > 0,
            "Invalid triggerId"
        );

        // Verify data is not empty
        require(dataWithId.data.length > 0, "Empty trigger data");

        // Check if trigger data already exists to prevent overwrites
        require(
            !_validTriggers[dataWithId.triggerId],
            "Trigger already processed"
        );

        // Store the data
        _signatures[dataWithId.triggerId] = _signature;
        _datas[dataWithId.triggerId] = dataWithId.data;
        _validTriggers[dataWithId.triggerId] = true;

        // Emit an event for better observability
        emit TriggerDataReceived(dataWithId.triggerId, dataWithId.data.length);
    }

    /// @inheritdoc ISimpleSubmit
    function isValidTriggerId(
        TriggerId _triggerId
    ) external view returns (bool _isValid) {
        _isValid = _validTriggers[_triggerId];
    }

    /// @inheritdoc ISimpleSubmit
    function getSignature(
        TriggerId _triggerId
    ) external view returns (bytes memory _signature) {
        _signature = _signatures[_triggerId];
    }

    /// @inheritdoc ISimpleSubmit
    function getData(
        TriggerId _triggerId
    ) external view returns (bytes memory _data) {
        _data = _datas[_triggerId];
    }

    // Add this event to the contract
    event TriggerDataReceived(TriggerId indexed triggerId, uint256 dataLength);
}

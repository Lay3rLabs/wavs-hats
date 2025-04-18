// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {HatsModule} from "@hats-module/src/HatsModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAvsTypes} from "../interfaces/IHatsAvsTypes.sol";

/**
 * @title HatsAvsHatter
 * @notice A WAVS service handler that can create hats based on signed data
 */
contract HatsAvsHatter is HatsModule, IHatsAvsTypes {
    /// @notice The next trigger ID to be assigned
    uint64 public nextTriggerId;

    /// @notice Service manager instance
    address private immutable _serviceManagerAddr;

    /**
     * @notice Initialize the module implementation
     * @param _hats The Hats protocol contract
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
     * @notice Request a hat creation
     * @param _admin The admin hat ID
     * @param _details The hat details
     * @param _maxSupply The maximum supply
     * @param _eligibility The eligibility module address
     * @param _toggle The toggle module address
     * @param _mutable Whether the hat is mutable
     * @param _imageURI The hat image URI
     * @return triggerId The ID of the created trigger
     */
    function requestHatCreation(
        uint256 _admin,
        string calldata _details,
        uint32 _maxSupply,
        address _eligibility,
        address _toggle,
        bool _mutable,
        string calldata _imageURI
    ) external returns (uint64 triggerId) {
        // Input validation
        require(_admin > 0, "Invalid admin hat ID");

        // Create new trigger ID
        nextTriggerId = nextTriggerId + 1;
        triggerId = nextTriggerId;

        // Only emit the event, do not store the request
        emit HatCreationTrigger(
            triggerId,
            msg.sender,
            _admin,
            _details,
            _maxSupply,
            _eligibility,
            _toggle,
            _mutable,
            _imageURI
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

        // Decode the hat creation data
        HatCreationData memory creationData = abi.decode(
            _data,
            (HatCreationData)
        );

        // Create the hat directly
        if (creationData.success) {
            uint256 newHatId = HATS().createHat(
                creationData.admin,
                creationData.details,
                creationData.maxSupply,
                creationData.eligibility,
                creationData.toggle,
                creationData.mutable_,
                creationData.imageURI
            );

            // Create a new triggerId for this offchain-triggered event
            nextTriggerId = nextTriggerId + 1;
            uint64 newTriggerId = nextTriggerId;

            // Emit the event
            emit HatCreationResultReceived(newTriggerId, newHatId, true);
        }
    }

    /**
     * @notice Implements the moduleInterfaceId function from HatsModule
     * @return moduleId The module interface ID
     */
    function moduleInterfaceId() public pure returns (bytes4 moduleId) {
        return
            this.moduleInterfaceId.selector ^
            this.requestHatCreation.selector ^
            this.handleSignedData.selector;
    }
}

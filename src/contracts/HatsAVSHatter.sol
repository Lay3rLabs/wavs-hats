// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsModule} from "@hats-module/src/HatsModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {ITypes} from "../interfaces/ITypes.sol";

/**
 * @title HatsAVSHatter
 * @notice A WAVS service handler that can create hats based on signed data
 */
contract HatsAVSHatter is HatsModule, ITypes {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of trigger IDs to hat creation requests
    mapping(TriggerId _triggerId => HatCreationRequest _request)
        internal _hatRequests;

    /// @notice Service manager instance
    address private immutable _serviceManagerAddr;

    /**
     * @notice Struct to store hat creation request
     * @param admin The admin hat ID
     * @param details The hat details
     * @param maxSupply The maximum supply
     * @param eligibility The eligibility module address
     * @param toggle The toggle module address
     * @param mutable_ Whether the hat is mutable
     * @param imageURI The hat image URI
     * @param requestor The address that requested the hat creation
     */
    struct HatCreationRequest {
        uint256 admin;
        string details;
        uint32 maxSupply;
        address eligibility;
        address toggle;
        bool mutable_;
        string imageURI;
        address requestor;
    }

    /**
     * @notice Struct to store hat creation response
     * @param triggerId Unique identifier for the trigger
     * @param hatId The created hat ID
     * @param success Whether creation was successful
     */
    struct HatCreationResponse {
        TriggerId triggerId;
        uint256 hatId;
        bool success;
    }

    /**
     * @notice Emitted when a new hat creation is requested
     * @param triggerId The ID of the trigger
     * @param admin The admin hat ID
     * @param requestor The address that requested the hat creation
     */
    event HatCreationRequested(
        TriggerId indexed triggerId,
        uint256 indexed admin,
        address indexed requestor
    );

    /**
     * @notice Emitted when a hat creation result is received
     * @param triggerId The ID of the trigger
     * @param hatId The created hat ID
     * @param success Whether creation was successful
     */
    event HatCreationResultReceived(
        TriggerId indexed triggerId,
        uint256 indexed hatId,
        bool success
    );

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
    ) external returns (TriggerId triggerId) {
        // Input validation
        require(_admin > 0, "Invalid admin hat ID");

        // Validate that caller is admin hat wearer
        require(
            HATS().isWearerOfHat(msg.sender, _admin),
            "Not admin hat wearer"
        );

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // Store hat creation request
        _hatRequests[triggerId] = HatCreationRequest({
            admin: _admin,
            details: _details,
            maxSupply: _maxSupply,
            eligibility: _eligibility,
            toggle: _toggle,
            mutable_: _mutable,
            imageURI: _imageURI,
            requestor: msg.sender
        });

        // Emit the event
        emit HatCreationRequested(triggerId, _admin, msg.sender);
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
        HatCreationResponse memory response = abi.decode(
            _data,
            (HatCreationResponse)
        );

        // Verify triggerId is valid
        require(TriggerId.unwrap(response.triggerId) > 0, "Invalid triggerId");

        // Get the hat creation request
        HatCreationRequest memory request = _hatRequests[response.triggerId];

        // Verify request exists
        require(request.requestor != address(0), "Request not found");

        // If success, create the hat
        if (response.success) {
            // Create the hat
            uint256 newHatId = HATS().createHat(
                request.admin,
                request.details,
                request.maxSupply,
                request.eligibility,
                request.toggle,
                request.mutable_,
                request.imageURI
            );

            // Update the response with the actual hat ID
            response.hatId = newHatId;
        }

        // Emit the event
        emit HatCreationResultReceived(
            response.triggerId,
            response.hatId,
            response.success
        );
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

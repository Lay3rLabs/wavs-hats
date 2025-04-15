// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

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
    TriggerId public nextTriggerId;

    /// @notice Mapping of trigger IDs to hat creation requests
    mapping(TriggerId _triggerId => HatCreationData _request)
        internal _hatRequests;

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

    // /**
    //  * @notice Initialize the module instance with config
    //  * @param _initData The initialization data
    //  * @dev This is called by the factory during deployment
    //  */
    // function _setUp(bytes calldata _initData) internal override {
    //     // If there's initialization data, decode it
    //     if (_initData.length > 0) {
    //         // Leave this for potential future use
    //     }
    // }

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

        // Check one of these permission scenarios:
        // 1. The caller wears the admin hat directly (traditional permission)
        // 2. This contract is an admin of the hat (can create child hats)
        // 3. This contract wears an admin hat for this hat tree
        // bool isAuthorized = HATS().isWearerOfHat(msg.sender, _admin) ||
        //     HATS().isAdminOfHat(address(this), _admin) ||
        //     HATS().isWearerOfHat(address(this), _admin);

        // require(isAuthorized, "Not authorized to create hat");

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // TODO: don't store the request here, just emit the event
        // Store hat creation request
        _hatRequests[triggerId] = HatCreationData({
            admin: _admin,
            details: _details,
            maxSupply: _maxSupply,
            eligibility: _eligibility,
            toggle: _toggle,
            mutable_: _mutable,
            imageURI: _imageURI,
            requestor: msg.sender,
            hatId: 0,
            success: false
        });

        // Emit the new structured event for WAVS
        emit HatCreationTrigger(
            TriggerId.unwrap(triggerId),
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

        // TODO: remove this
        // // If this is a response to an existing request
        // if (
        //     TriggerId.unwrap(nextTriggerId) > 0 &&
        //     creationData.requestor != address(0) &&
        //     _hatRequests[TriggerId.wrap(1)].requestor != address(0)
        // ) {
        //     // Find the trigger ID if it exists
        //     TriggerId foundTriggerId;
        //     bool found = false;

        //     // Only look at recent trigger IDs to avoid excessive gas consumption
        //     uint64 maxCheck = 100;
        //     uint64 current = TriggerId.unwrap(nextTriggerId);
        //     uint64 startCheck = current > maxCheck ? current - maxCheck : 1;

        //     for (uint64 i = startCheck; i <= current; i++) {
        //         TriggerId tid = TriggerId.wrap(i);
        //         HatCreationData storage request = _hatRequests[tid];

        //         // Match against admin hat and requestor
        //         if (
        //             request.admin == creationData.admin &&
        //             request.requestor == creationData.requestor
        //         ) {
        //             foundTriggerId = tid;
        //             found = true;
        //             break;
        //         }
        //     }

        //     if (found) {
        //         // Get the hat creation request
        //         HatCreationData storage request = _hatRequests[foundTriggerId];

        //         // If success flag is true, create the hat
        //         if (creationData.success) {
        //             // Create the hat
        //             uint256 newHatId = HATS().createHat(
        //                 request.admin,
        //                 request.details,
        //                 request.maxSupply,
        //                 request.eligibility,
        //                 request.toggle,
        //                 request.mutable_,
        //                 request.imageURI
        //             );

        //             // Update the request with the actual hat ID
        //             request.hatId = newHatId;
        //             request.success = true;

        //             // Emit the event
        //             emit HatCreationResultReceived(
        //                 foundTriggerId,
        //                 newHatId,
        //                 true
        //             );
        //         }
        //         return;
        //     }
        // }

        // If we get here, either we couldn't find a matching request
        // or this is a direct offchain-triggered hat creation

        // // Validate admin hat
        // require(creationData.admin > 0, "Invalid admin hat ID");

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
            nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
            TriggerId newTriggerId = nextTriggerId;

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

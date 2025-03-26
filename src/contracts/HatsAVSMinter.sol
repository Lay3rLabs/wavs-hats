// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsModule} from "@hats-module/src/HatsModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {ITypes} from "../interfaces/ITypes.sol";

/**
 * @title HatsAVSMinter
 * @notice A WAVS service handler that can mint hats to addresses based on signed data
 */
contract HatsAVSMinter is HatsModule, ITypes {
    /// @notice The next trigger ID to be assigned
    TriggerId public nextTriggerId;

    /// @notice Mapping of trigger IDs to hat minting requests
    mapping(TriggerId _triggerId => HatMintingData _request)
        internal _mintRequests;

    /// @notice Service manager instance
    address private immutable _serviceManagerAddr;

    /**
     * @notice Struct to store hat minting data
     * @param hatId The hat ID to mint
     * @param wearer The address that will wear the hat
     * @param requestor The address that requested the hat minting
     * @param success Whether minting was successful
     * @param reason Optional reason for failure
     */
    struct HatMintingData {
        uint256 hatId;
        address wearer;
        address requestor;
        bool success;
        string reason;
    }

    /**
     * @notice Struct for the encoded hat and wearer data
     * @param hatId The hat ID to mint
     * @param wearer The address that will wear the hat
     */
    struct EncodedHatMintingData {
        uint256 hatId;
        address wearer;
    }

    /**
     * @notice Emitted when a hat minting is requested
     * @param triggerId The ID of the trigger
     * @param hatId The hat ID to mint
     * @param wearer The address that will wear the hat
     * @param requestor The address that requested the minting
     */
    event HatMintingRequested(
        TriggerId indexed triggerId,
        uint256 indexed hatId,
        address indexed wearer,
        address requestor
    );

    /**
     * @notice Emitted when a hat minting result is received
     * @param triggerId The ID of the trigger
     * @param hatId The hat ID
     * @param wearer The address wearing the hat
     * @param success Whether minting was successful
     */
    event HatMintingResultReceived(
        TriggerId indexed triggerId,
        uint256 indexed hatId,
        address indexed wearer,
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
        _serviceManagerAddr = _serviceManager;
    }

    /**
     * @notice Initialize the module instance with config
     * @param _initData The initialization data
     */
    function _setUp(bytes calldata _initData) internal override {
        if (_initData.length > 0) {
            // Optional initialization logic
        }
    }

    /**
     * @notice Request a hat minting
     * @param _hatId The hat ID to mint
     * @param _wearer The address that will wear the hat
     * @return triggerId The ID of the created trigger
     */
    function requestHatMinting(
        uint256 _hatId,
        address _wearer
    ) external returns (TriggerId triggerId) {
        // Input validation
        require(_hatId > 0, "Invalid hat ID");
        require(_wearer != address(0), "Invalid wearer address");

        // TODO remove this. This method is really just for testing.
        // Get admin of the hat using bitwise operations (first 32 bits of hatId)
        // According to Hats Protocol, the admin hat ID is the parent hat
        // uint256 adminHat = _hatId &
        //    0xFFFFFFFF00000000000000000000000000000000000000000000000000000000;

        // // Validate that caller is admin hat wearer or authorized
        // require(
        //     HATS().isWearerOfHat(msg.sender, adminHat),
        //     "Not authorized to mint"
        // );

        // Create new trigger ID
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        triggerId = nextTriggerId;

        // Store hat minting request
        _mintRequests[triggerId] = HatMintingData({
            hatId: _hatId,
            wearer: _wearer,
            requestor: msg.sender,
            success: false,
            reason: ""
        });

        // Emit the original event for backward compatibility
        emit HatMintingRequested(triggerId, _hatId, _wearer, msg.sender);

        // Create and emit the standard NewTrigger event that WAVS expects
        // Encode data using the EncodedHatMintingData struct to match Rust decoding
        EncodedHatMintingData memory encodedData = EncodedHatMintingData({
            hatId: _hatId,
            wearer: _wearer
        });

        TriggerInfo memory triggerInfo = TriggerInfo({
            triggerId: triggerId,
            creator: msg.sender,
            data: abi.encode(encodedData)
        });

        emit NewTrigger(abi.encode(triggerInfo));
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

        // Decode the minting data
        HatMintingData memory mintingData = abi.decode(_data, (HatMintingData));

        // Ensure hat ID is valid
        require(mintingData.hatId > 0, "Invalid hat ID");
        require(mintingData.wearer != address(0), "Invalid wearer address");

        // Check if there have been any requests at all
        if (TriggerId.unwrap(nextTriggerId) > 0) {
            // Find the trigger ID if it exists
            TriggerId foundTriggerId;
            bool found = false;

            // Only look at recent trigger IDs to avoid excessive gas consumption
            uint64 maxCheck = 100;
            uint64 current = TriggerId.unwrap(nextTriggerId);
            uint64 startCheck = current > maxCheck ? current - maxCheck : 1;

            for (uint64 i = startCheck; i <= current; i++) {
                TriggerId tid = TriggerId.wrap(i);
                HatMintingData storage request = _mintRequests[tid];

                // Match against hatId, wearer and requestor
                if (
                    request.hatId == mintingData.hatId &&
                    request.wearer == mintingData.wearer &&
                    request.requestor != address(0) // Ensure it's a valid request
                ) {
                    foundTriggerId = tid;
                    found = true;
                    break;
                }
            }

            if (found) {
                // Get the hat minting request
                HatMintingData storage request = _mintRequests[foundTriggerId];

                // If success flag is true, mint the hat
                if (mintingData.success) {
                    HATS().mintHat(request.hatId, request.wearer);
                    request.success = true;
                } else {
                    request.success = false;
                    request.reason = mintingData.reason;
                }

                // Emit the event
                emit HatMintingResultReceived(
                    foundTriggerId,
                    request.hatId,
                    request.wearer,
                    mintingData.success
                );

                return;
            }
        }

        // If we get here, either we couldn't find a matching request
        // or this is a direct offchain-triggered hat minting

        // For offchain-triggered events, create a new triggerId
        nextTriggerId = TriggerId.wrap(TriggerId.unwrap(nextTriggerId) + 1);
        TriggerId newTriggerId = nextTriggerId;

        // Mint the hat directly if success flag is true
        if (mintingData.success) {
            HATS().mintHat(mintingData.hatId, mintingData.wearer);

            // Emit the event
            emit HatMintingResultReceived(
                newTriggerId,
                mintingData.hatId,
                mintingData.wearer,
                true
            );
        }
    }

    /**
     * @notice Implements the moduleInterfaceId function from HatsModule
     * @return moduleId The module interface ID
     */
    function moduleInterfaceId() public pure returns (bytes4 moduleId) {
        return
            this.moduleInterfaceId.selector ^
            this.requestHatMinting.selector ^
            this.handleSignedData.selector;
    }
}

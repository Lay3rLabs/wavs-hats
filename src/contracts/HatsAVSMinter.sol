// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {HatsModule} from "@hats-module/src/HatsModule.sol";
import {IHats} from "hats-protocol/Interfaces/IHats.sol";
import {IWavsServiceManager} from "@wavs/interfaces/IWavsServiceManager.sol";
import {IHatsAvsTypes} from "../interfaces/IHatsAvsTypes.sol";

/**
 * @title HatsAvsMinter
 * @notice A WAVS service handler that can mint hats to addresses based on signed data
 */
contract HatsAvsMinter is HatsModule, IHatsAvsTypes {
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
        _serviceManagerAddr = _serviceManager;
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
    ) external returns (uint64 triggerId) {
        // Input validation
        require(_hatId > 0, "Invalid hat ID");
        require(_wearer != address(0), "Invalid wearer address");

        // Create new trigger ID
        nextTriggerId = nextTriggerId + 1;
        triggerId = nextTriggerId;

        // Emit the new structured event for WAVS
        emit MintingTrigger(triggerId, msg.sender, _hatId, _wearer);
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

        // For offchain-triggered events, create a new triggerId
        nextTriggerId = nextTriggerId + 1;
        uint64 newTriggerId = nextTriggerId;

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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @title IHatsAvsTypes
 * @notice Shared types and events for Hats AVS contracts
 */
interface IHatsAvsTypes {
    // TODO deprecate this event
    event NewTrigger(bytes _triggerInfo);

    // TODO deprecate this struct
    /**
     * @notice Struct to store trigger information
     * @param triggerId Unique identifier for the trigger
     * @param data Data associated with the triggerId
     */
    struct DataWithId {
        uint64 triggerId;
        bytes data;
    }

    /**
     * @notice Emitted when a new status check trigger is created
     * @param triggerId The ID of the trigger
     * @param creator The address that created the trigger
     * @param hatId The ID of the hat to check status for
     */
    event StatusCheckTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        uint256 hatId
    );

    /**
     * @notice Struct to store the result of a hat status check
     * @param triggerId Unique identifier for the trigger
     * @param active Whether the hat is active
     */
    struct StatusResult {
        uint64 triggerId;
        bool active;
        uint256 hatId;
    }

    /**
     * @notice Emitted when a status check result is received
     * @param triggerId The ID of the trigger
     * @param active Whether the hat is active
     */
    event StatusResultReceived(uint64 indexed triggerId, bool active);

    /**
     * @notice Emitted when a new eligibility check trigger is created
     * @param triggerId The ID of the trigger
     * @param creator The address that created the trigger
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    event EligibilityCheckTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        address wearer,
        uint256 hatId
    );

    /**
     * @notice Struct to store the result of an eligibility check
     * @param triggerId Unique identifier for the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    struct EligibilityResult {
        uint64 triggerId;
        bool eligible;
        bool standing;
        address wearer;
        uint256 hatId;
    }

    /**
     * @notice Emitted when an eligibility check result is received
     * @param triggerId The ID of the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    event EligibilityResultReceived(
        uint64 indexed triggerId,
        bool eligible,
        bool standing
    );

    /**
     * @notice Struct to store hat creation data
     * @param admin The admin hat ID
     * @param details The hat details
     * @param maxSupply The maximum supply
     * @param eligibility The eligibility module address
     * @param toggle The toggle module address
     * @param mutable_ Whether the hat is mutable
     * @param imageURI The hat image URI
     * @param requestor The address that requested the hat creation
     * @param hatId The ID of the created hat (0 if not yet created)
     * @param success Whether creation was successful
     */
    struct HatCreationData {
        uint256 admin;
        string details;
        uint32 maxSupply;
        address eligibility;
        address toggle;
        bool mutable_;
        string imageURI;
        address requestor;
        uint256 hatId;
        bool success;
    }

    /**
     * @notice Emitted when a new hat creation trigger is created
     * @param triggerId The ID of the trigger
     * @param creator The address that created the trigger
     * @param admin The admin hat ID
     * @param details The hat details
     * @param maxSupply The maximum supply
     * @param eligibility The eligibility module address
     * @param toggle The toggle module address
     * @param mutable_ Whether the hat is mutable
     * @param imageURI The hat image URI
     */
    event HatCreationTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        uint256 indexed admin,
        string details,
        uint32 maxSupply,
        address eligibility,
        address toggle,
        bool mutable_,
        string imageURI
    );

    /**
     * @notice Emitted when a hat creation result is received
     * @param triggerId The ID of the trigger
     * @param hatId The created hat ID
     * @param success Whether creation was successful
     */
    event HatCreationResultReceived(
        uint64 indexed triggerId,
        uint256 indexed hatId,
        bool success
    );

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
     * @notice Emitted when a new hat minting trigger is created
     * @param triggerId The ID of the trigger
     * @param creator The address that created the trigger
     * @param hatId The hat ID to mint
     * @param wearer The address that will wear the hat
     */
    event MintingTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        uint256 hatId,
        address wearer
    );

    /**
     * @notice Emitted when a hat minting result is received
     * @param triggerId The ID of the trigger
     * @param hatId The hat ID
     * @param wearer The address wearing the hat
     * @param success Whether minting was successful
     */
    event HatMintingResultReceived(
        uint64 indexed triggerId,
        uint256 indexed hatId,
        address indexed wearer,
        bool success
    );
}

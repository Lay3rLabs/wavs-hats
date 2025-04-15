// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @title IHatsAvsTypes
 * @notice Shared types and events for Hats AVS contracts
 */
interface IHatsAvsTypes {
    /// @notice TriggerId is a unique identifier for a trigger
    type TriggerId is uint64;

    /**
     * @notice Struct to store trigger information
     * @param triggerId Unique identifier for the trigger
     * @param data Data associated with the triggerId
     */
    struct DataWithId {
        TriggerId triggerId;
        bytes data;
    }

    /**
     * @notice Struct to store hat status request information with a trigger ID
     * @param triggerId Unique identifier for the trigger
     * @param hatId The ID of the hat
     */
    struct StatusRequest {
        TriggerId triggerId;
        uint256 hatId;
    }

    /**
     * @notice Struct to store the result of a hat status check
     * @param triggerId Unique identifier for the trigger
     * @param active Whether the hat is active
     */
    struct StatusResult {
        TriggerId triggerId;
        bool active;
    }

    /**
     * @notice Struct to store trigger data for eligibility checks
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    struct EligibilityTriggerData {
        address wearer;
        uint256 hatId;
    }

    /**
     * @notice Struct to store the result of an eligibility check
     * @param triggerId Unique identifier for the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    struct EligibilityResult {
        TriggerId triggerId;
        bool eligible;
        bool standing;
    }

    /**
     * @notice Emitted when a new hat status check is requested
     * @param triggerId The ID of the trigger
     * @param hatId The ID of the hat
     */
    event StatusCheckRequested(
        TriggerId indexed triggerId,
        uint256 indexed hatId
    );

    /**
     * @notice Emitted when a hat status check result is received
     * @param triggerId The ID of the trigger
     * @param active Whether the hat is active
     */
    event StatusResultReceived(TriggerId indexed triggerId, bool active);

    /**
     * @notice Emitted when a new eligibility check is requested
     * @param triggerId The ID of the trigger
     * @param wearer The address of the wearer
     * @param hatId The ID of the hat
     */
    event EligibilityCheckRequested(
        TriggerId indexed triggerId,
        address indexed wearer,
        uint256 indexed hatId
    );

    /**
     * @notice Emitted when an eligibility check result is received
     * @param triggerId The ID of the trigger
     * @param eligible Whether the wearer is eligible to wear the hat
     * @param standing Whether the wearer is in good standing
     */
    event EligibilityResultReceived(
        TriggerId indexed triggerId,
        bool eligible,
        bool standing
    );
}

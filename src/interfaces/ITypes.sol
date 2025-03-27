// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface ITypes {
    /**
     * @notice Struct to store trigger information
     * @param triggerId Unique identifier for the trigger
     * @param data Data associated with the triggerId
     */
    struct DataWithId {
        TriggerId triggerId;
        bytes data;
    }

    /// @notice TriggerId is a unique identifier for a trigger
    type TriggerId is uint64;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @title IWavsServiceHandler
 * @notice Interface for a WAVS service handler
 */
interface IWavsServiceHandler {
    function handleSignedData(
        bytes calldata _data,
        bytes calldata _signature
    ) external;
}

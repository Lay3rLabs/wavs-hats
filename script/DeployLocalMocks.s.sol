// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockWavsServiceManager} from "../src/mocks/MockWavsServiceManager.sol";

/**
 * @title DeployLocalMocks
 * @notice Deployment script for local mock contracts
 */
contract DeployLocalMocks is Script {
    function run() public {
        vm.startBroadcast();

        // Deploy the mock service manager
        MockWavsServiceManager mockServiceManager = new MockWavsServiceManager();
        console.log(
            "MockWavsServiceManager deployed at: %s",
            address(mockServiceManager)
        );

        vm.stopBroadcast();
    }
}

# Hats Protocol WAVS AVS Integration

This project integrates [Hats Protocol](https://github.com/Hats-Protocol/hats-protocol) with [WAVS (WASI Autonomous Verifiable Services)](https://docs.layer.xyz/wavs/overview) to enable automated hat eligibility checks and hat status management.

## Overview

The integration consists of:

1. **HatsEligibilityServiceHandler**: Implements `IHatsEligibility` to check if an address is eligible to wear a hat using WAVS.
2. **HatsToggleServiceHandler**: Implements `IHatsToggle` to determine if a hat should be active or inactive using WAVS.
3. **HatsAVSHatter**: Creates hats based on off-chain verification using WAVS.
4. **HatsAVSManager**: Central contract that orchestrates the integration.

## Architecture

### Components

- **WAVS Service Components**: Off-chain Rust components compiled to WASM that implement the actual eligibility and toggle checking logic.
- **On-chain Contracts**: Solidity contracts that communicate with WAVS and Hats Protocol.

### Flow

1. A user or system requests an eligibility check for a wearer and hat (or a status check for a hat).
2. The request is stored on-chain as a trigger and emitted as an event.
3. WAVS operators detect the event trigger and run the corresponding service component off-chain.
4. The off-chain component performs the eligibility logic and returns a result.
5. WAVS operators sign the result and submit it back on-chain to the service handler contract.
6. The Hats Protocol can then use this information to determine wearers' eligibility or hat status.

## Usage

### Setting Up Hats with WAVS Modules

To use a hat with WAVS eligibility checks:

```solidity
// Create a hat with the HatsEligibilityServiceHandler as the eligibility module
uint256 hatId = hats.createHat(
    adminHatId,
    "Hat Name",
    1, // maxSupply
    address(hatsEligibilityHandler), // eligibility module
    address(0), // toggle module
    true, // mutable
    "ipfs://..." // imageURI
);
```

To use a hat with WAVS toggle checks:

```solidity
// Create a hat with the HatsToggleServiceHandler as the toggle module
uint256 hatId = hats.createHat(
    adminHatId,
    "Hat Name",
    1, // maxSupply
    address(0), // eligibility module
    address(hatsToggleHandler), // toggle module
    true, // mutable
    "ipfs://..." // imageURI
);
```

## WAVS Service Components

### Eligibility Component

The hats-eligibility component implements the standard WAVS component interface:

```rust
fn run(action: TriggerAction) -> Result<Option<Vec<u8>>, String>
```

It expects the trigger data to be ABI encoded as:
- Input: `(address wearer, uint256 hatId)`
- Output: `(uint64 triggerId, bool eligible, bool standing)`

The component has a simple implementation that determines eligibility based on:
- Accounts starting with "0x1" are always eligible
- Other accounts are eligible if the current timestamp is even
- Accounts ending with "5" are never in good standing

### Toggle Component

The hats-toggle component implements the standard WAVS component interface:

```rust
fn run(action: TriggerAction) -> Result<Option<Vec<u8>>, String>
```

It expects the trigger data to be ABI encoded as:
- Input: `(uint256 hatId)`
- Output: `(uint64 triggerId, bool active)`

The component has a simple implementation that determines hat status based on:
- Hats with even IDs are always active
- Other hats are active if the current day is even

## Setup and Deployment

### Prerequisites

> Install [`cargo install cargo-component --locked`](https://github.com/bytecodealliance/cargo-component#installation) if you have not already.

> Install [Ollama](https://ollama.com/download) and download the llama3.1 model via `ollama pull llama3.1`.

```bash
# Install initial dependencies.
make setup

# Build the contracts and WASI components.
make build

# Run the tests.
make test
```

### Start Anvil and WAVS

> On MacOS Docker, ensure you've either enabled host networking (Docker Engine -> Settings -> Resources -> Network -> 'Enable Host Networking') or installed [docker-mac-net-connect](https://github.com/chipmk/docker-mac-net-connect) via `brew install chipmk/tap/docker-mac-net-connect && sudo brew services start chipmk/tap/docker-mac-net-connect`.

```bash
# Copy over the .env file.
cp .env.example .env

# Start all services.
make start-all
```

> The `start-all` command must remain running in your terminal. Use another terminal to run other commands.
>
> You can stop the services with `ctrl+c` (you may have to press it twice).

### Deploying Contracts

Before deploying the contracts, ensure you've set the required environment variables in your `.env` file:

```bash
# Required environment variables for deployment
HATS_PROTOCOL_ADDRESS=0x... # Address of the deployed Hats Protocol contract
HATS_MODULE_FACTORY_ADDRESS=0x... # Address of the deployed Hats Module Factory
```

If you're using the local WAVS setup, the SERVICE_MANAGER_ADDRESS will be read automatically from the deployments.json file.

Now, deploy the contracts:

```bash
# Deploy the contracts
forge script script/DeployHatsAVS.s.sol:DeployHatsAVS --rpc-url http://localhost:8545 --broadcast
```

After deployment, the script will add the deployed contract addresses to your `.env` file:

```bash
# Hats Protocol AVS Integration Addresses
HATS_ELIGIBILITY_SERVICE_HANDLER_IMPL=0x...
HATS_TOGGLE_SERVICE_HANDLER_IMPL=0x...
HATS_AVS_HATTER_IMPL=0x...
HATS_ELIGIBILITY_SERVICE_HANDLER=0x...
HATS_TOGGLE_SERVICE_HANDLER=0x...
HATS_AVS_HATTER=0x...
HATS_AVS_MANAGER=0x...
```

The `DeployHatsAVS` script will fail if there are existing environment variables. You can clean them with:

``` bash
./clean_env.sh
```

### Deploy Service Components

After deploying the contracts, you need to deploy the WAVS service components:

```bash
# Deploy the eligibility service component
COMPONENT_FILENAME=wavs_hats_eligibility.wasm SERVICE_TRIGGER_ADDR=$HATS_ELIGIBILITY_SERVICE_HANDLER SERVICE_SUBMISSION_ADDR=$HATS_ELIGIBILITY_SERVICE_HANDLER TRIGGER_EVENT="NewTrigger(bytes)" SERVICE_CONFIG='{"fuel_limit":100000000,"max_gas":5000000,"host_envs":[],"kv":[],"workflow_id":"default","component_id":"default"}' make deploy-service

# Deploy the toggle service component
COMPONENT_FILENAME=wavs_hats_toggle.wasm SERVICE_TRIGGER_ADDR=$HATS_TOGGLE_SERVICE_HANDLER SERVICE_SUBMISSION_ADDR=$HATS_TOGGLE_SERVICE_HANDLER TRIGGER_EVENT="NewTrigger(bytes)" SERVICE_CONFIG='{"fuel_limit":100000000,"max_gas":5000000,"host_envs":[],"kv":[],"workflow_id":"default","component_id":"default"}' make deploy-service
```

### Testing the Integration

You can use the following scripts to test the Hats Protocol WAVS integration:

#### Using Forge Scripts

##### SimplifiedTest.s.sol (Basic Testing)

The `SimplifiedTest.s.sol` script is the simplest way to test both eligibility and status checks:

```bash
# Run the simplified test script to send both eligibility and status check requests
forge script script/SimplifiedTest.s.sol --rpc-url http://localhost:8545 --broadcast

# Wait a few seconds for the WAVS services to process the requests

# Check the results
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545
```

This script performs the following actions:
- Requests an eligibility check for a specific wearer and hat ID
- Requests a status check for a hat ID
- Outputs the trigger IDs that were created

You can also specify parameters:
```bash
# Run with custom parameters: mode (0=all, 1=eligibility only, 2=toggle only), account, hatId
forge script script/SimplifiedTest.s.sol --rpc-url http://localhost:8545 --broadcast --sig "run(uint8,address,uint256)" 0 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1
```

##### CheckHatsAVSResults.s.sol (Checking Results)

After running any of the test scripts, you can use the `CheckHatsAVSResults.s.sol` script to check the results:

```bash
# Check the results for a specific account and hat IDs
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint8,address,uint256,uint256)" 0 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1 1
```

Parameters:
- First parameter (uint8): Mode (0=all, 1=eligibility only, 2=toggle only)
- Second parameter (address): Wearer address to check eligibility for
- Third parameter (uint256): Hat ID to check eligibility for
- Fourth parameter (uint256): Hat ID to check status for

## Minting Hats with WAVS Verification

In addition to creating hats and checking eligibility/status, this project also supports minting hats to addresses based on off-chain verification via WAVS.

### HatsAVSMinter

The `HatsAVSMinter` contract enables hat minting with WAVS verification:

1. Something triggers the service.
2. WAVS operators perform off-chain verification to determine if an address should receive the hat
3. If verification is successful, the hat is minted to the specified address

### Deploy the Minter Service Component

After deploying the contracts, deploy the WAVS service component for the minter:

```bash
# Deploy the minter service component
COMPONENT_FILENAME=wavs_hats_minter.wasm SERVICE_TRIGGER_ADDR=$HATS_AVS_MINTER SERVICE_SUBMISSION_ADDR=$HATS_AVS_MINTER TRIGGER_EVENT="NewTrigger(bytes)" SERVICE_CONFIG='{"fuel_limit":100000000,"max_gas":5000000,"host_envs":[],"kv":[],"workflow_id":"default","component_id":"default"}' make deploy-service
```

### Testing the Minter

You can test the `HatsAVSMinter` with the following scripts:

```bash
# Request a hat minting (uses default values)
forge script script/MinterTest.s.sol --rpc-url http://localhost:8545 --broadcast

# Wait a few seconds for WAVS processing

# Check if the hat was minted
forge script script/CheckMinterResults.s.sol --rpc-url http://localhost:8545
```

You can also provide custom parameters:

```bash
# Request hat minting with custom wearer and hat ID
forge script script/MinterTest.s.sol --rpc-url http://localhost:8545 --broadcast --sig "run(address,uint256)" 0x1234567890123456789012345678901234567890 42

# Check results with custom parameters
forge script script/CheckMinterResults.s.sol --rpc-url http://localhost:8545 --sig "run(address,uint256)" 0x1234567890123456789012345678901234567890 42
```





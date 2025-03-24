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

### Requesting Eligibility Checks

```solidity
// Request an eligibility check for a wearer and hat
TriggerId triggerId = hatsAVSManager.requestEligibilityCheck(wearerAddress, hatId);
```

### Requesting Status Checks

```solidity
// Request a status check for a hat
TriggerId triggerId = hatsAVSManager.requestStatusCheck(hatId);
```

### Setting Up Automated Checks

```solidity
// Set up automated eligibility checks for multiple wearers
address[] memory wearers = new address[](2);
wearers[0] = address1;
wearers[1] = address2;
hatsAVSManager.setupAutomaticEligibilityChecks(hatId, wearers);

// Set up an automated status check for a hat
hatsAVSManager.setupAutomaticStatusCheck(hatId);
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

### Deploy Service Components

After deploying the contracts, you need to deploy the WAVS service components:

```bash
# Deploy the eligibility service component
COMPONENT_FILENAME=hats_eligibility.wasm SERVICE_TRIGGER_ADDR=$HATS_AVS_MANAGER_ADDRESS SERVICE_SUBMISSION_ADDR=$HATS_ELIGIBILITY_SERVICE_HANDLER TRIGGER_EVENT="EligibilityCheckRequested(TriggerId, address, uint256)" SERVICE_CONFIG='{"fuel_limit":100000000,"max_gas":5000000,"host_envs":[],"kv":[],"workflow_id":"default","component_id":"default"}' make deploy-service

# Deploy the toggle service component
COMPONENT_FILENAME=hats_toggle.wasm SERVICE_TRIGGER_ADDR=$HATS_AVS_MANAGER_ADDRESS SERVICE_SUBMISSION_ADDR=$HATS_TOGGLE_SERVICE_HANDLER TRIGGER_EVENT="StatusCheckRequested(TriggerId, uint256)" SERVICE_CONFIG='{"fuel_limit":100000000,"max_gas":5000000,"host_envs":[],"kv":[],"workflow_id":"default","component_id":"default"}' make deploy-service
```

### Testing the Integration

You can use the following commands to test the Hats Protocol WAVS integration:

#### 1. Create a Hat with Eligibility Module

```bash
# Create a hat with the eligibility module
# Parameters: adminHatId, details, maxSupply, eligibility, toggle, mutable, imageURI
cast send --private-key $ANVIL_PRIVATE_KEY $HATS_PROTOCOL_ADDRESS "createHat(uint256,string,uint32,address,address,bool,string)" 1 "Test Hat with Eligibility" 10 $HATS_ELIGIBILITY_SERVICE_HANDLER 0x0000000000000000000000000000000000000000 true "ipfs://..."
```

#### 2. Request an Eligibility Check

```bash
# Request an eligibility check for a wearer and hat
# Parameters: wearer, hatId
cast send --private-key $ANVIL_PRIVATE_KEY $HATS_AVS_MANAGER "requestEligibilityCheck(address,uint256)" 0x1234567890123456789012345678901234567890 2
```

#### 3. Query Eligibility Status

```bash
# Query the eligibility status of a wearer for a hat
# Parameters: wearer, hatId
cast call $HATS_AVS_MANAGER "getEligibilityStatus(address,uint256)" 0x1234567890123456789012345678901234567890 2
```

#### 4. Create a Hat with Toggle Module

```bash
# Create a hat with the toggle module
# Parameters: adminHatId, details, maxSupply, eligibility, toggle, mutable, imageURI
cast send --private-key $ANVIL_PRIVATE_KEY $HATS_PROTOCOL_ADDRESS "createHat(uint256,string,uint32,address,address,bool,string)" 1 "Test Hat with Toggle" 10 0x0000000000000000000000000000000000000000 $HATS_TOGGLE_SERVICE_HANDLER true "ipfs://..."
```

#### 5. Request a Status Check

```bash
# Request a status check for a hat
# Parameters: hatId
cast send --private-key $ANVIL_PRIVATE_KEY $HATS_AVS_MANAGER "requestStatusCheck(uint256)" 2
```

#### 6. Query Hat Status

```bash
# Query the status of a hat
# Parameters: hatId
cast call $HATS_AVS_MANAGER "getHatStatus(uint256)" 2
```

## Instructions

These instructions cover the basic setup, deployment, and testing of the Hats Protocol WAVS integration. For more detailed usage and customization options, refer to the contract documentation and test files.


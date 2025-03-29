# Hats Protocol WAVS AVS Integration

This project integrates [Hats Protocol](https://github.com/Hats-Protocol/hats-protocol) with [WAVS (WASI Autonomous Verifiable Services)](https://docs.wavs.xyz/overview) to enable automated hat eligibility checks, status management, minting, and creation based onchain or offchain events.

TODO:
- More interesting example WAVS components that serve real use cases
- Review by someone more familiar with hats
- Consider removing triggerId logic? Some examples might be purely offchain triggers

NOTE: these are NOT audited and NOT PRODUCTION READY. Right now they work by letting anyone to trigger events that cause the services to run, and meant only for experimentation.

## Overview
The AVS consists of Solidity contracts that communicate with WAVS and Hats Protocol as well as off-chain Rust components compiled to WASM that implement the actual eligibility and toggle-checking logic.

Solidity Contracts in `src`:
1. **HatsEligibilityServiceHandler**: Implements `IHatsEligibility` to check if an address is eligible to wear a hat using WAVS.
2. **HatsToggleServiceHandler**: Implements `IHatsToggle` to determine if a hat should be active or inactive using WAVS.
3. **HatsAVSHatter**: Creates new hats based on off-chain verification using WAVS.
4. **HatsAVSMinter**: Mints new hats to users based on off-chain verification using WAVS.

WASI components in `components`:
1. **hats-eligibility**: updates eligibility for a particular hat.
2. **hats-toggle**: toggles active status for a particular hat.
3. **hats-minter**: mints a new hat to a target address.
4. **hats-creator**: creates a new kind of hat.

### General Flow

1. An event is emitted.
2. WAVS operators detect the event trigger and run the corresponding service component off-chain.
3. The off-chain component performs the application logic and returns a result.
4. WAVS operators sign the result and submit it back on-chain to the correct service handler contract (a hatter, eligibility module, toggle module, or minter).


## Setup and Deployment

### Prerequisites

> Install [`cargo install cargo-component --locked`](https://github.com/bytecodealliance/cargo-component#installation) if you have not already.

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
HATS_AVS_MINTER_IMPL=0x...
HATS_ELIGIBILITY_SERVICE_HANDLER=0x...
HATS_TOGGLE_SERVICE_HANDLER=0x...
HATS_AVS_HATTER=0x...
HATS_AVS_MINTER=0x...
HATS_AVS_MANAGER=0x...
```

Load these new environment variables with:
```bash
source .env
```

The `DeployHatsAVS` script will fail if there are existing environment variables. You can clean them with `./clean_env.sh`.

### Deploy Service Components

After deploying the contracts, you need to deploy all WAVS service components:

```bash
# Deploy the eligibility service component
COMPONENT_FILENAME=wavs_hats_eligibility.wasm SERVICE_TRIGGER_ADDR=$HATS_ELIGIBILITY_SERVICE_HANDLER SERVICE_SUBMISSION_ADDR=$HATS_ELIGIBILITY_SERVICE_HANDLER TRIGGER_EVENT="EligibilityCheckTrigger(uint64,address,address,uint256)" make deploy-service

# Deploy the toggle service component
COMPONENT_FILENAME=wavs_hats_toggle.wasm SERVICE_TRIGGER_ADDR=$HATS_TOGGLE_SERVICE_HANDLER SERVICE_SUBMISSION_ADDR=$HATS_TOGGLE_SERVICE_HANDLER TRIGGER_EVENT="StatusCheckTrigger(uint64,address,uint256)" make deploy-service

# Deploy the minter service component
COMPONENT_FILENAME=wavs_hats_minter.wasm SERVICE_TRIGGER_ADDR=$HATS_AVS_MINTER SERVICE_SUBMISSION_ADDR=$HATS_AVS_MINTER TRIGGER_EVENT="MintingTrigger(uint64,address,uint256,address)" make deploy-service

# Deploy the creator service component
COMPONENT_FILENAME=wavs_hats_creator.wasm SERVICE_TRIGGER_ADDR=$HATS_AVS_HATTER SERVICE_SUBMISSION_ADDR=$HATS_AVS_HATTER TRIGGER_EVENT="HatCreationTrigger(uint64,address,uint256,string,uint32,address,address,bool,string)" make deploy-service
```

## Testing the Integration

After deploying all contracts and service components, you can test each component individually:

### Checking Results

After running any of the test scripts, you should wait a few seconds for the WAVS services to process the requests. Then, you can check the results:

```bash
# Check all results
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545

# Check only eligibility results
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint8,address,uint256,uint256)" 1 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1 0

# Check only toggle results
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint8,address,uint256,uint256)" 2 0x0000000000000000000000000000000000000000 0 1

# Check minting results
forge script script/CheckMinterResults.s.sol --rpc-url http://localhost:8545
```

Parameters for CheckHatsAVSResults.s.sol:
- First parameter (uint8): Mode (0=all, 1=eligibility only, 2=toggle only)
- Second parameter (address): Wearer address to check eligibility for
- Third parameter (uint256): Hat ID to check eligibility for
- Fourth parameter (uint256): Hat ID to check status for

### Testing Eligibility

To test the eligibility service:

```bash
# Request an eligibility check (uses default account 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 and hat ID 1)
forge script script/EligibilityTest.s.sol --rpc-url http://localhost:8545 --broadcast

# You can also specify a custom account and hat ID
forge script script/EligibilityTest.s.sol --rpc-url http://localhost:8545 --broadcast --sig "run(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1
```

Check the eligibility results:
```bash
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint8,address,uint256,uint256)" 1 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1 0
```

### Testing Toggle

To test the toggle (hat status) service:

```bash
# Request a status check (uses default hat ID 1)
forge script script/ToggleTest.s.sol --rpc-url http://localhost:8545 --broadcast

# You can also specify a custom hat ID
forge script script/ToggleTest.s.sol --rpc-url http://localhost:8545 --broadcast --sig "run(uint256)" 1
```

Check the toggle results:
```bash
forge script script/CheckHatsAVSResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint8,address,uint256,uint256)" 2 0x0000000000000000000000000000000000000000 0 1
```

### Testing Minting

To test the hat minting service:

```bash
# Request a hat minting (uses default values)
forge script script/MinterTest.s.sol --rpc-url http://localhost:8545 --broadcast

# You can also provide custom parameters
forge script script/MinterTest.s.sol --rpc-url http://localhost:8545 --broadcast --sig "run(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1
```

Check the minting results:
```bash
forge script script/CheckMinterResults.s.sol --rpc-url http://localhost:8545
```

### Testing Hat Creation

To test the hat creation service:

```bash
# Request a hat creation (uses default values)
forge script script/CreatorTest.s.sol --tc CreatorTest --rpc-url http://localhost:8545 --broadcast

# You can also provide custom parameters
forge script script/CreatorTest.s.sol --tc CreatorTest --rpc-url http://localhost:8545 --broadcast --sig "run(uint256,string,uint32,address,address,bool,string)" 281474976710656 "Custom Hat" 50 0x0000000000000000000000000000000000000000 0x0000000000000000000000000000000000000000 true "ipfs://QmCustomHash"
```

Check the hat creation results:
```bash
forge script script/CheckCreatorResults.s.sol --rpc-url http://localhost:8545

# You can also specify a custom admin hat ID
forge script script/CheckCreatorResults.s.sol --rpc-url http://localhost:8545 --sig "run(uint256)" 281474976710656
```

The hat creation process involves:
1. The script checks if you're wearing the admin hat, and if not, creates a top hat that you can use as admin
2. It then requests hat creation through the HatsAVSHatter contract
3. WAVS operators detect the request and process it off-chain
4. The result is then submitted back on-chain
5. You can check if the hat was created successfully using the CheckCreatorResults script


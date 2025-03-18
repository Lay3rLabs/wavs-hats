# Hats Protocol WAVS AVS Integration

This project integrates [Hats Protocol](https://github.com/Hats-Protocol/hats-protocol) with [WAVS (WASI Autonomous Verifiable Services)](https://docs.layer.xyz/wavs/overview) to enable automated hat eligibility checks and hat status management.

## Overview

The integration consists of:

1. **HatsEligibilityServiceHandler**: Implements `IHatsEligibility` to check if an address is eligible to wear a hat using WAVS.
2. **HatsToggleServiceHandler**: Implements `IHatsToggle` to determine if a hat should be active or inactive using WAVS.
3. **HatsAVSTrigger**: Creates triggers for hat eligibility and status checks.
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


## Installation

```bash
# Install dependencies
forge install
```

## Building

```bash
# Build the contracts and components
make build
```

## Deployment

```bash
# Deploy contracts
forge script script/DeployHatsAVS.s.sol:DeployHatsAVS --rpc-url http://localhost:8545 --broadcast
```

## Testing

```bash
# Run tests
forge test
```

## License

MIT

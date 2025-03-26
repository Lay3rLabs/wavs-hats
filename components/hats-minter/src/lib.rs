#[allow(warnings)]
mod bindings;
use alloy_sol_types::{sol, SolValue};
use bindings::{
    export,
    wavs::worker::layer_types::{TriggerData, TriggerDataEthContractEvent},
    Guest, TriggerAction,
};
use wavs_wasi_chain::{
    decode_event_log_data,
    ethereum::alloy_primitives::{Address, Uint},
};

sol! {
    type TriggerId is uint64;

    // Define struct to match the tuple being encoded in Solidity
    #[derive(Debug)]
    struct EncodedHatMintingData {
        uint256 hatId;
        address wearer;
    }

    #[derive(Debug)]
    event NewTrigger(bytes _triggerInfo);

    #[derive(Debug)]
    struct TriggerInfo {
        TriggerId triggerId;
        address creator;
        bytes data;
    }

    #[derive(Debug)]
    struct HatMintingData {
        uint256 hatId;
        address wearer;
        address requestor;
        bool success;
        string reason;
    }
}

struct Component;

impl Guest for Component {
    fn run(trigger_action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        match trigger_action.data {
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                // Decode the NewTrigger event to get the _triggerInfo bytes
                let NewTrigger { _triggerInfo } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Decode the _triggerInfo bytes to get the TriggerInfo struct
                let trigger_info = TriggerInfo::abi_decode(&_triggerInfo, true)
                    .map_err(|e| format!("Failed to decode trigger info: {}", e))?;

                eprintln!("Successfully decoded trigger info");
                // Use the raw value for logging the trigger ID
                eprintln!("Trigger ID: {}", u64::from(trigger_info.triggerId));
                eprintln!("Creator: {}", trigger_info.creator);
                eprintln!("Data length: {}", trigger_info.data.len());

                // Create a default formatted top hat ID (domain 1)
                // In Hats Protocol, top hat IDs are formatted as: domain << 224
                let default_hat_id = Uint::from(1_u8) << 224;
                let default_wearer = trigger_info.creator;

                // Try to decode the encoded hat and wearer data from the struct
                let (hat_id, wearer) = if !trigger_info.data.is_empty() {
                    // We're expecting that data is abi.encode(EncodedHatMintingData)
                    // So first we need to decode the outer layer
                    match EncodedHatMintingData::abi_decode(&trigger_info.data, true) {
                        Ok(encoded_data) => {
                            eprintln!("Successfully decoded hat ID and wearer from trigger data");
                            // Ensure hat ID is valid for Hats Protocol format
                            let formatted_hat_id = if encoded_data.hatId == Uint::from(1_u8) {
                                // If it's 1, it's likely meant to be a top hat with domain 1
                                eprintln!("Converting hat ID 1 to proper format");
                                default_hat_id
                            } else {
                                encoded_data.hatId
                            };
                            (formatted_hat_id, encoded_data.wearer)
                        }
                        Err(e) => {
                            eprintln!("Failed to decode EncodedHatMintingData: {}", e);
                            eprintln!("Using default values");
                            (default_hat_id, default_wearer)
                        }
                    }
                } else {
                    eprintln!("No data in trigger_info, using defaults");
                    (default_hat_id, default_wearer)
                };

                // Log the values we're using
                eprintln!("Using hat ID: {}", hat_id);
                eprintln!("Using wearer: {}", wearer);

                // Create HatMintingData with the extracted data
                let result = HatMintingData {
                    hatId: hat_id,
                    wearer,
                    requestor: trigger_info.creator,
                    success: true, // Set success to true to allow minting
                    reason: "".to_string(),
                };

                // Log success message
                eprintln!("Hat minter component successfully processed the trigger");

                // Return the ABI-encoded result
                Ok(Some(result.abi_encode()))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

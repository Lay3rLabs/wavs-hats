#[allow(warnings)]
mod bindings;
use alloy_sol_types::{sol, SolValue};
use bindings::{
    export,
    wavs::worker::layer_types::{TriggerData, TriggerDataEthContractEvent},
    Guest, TriggerAction,
};
use wavs_wasi_chain::{decode_event_log_data, ethereum::alloy_primitives::Uint};

sol!("../../src/interfaces/IHatsAvsTypes.sol");

struct Component;

impl Guest for Component {
    fn run(trigger_action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        match trigger_action.data {
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                // Decode the MintingTrigger event
                let IHatsAvsTypes::MintingTrigger { triggerId, creator, hatId, wearer } =
                    decode_event_log_data!(log)
                        .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                eprintln!("Successfully decoded minting trigger");
                eprintln!("Trigger ID: {}", u64::from(triggerId));
                eprintln!("Creator: {}", creator);
                eprintln!("Hat ID: {}", hatId);
                eprintln!("Wearer: {}", wearer);

                // Create a default formatted top hat ID (domain 1) if needed
                let formatted_hat_id = if hatId == Uint::from(1_u8) {
                    // If it's 1, it's likely meant to be a top hat with domain 1
                    eprintln!("Converting hat ID 1 to proper format");
                    Uint::from(1_u8) << 224
                } else {
                    hatId
                };

                // Create HatMintingData with the extracted data
                let result = IHatsAvsTypes::HatMintingData {
                    hatId: formatted_hat_id,
                    wearer,
                    requestor: creator,
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

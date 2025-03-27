#[allow(warnings)]
mod bindings;
use alloy_sol_types::{sol, SolValue};
use bindings::{
    export,
    wavs::worker::layer_types::{TriggerData, TriggerDataEthContractEvent},
    Guest, TriggerAction,
};
use wavs_wasi_chain::{decode_event_log_data, ethereum::alloy_primitives::Uint};

sol! {
    type TriggerId is uint64;

    #[derive(Debug)]
    event HatCreationTrigger(
        uint64 indexed triggerId,
        address indexed creator,
        uint256 indexed admin,
        string details,
        uint32 maxSupply,
        address eligibility,
        address toggle,
        bool mutable_,
        string imageURI
    );

    #[derive(Debug)]
    struct HatCreationData {
        uint256 admin;
        string details;
        uint32 maxSupply;
        address eligibility;
        address toggle;
        bool mutable_;
        string imageURI;
        address requestor;
        uint256 hatId;
        bool success;
    }
}

struct Component;

impl Guest for Component {
    fn run(trigger_action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        match trigger_action.data {
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                // Decode the HatCreationTrigger event
                let HatCreationTrigger {
                    triggerId,
                    creator,
                    admin,
                    details,
                    maxSupply,
                    eligibility,
                    toggle,
                    mutable_,
                    imageURI,
                } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                eprintln!("Successfully decoded hat creation trigger");
                eprintln!("Trigger ID: {}", u64::from(triggerId));
                eprintln!("Creator: {}", creator);
                eprintln!("Admin hat ID: {}", admin);
                eprintln!("Details: {}", details);
                eprintln!("Max supply: {}", maxSupply);

                // Create HatCreationData with the extracted data
                let result = HatCreationData {
                    admin,
                    details,
                    maxSupply,
                    eligibility,
                    toggle,
                    mutable_,
                    imageURI,
                    requestor: creator,
                    hatId: Uint::from(0), // Filled in by the contract after creation
                    success: true,
                };

                // Log success message
                eprintln!("Hat creation component successfully processed the trigger");

                // Return the ABI-encoded result
                Ok(Some(result.abi_encode()))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

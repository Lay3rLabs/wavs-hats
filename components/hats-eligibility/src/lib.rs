#[allow(warnings)]
mod bindings;
use alloy_sol_types::{sol, SolValue};
use bindings::{
    export,
    wavs::worker::layer_types::{TriggerData, TriggerDataEthContractEvent},
    Guest, TriggerAction,
};
use wavs_wasi_chain::decode_event_log_data;

sol! {
    type TriggerId is uint64;

    #[derive(Debug)]
    event EligibilityCheckRequested(
        TriggerId indexed triggerId,
        address indexed wearer,
        uint256 indexed hatId
    );

    #[derive(Debug)]
    struct EligibilityResult {
        TriggerId triggerId;
        bool eligible;
        bool standing;
    }
}

struct Component;

impl Guest for Component {
    fn run(trigger_action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        match trigger_action.data {
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                // Decode event
                let EligibilityCheckRequested { triggerId, .. } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Return result with payload data recieved in handleSignedData
                Ok(Some(
                    EligibilityResult { triggerId, eligible: true, standing: true }.abi_encode(),
                ))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

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
    event NewTrigger(bytes _triggerInfo);

    #[derive(Debug)]
    struct TriggerInfo {
        TriggerId triggerId;
        address creator;
        bytes data;
    }

    #[derive(Debug)]
    struct StatusResult {
        TriggerId triggerId;
        bool active;
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
                // Return error if we can't decode instead of using fallbacks
                let trigger_info = TriggerInfo::abi_decode(&_triggerInfo, true)
                    .map_err(|e| format!("Failed to decode trigger info: {}", e))?;

                eprintln!("Successfully decoded trigger info");

                // Extract the hat ID from data if needed for your logic
                // In a real implementation, you would analyze the hat ID data
                // to determine if the hat should be active

                // For this simplified implementation, we're just setting active to true
                let active = true;

                // Create a StatusResult with the proper triggerId from decoded data
                let result = StatusResult { triggerId: trigger_info.triggerId, active };

                // Return the ABI-encoded result
                Ok(Some(result.abi_encode()))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

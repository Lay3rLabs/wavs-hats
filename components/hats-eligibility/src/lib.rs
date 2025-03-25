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
                // Decode the NewTrigger event to get the _triggerInfo bytes
                let NewTrigger { _triggerInfo } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Decode the _triggerInfo bytes to get the TriggerInfo struct
                // Return error if we can't decode instead of using fallbacks
                let trigger_info = TriggerInfo::abi_decode(&_triggerInfo, true)
                    .map_err(|e| format!("Failed to decode trigger info: {}", e))?;

                eprintln!("Successfully decoded trigger info");

                // Extract wearer and hatId if needed from data
                // In a real implementation, you would analyze the data to determine
                // if the wearer is eligible and in good standing

                // For this simplified implementation, we're just setting:
                // eligible = true and standing = true
                let eligible = true;
                let standing = true;

                // Create EligibilityResult with the proper triggerId from decoded data
                let result =
                    EligibilityResult { triggerId: trigger_info.triggerId, eligible, standing };

                // Log success message
                eprintln!("Eligibility component successfully processed the trigger");

                // Return the ABI-encoded result
                Ok(Some(result.abi_encode()))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

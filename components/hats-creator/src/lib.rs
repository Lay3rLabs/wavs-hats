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
    event NewTrigger(bytes _triggerInfo);

    #[derive(Debug)]
    struct TriggerInfo {
        TriggerId triggerId;
        address creator;
        bytes data;
    }

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
                // Decode the NewTrigger event to get the _triggerInfo bytes
                let NewTrigger { _triggerInfo } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Decode the _triggerInfo bytes to get the TriggerInfo struct
                // Return error if we can't decode instead of using fallbacks
                let trigger_info = TriggerInfo::abi_decode(&_triggerInfo, true)
                    .map_err(|e| format!("Failed to decode trigger info: {}", e))?;

                eprintln!("Successfully decoded trigger info");

                // TODO decode the data in TriggerInfo.data to get the HatCreationData struct

                // Create EligibilityResult with the proper triggerId from decoded data
                let result = HatCreationData {
                    admin: Uint::from(0),
                    details: "hat details".to_string(),
                    maxSupply: 1,
                    eligibility: trigger_info.creator,
                    toggle: trigger_info.creator,
                    mutable_: true,
                    imageURI: "".to_string(),
                    requestor: trigger_info.creator,
                    hatId: Uint::from(0),
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

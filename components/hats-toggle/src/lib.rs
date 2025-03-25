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
    struct StatusResult {
        TriggerId triggerId;
        bool active;
    }

    #[derive(Debug)]
    event StatusCheckRequested(
        uint64 indexed triggerId,
        uint256 indexed hatId
    );

}

struct Component;

impl Guest for Component {
    fn run(trigger_action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        match trigger_action.data {
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                // Decode event
                let StatusCheckRequested { triggerId, .. } = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Return true. Normally you would like to have some other logic in the component
                // to decide if the transaction should be approved or not.
                Ok(Some(StatusResult { triggerId, active: true }.abi_encode()))
            }
            _ => Err("Unsupported trigger data".to_string()),
        }
    }
}

export!(Component with_types_in bindings);

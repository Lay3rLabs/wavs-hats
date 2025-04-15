#[allow(warnings)]
mod bindings;
mod evm;
mod image;
mod ipfs;
mod llm;
mod nft;

use alloy_sol_macro::sol;
use alloy_sol_types::SolValue;
use bindings::{
    export,
    wavs::worker::layer_types::{TriggerData, TriggerDataEthContractEvent},
    Guest, TriggerAction,
};
use wavs_wasi_chain::decode_event_log_data;
use wstd::runtime::block_on;

// Use the sol! macro to import needed solidity types
// You can write solidity code in the macro and it will be available in the component
// Or you can import the types from a solidity file.
sol!("../../src/interfaces/ITypes.sol");
sol! {
    #[derive(Debug)]
    event NewTrigger(bytes _triggerInfo);
}

use crate::llm::{LLMClient, Message};
use crate::ITypes::DataWithId;

#[derive(Default)]
pub struct Component;

impl Guest for Component {
    /// @dev This function is called when a WAVS trigger action is fired.
    fn run(action: TriggerAction) -> std::result::Result<Option<Vec<u8>>, String> {
        // Decode the trigger event
        let trigger_info = match action.data {
            // Fired from an Ethereum contract event.
            TriggerData::EthContractEvent(TriggerDataEthContractEvent { log, .. }) => {
                let event: NewTrigger = decode_event_log_data!(log)
                    .map_err(|e| format!("Failed to decode event log data: {}", e))?;

                // Decode the trigger info bytes into DataWithId
                DataWithId::abi_decode(&event._triggerInfo, false)
                    .map_err(|e| format!("Failed to decode trigger info: {}", e))?
            }
            // Fired from a raw data event (e.g. from a CLI command or from another component).
            TriggerData::Raw(data) => {
                let prompt = std::str::from_utf8(&data)
                    .map_err(|e| format!("Failed to decode prompt from bytes: {}", e))?;
                DataWithId { triggerId: 0, data: prompt.to_string().into() }
            }
            _ => Err("Unsupported trigger data type".to_string())?,
        };

        // The data field contains the actual prompt/message to be processed
        let prompt = std::str::from_utf8(&trigger_info.data)
            .map_err(|e| format!("Failed to decode prompt from bytes: {}", e))?;

        // TODO get system prompt and user prompt from hats nfts tokenURI

        // Process the prompt using the LLM client
        let result = block_on(async {
            let client = LLMClient::new("llama3.2")
                .map_err(|e| format!("Failed to initialize LLM client: {}", e))?;
            let messages = vec![Message { role: "user".to_string(), content: prompt.to_string() }];
            client.chat_completion(&messages).await
        })
        .map_err(|e| format!("Failed to get chat completion: {}", e))?;

        // Return the result encoded as DataWithId
        let encoded = DataWithId {
            triggerId: trigger_info.triggerId,
            data: result.as_bytes().to_vec().into(),
        }
        .abi_encode();

        Ok(Some(encoded))
    }
}

export!(Component with_types_in bindings);

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use anyhow::Result;

//     // Test helper functions
//     fn setup_test_component() -> Component {
//         Component::default()
//     }

//     // fn create_test_trigger() -> TriggerAction {
//     //     mock_trigger(b"test data")
//     // }
// }

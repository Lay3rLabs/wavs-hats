#[allow(warnings)]
mod bindings;
mod evm;
mod image;
mod ipfs;
mod llm;
mod nft;
mod tools;

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
sol!("../../src/interfaces/IHatsAvsTypes.sol");

use crate::llm::LLMClient;
use crate::tools::builders;
use crate::tools::Message;
use crate::IHatsAvsTypes::{DataWithId, NewTrigger};

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
            // Note: this is just for testing ATM.
            // TODO pass in and decode an actual event, so this can be composed with other components
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

        // Process the prompt using the LLM client
        let result = block_on(async {
            // TODO get system prompt, model, and user prompt from hats nfts tokenURI
            let model = "llama3.2";

            // Example JSON configuration
            let config_json = r#"{
                "temperature": 0.0,
                "top_p": 0.9,
                "seed": 42,
                "max_tokens": 500,
                "context_window": 4096
            }"#;

            // Create messages
            let messages = vec![
                Message::new_system(
                    "Use the provided tools when appropriate to assist users with their queries. Only output tool results, no other text."
                        .to_string(),
                ),
                Message::new_user(prompt.to_string()),
            ];

            // Create client directly from JSON configuration
            let client = LLMClient::from_json(model, config_json)
                .map_err(|e| format!("Failed to initialize LLM client: {}", e))?;

            // Define available tools using the helper functions
            let available_tools = vec![builders::calculator()];

            // Send request with tools
            let mut response = client.chat_completion(&messages, Some(&available_tools)).await?;

            // Handle tool calls if present
            let tool_calls = response.tool_calls.take(); // Take ownership of tool_calls
            if let Some(tool_calls) = tool_calls {
                println!("Received tool calls: {:?}", tool_calls);
                if !tool_calls.is_empty() {
                    println!("Processing {} tool calls", tool_calls.len());
                    // Process all tool calls
                    return tools::process_tool_calls(&client, messages, response, tool_calls)
                        .await;
                } else {
                    // No tool calls, just return the text content
                    println!("No tool calls in response, returning content");
                    Ok(response.content.unwrap_or_default())
                }
            } else {
                // No tool calls, just return the text content
                println!("No tool_calls field in response, returning content");
                Ok(response.content.unwrap_or_default())
            }
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

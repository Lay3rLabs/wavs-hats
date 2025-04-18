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
use crate::tools::handlers;
use crate::tools::{Message, Tool};
use crate::IHatsAvsTypes::{DataWithId, NewTrigger};
use serde_json::json;

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

        // TODO get system prompt, model, and user prompt from hats nfts tokenURI

        // Process the prompt using the LLM client
        let result = block_on(async {
            let client = LLMClient::new("gpt-4")
                .map_err(|e| format!("Failed to initialize LLM client: {}", e))?;

            // Define available tools using the helper functions
            let available_tools = vec![
                builders::calculator(),
            ];

            // Create messages
            let messages = vec![
                Message::new_system("You are a helpful assistant for the Hats Protocol, a system for creating, managing, and wearing authority tokens called Hats. Use the provided tools when appropriate to assist users with their queries.".to_string()),
                Message::new_user(prompt.to_string()),
            ];
            // Send request with tools
            let mut response = client.chat_completion(&messages, Some(&available_tools)).await?;

            // Handle tool calls if present
            let tool_calls = response.tool_calls.take(); // Take ownership of tool_calls
            if let Some(tool_calls) = tool_calls {
                if !tool_calls.is_empty() {
                    println!("Tool calls: {:?}", tool_calls);
                    // Process all tool calls
                    return process_tool_calls(&client, messages, response, tool_calls).await;
                } else {
                    // No tool calls, just return the text content
                    Ok(response.content.unwrap_or_default())
                }
            } else {
                // No tool calls, just return the text content
                Ok(response.content.unwrap_or_default())
            }
        })
        .map_err(|e| format!("Failed to get chat completion: {}", e))?;

        println!("Result: {:?}", result);

        // Return the result encoded as DataWithId
        let encoded = DataWithId {
            triggerId: trigger_info.triggerId,
            data: result.as_bytes().to_vec().into(),
        }
        .abi_encode();

        Ok(Some(encoded))
    }
}

/// Process tool calls and generate a response
async fn process_tool_calls(
    client: &LLMClient,
    initial_messages: Vec<Message>,
    response: Message,
    tool_calls: Vec<tools::ToolCall>,
) -> Result<String, String> {
    // Create a new messages array for the follow-up conversation
    let mut tool_messages = initial_messages.clone();

    // Add the assistant's response with tool calls, ensuring content is not null
    // When we're sending tool calls, OpenAI requires content to be a string (even if empty)
    // We MUST preserve the original tool_calls so OpenAI can match the tool responses
    let sanitized_response = Message {
        role: response.role,
        content: Some(response.content.unwrap_or_default()),
        tool_calls: Some(tool_calls.clone()), // Important: preserve the tool_calls!
        tool_call_id: response.tool_call_id,
        name: response.name,
    };
    tool_messages.push(sanitized_response);

    // Process each tool call and add the results
    for tool_call in tool_calls {
        let tool_result = handlers::execute_tool_call(&tool_call)?;
        tool_messages.push(Message::new_tool_result(tool_call.id.clone(), tool_result));
    }

    // Get the final response incorporating all tool results
    let final_response = client.chat_completion_text(&tool_messages).await?;
    Ok(final_response)
}

export!(Component with_types_in bindings);

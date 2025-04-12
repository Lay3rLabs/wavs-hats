use core::panic::PanicMessage;

use crate::llm::{LLMClient, Message, Provider};
use anyhow::Result;
use serde::{Deserialize, Serialize};
use wstd::{
    http::{Client, IntoBody, Request},
    io::AsyncRead,
};

// Ollama response structures
#[derive(Deserialize, Debug)]
#[serde(untagged)]
pub enum OllamaChatResponse {
    Success(OllamaChatSuccessResponse),
    Error { error: String },
}

#[derive(Deserialize, Debug)]
pub struct OllamaChatSuccessResponse {
    pub message: OllamaChatMessage,
}

#[derive(Deserialize, Debug, Serialize)]
pub struct OllamaChatMessage {
    pub content: String,
}

/// Query Ollama with the given model, messages, and options
pub async fn query_llama(
    model: &str,
    messages: &Vec<Message>,
    options: &serde_json::Value,
) -> Result<String, String> {
    // Create LLM client for Ollama
    let client = LLMClient::new(Provider::Ollama, model)?;

    // Send chat completion request
    client.chat_completion(messages, None).await
}

pub async fn query_ollama(prompt: &str) -> Result<String> {
    let client =
        LLMClient::new(Provider::Ollama, "llama3.1").map_err(|e| anyhow::anyhow!("{}", e))?;

    let messages = vec![Message { role: "user".to_string(), content: prompt.to_string() }];

    client.chat_completion(&messages, None).await.map_err(|e| anyhow::anyhow!("{}", e))
}

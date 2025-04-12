use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use wstd::{
    http::{Client, HeaderValue, IntoBody, Request},
    io::AsyncRead,
};

/// Common message structure for chat completions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: String,
    pub content: String,
}

/// Client for making LLM API requests
#[derive(Debug)]
pub struct LLMClient {
    model: String,
    api_url: String,
}

impl LLMClient {
    /// Create a new LLM client
    pub fn new(model: &str) -> Result<Self, String> {
        // Validate model name is not empty
        if model.trim().is_empty() {
            return Err("Model name cannot be empty".to_string());
        }

        // Use Ollama's OpenAI-compatible endpoint
        let api_url = env::var("WAVS_ENV_OLLAMA_API_URL")
            .unwrap_or_else(|_| "http://localhost:11434".to_string());

        Ok(Self { model: model.to_string(), api_url: format!("{}/v1/chat/completions", api_url) })
    }

    /// Send a chat completion request
    pub async fn chat_completion(&self, messages: &[Message]) -> Result<String, String> {
        // Validate messages
        if messages.is_empty() {
            return Err("Messages cannot be empty".to_string());
        }

        // Create request body with deterministic settings
        let body = json!({
            "model": self.model,
            "messages": messages,
            "temperature": 0.0,
            "top_p": 1.0,
            "seed": 42,
            "stream": false
        });

        // Create request
        let mut req = Request::post(&self.api_url)
            .body(serde_json::to_vec(&body).unwrap().into_body())
            .map_err(|e| format!("Failed to create request: {}", e))?;

        // Add headers
        req.headers_mut().insert("Content-Type", HeaderValue::from_static("application/json"));
        req.headers_mut().insert("Accept", HeaderValue::from_static("application/json"));

        // Send request
        let mut res =
            Client::new().send(req).await.map_err(|e| format!("Request failed: {}", e))?;

        if res.status() != 200 {
            let mut error_body = Vec::new();
            res.body_mut()
                .read_to_end(&mut error_body)
                .await
                .map_err(|e| format!("Failed to read error response: {}", e))?;
            return Err(format!(
                "API error: status {} - {}",
                res.status(),
                String::from_utf8_lossy(&error_body)
            ));
        }

        // Read response body
        let mut body_buf = Vec::new();
        res.body_mut()
            .read_to_end(&mut body_buf)
            .await
            .map_err(|e| format!("Failed to read response body: {}", e))?;

        let body =
            String::from_utf8(body_buf).map_err(|e| format!("Invalid UTF-8 in response: {}", e))?;

        // Parse OpenAI-compatible response
        #[derive(Deserialize)]
        struct ChatResponse {
            choices: Vec<Choice>,
        }

        #[derive(Deserialize)]
        struct Choice {
            message: Message,
        }

        let resp: ChatResponse =
            serde_json::from_str(&body).map_err(|e| format!("Failed to parse response: {}", e))?;

        resp.choices
            .first()
            .map(|choice| choice.message.content.clone())
            .ok_or_else(|| "No response choices returned".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use wstd::runtime::block_on;

    fn setup_test_env() {
        env::set_var("WAVS_ENV_OLLAMA_API_URL", "http://localhost:11434");
    }

    #[test]
    fn test_llm_client_initialization() {
        setup_test_env();

        let client = LLMClient::new("llama3.1");
        assert!(client.is_ok());
        let client = client.unwrap();
        assert_eq!(client.model, "llama3.1");
        assert!(client.api_url.contains("localhost:11434"));
        assert!(client.api_url.contains("/v1/chat/completions"));
    }

    #[test]
    fn test_empty_messages() {
        setup_test_env();
        let client = LLMClient::new("llama3.1").unwrap();
        let empty_messages: Vec<Message> = vec![];

        let result = block_on(async { client.chat_completion(&empty_messages).await });

        assert!(result.is_err());
        assert!(matches!(result, Err(e) if e.contains("Messages cannot be empty")));
    }

    #[test]
    fn test_empty_model_name() {
        setup_test_env();
        let result = LLMClient::new("");
        assert!(result.is_err());
        assert!(matches!(result, Err(e) if e.contains("Model name cannot be empty")));

        let result = LLMClient::new("   ");
        assert!(result.is_err());
        assert!(matches!(result, Err(e) if e.contains("Model name cannot be empty")));
    }

    #[test]
    fn test_chat_completion_integration() {
        setup_test_env();

        let client = LLMClient::new("llama3.1").unwrap();
        let messages =
            vec![Message { role: "user".to_string(), content: "Say hello!".to_string() }];

        let result = block_on(async { client.chat_completion(&messages).await });

        // Note: This test will fail if Ollama is not running locally
        // In a real CI environment, we would mock the HTTP client
        if result.is_ok() {
            let response = result.unwrap();
            assert!(!response.is_empty());
            println!("Ollama response: {}", response);
        } else {
            println!("Skipping Ollama test - service not available");
        }
    }
}

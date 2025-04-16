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
    api_key: Option<String>,
}

#[derive(Debug)]
pub enum Error {
    EmptyModelName,
    EmptyMessages,
    InvalidProvider,
    RequestFailed(String),
    Other(String),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::EmptyModelName => write!(f, "Model name cannot be empty"),
            Error::EmptyMessages => write!(f, "Messages cannot be empty"),
            Error::InvalidProvider => write!(f, "Invalid provider configuration"),
            Error::RequestFailed(msg) => write!(f, "Request failed: {}", msg),
            Error::Other(msg) => write!(f, "Other error: {}", msg),
        }
    }
}

impl std::error::Error for Error {}

impl From<Error> for String {
    fn from(error: Error) -> Self {
        error.to_string()
    }
}

impl From<String> for Error {
    fn from(error: String) -> Self {
        Error::Other(error)
    }
}

fn get_required_var(name: &str) -> Result<String, String> {
    std::env::var(name).map_err(|e| format!("Missing required variable {}: {}", name, e))
}

impl LLMClient {
    /// Create a new LLM client
    pub fn new(model: &str) -> Result<Self, String> {
        // Validate model name
        if model.trim().is_empty() {
            return Err("Model name cannot be empty".to_string());
        }

        // Get API key if using OpenAI models
        let api_key = match model {
            "gpt-3.5-turbo" | "gpt-4" => Some(get_required_var("WAVS_ENV_OPENAI_API_KEY")?),
            _ => None, // Ollama doesn't need an API key
        };

        // Set API URL based on model type
        let api_url = match model {
            "gpt-3.5-turbo" | "gpt-4" => "https://api.openai.com/v1/chat/completions".to_string(),
            _ => format!(
                "{}/api/chat",
                env::var("WAVS_ENV_OLLAMA_API_URL")
                    .unwrap_or_else(|_| "http://localhost:11434".to_string())
            ),
        };

        Ok(Self { model: model.to_string(), api_url, api_key })
    }

    /// Send a chat completion request
    pub async fn chat_completion(&self, messages: &[Message]) -> Result<String, String> {
        // Validate messages
        if messages.is_empty() {
            return Err("Messages cannot be empty".to_string());
        }

        println!("Sending chat completion request:");
        println!("- Model: {}", self.model);
        println!("- Number of messages: {}", messages.len());
        println!("- First message: {:?}", messages.first());

        // Create request body with deterministic settings
        let body = if self.api_key.is_some() {
            // OpenAI format
            json!({
                "model": self.model,
                "messages": messages,
                "temperature": 0.0,
                "top_p": 1.0,
                "seed": 42,
                "stream": false,
                "max_tokens": 100  // Limit response length
            })
        } else {
            // Ollama chat format
            json!({
                "model": self.model,
                "messages": messages,
                "stream": false,
                "options": {
                    "temperature": 0.0,
                    "top_p": 0.1,
                    "seed": 42,
                    "num_ctx": 4096, // Context window size
                    "num_predict": 100  // Limit response length
                }
            })
        };

        println!("Request body: {}", serde_json::to_string_pretty(&body).unwrap());

        // Create request
        let mut req = Request::post(&self.api_url)
            .body(serde_json::to_vec(&body).unwrap().into_body())
            .map_err(|e| format!("Failed to create request: {}", e))?;

        // Add headers
        req.headers_mut().insert("Content-Type", HeaderValue::from_static("application/json"));
        req.headers_mut().insert("Accept", HeaderValue::from_static("application/json"));

        // Add authorization if needed
        if let Some(api_key) = &self.api_key {
            req.headers_mut().insert(
                "Authorization",
                HeaderValue::from_str(&format!("Bearer {}", api_key))
                    .map_err(|e| format!("Invalid API key format: {}", e))?,
            );
        }

        println!("Sending request to: {}", req.uri());

        // Send request
        let mut res =
            Client::new().send(req).await.map_err(|e| format!("Request failed: {}", e))?;

        println!("Received response with status: {}", res.status());

        if res.status() != 200 {
            let mut error_body = Vec::new();
            res.body_mut()
                .read_to_end(&mut error_body)
                .await
                .map_err(|e| format!("Failed to read error response: {}", e))?;
            let error_msg = format!(
                "API error: status {} - {}",
                res.status(),
                String::from_utf8_lossy(&error_body)
            );
            println!("Error: {}", error_msg);
            return Err(error_msg);
        }

        // Read response body
        let mut body_buf = Vec::new();
        res.body_mut()
            .read_to_end(&mut body_buf)
            .await
            .map_err(|e| format!("Failed to read response body: {}", e))?;

        let body =
            String::from_utf8(body_buf).map_err(|e| format!("Invalid UTF-8 in response: {}", e))?;

        println!("Raw response: {}", body);

        // Parse response based on provider
        let content = if self.api_key.is_some() {
            // Parse OpenAI response format
            #[derive(Deserialize)]
            struct ChatResponse {
                choices: Vec<Choice>,
            }

            #[derive(Deserialize)]
            struct Choice {
                message: Message,
            }

            let resp: ChatResponse = serde_json::from_str(&body)
                .map_err(|e| format!("Failed to parse OpenAI response: {}", e))?;

            resp.choices
                .first()
                .map(|choice| choice.message.content.clone())
                .ok_or_else(|| "No response choices returned".to_string())?
        } else {
            // Parse Ollama chat response format
            #[derive(Deserialize)]
            struct OllamaResponse {
                message: Message,
            }

            let resp: OllamaResponse = serde_json::from_str(&body)
                .map_err(|e| format!("Failed to parse Ollama response: {}", e))?;

            resp.message.content
        };

        println!("Successfully received response of length: {}", content.len());
        Ok(content)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use wstd::runtime::block_on;

    fn setup_test_env() {
        env::set_var("WAVS_ENV_OLLAMA_API_URL", "http://localhost:11434");
    }

    // Unit tests that don't require HTTP requests
    #[test]
    fn test_llm_client_initialization() {
        setup_test_env();

        let client = LLMClient::new("llama3.2");
        assert!(client.is_ok());
        let client = client.unwrap();
        assert_eq!(client.model, "llama3.2");
        assert!(client.api_url.contains("localhost:11434"));
        assert!(client.api_url.contains("/api/chat"));
    }

    #[test]
    fn test_new_client_empty_model() {
        let result = LLMClient::new("");
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Model name cannot be empty");

        let result = LLMClient::new("   ");
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Model name cannot be empty");
    }

    #[test]
    fn test_chat_completion_empty_messages() {
        let client = LLMClient::new("llama3.2").unwrap();
        let result = block_on(async { client.chat_completion(&[]).await });
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Messages cannot be empty"));
    }

    // Integration tests that require HTTP - only run in WASI environment
    #[cfg(all(test, target_arch = "wasm32"))]
    mod integration {
        use super::*;

        #[cfg(feature = "ollama")]
        mod ollama {
            use super::*;

            fn init() {
                env::set_var("RUST_LOG", "debug");
                env_logger::init();
            }

            #[test]
            fn test_ollama_chat_completion() {
                init();
                println!("Initializing Ollama client...");
                let client = LLMClient::new("llama3.2").unwrap();
                println!("Client initialized successfully");

                let messages = vec![
                    Message {
                        role: "system".to_string(),
                        content: "You are a helpful math assistant".to_string(),
                    },
                    Message { role: "user".to_string(), content: "What is 2+2?".to_string() },
                ];
                println!("Sending test message: {:?}", messages);

                let result = block_on(async {
                    match client.chat_completion(&messages).await {
                        Ok(response) => {
                            println!("Received successful response");
                            Ok(response)
                        }
                        Err(e) => {
                            println!("Error during chat completion: {}", e);
                            Err(e)
                        }
                    }
                });

                match result {
                    Ok(content) => {
                        println!("Test successful! Response: {}", content);
                        assert!(!content.is_empty());
                    }
                    Err(e) => {
                        println!("Test failed with error: {}", e);
                        panic!("Test failed: {}", e);
                    }
                }
            }
        }

        #[cfg(feature = "openai")]
        mod openai {
            use super::*;

            fn validate_config() -> Result<(), String> {
                // Check required variables
                let required_vars = ["WAVS_ENV_OPENAI_API_KEY"];

                for var in required_vars {
                    std::env::var(var)
                        .map_err(|_| format!("Missing required variable: {}", var))?;
                }
                Ok(())
            }

            #[test]
            fn test_openai_chat_completion() {
                // Validate environment configuration
                if let Err(e) = validate_config() {
                    println!("Skipping OpenAI test: {}", e);
                    return;
                }

                println!("Initializing OpenAI client...");
                let client = LLMClient::new("gpt-3.5-turbo").unwrap();
                println!("Client initialized successfully");

                let messages = vec![
                    Message {
                        role: "system".to_string(),
                        content: "You are a helpful math assistant".to_string(),
                    },
                    Message { role: "user".to_string(), content: "What is 2+2?".to_string() },
                ];
                println!("Sending test message: {:?}", messages);

                let result = block_on(async {
                    match client.chat_completion(&messages).await {
                        Ok(response) => {
                            println!("Received successful response");
                            Ok(response)
                        }
                        Err(e) => {
                            println!("Error during chat completion: {}", e);
                            Err(e)
                        }
                    }
                });

                match result {
                    Ok(content) => {
                        println!("Test successful! Response: {}", content);
                        assert!(!content.is_empty());
                    }
                    Err(e) => {
                        println!("Test failed with error: {}", e);
                        panic!("Test failed: {}", e);
                    }
                }
            }
        }
    }

    // Add a note about integration tests when running natively
    #[cfg(not(target_arch = "wasm32"))]
    #[test]
    fn test_integration_tests_note() {
        println!("Note: Integration tests are skipped when running natively.");
        println!("To run integration tests, use `cargo wasi test` or run in a WASI environment.");
    }
}

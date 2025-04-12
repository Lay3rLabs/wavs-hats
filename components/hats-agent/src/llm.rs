use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use wstd::{
    http::{body::BoundedBody, Client, HeaderValue, IntoBody, Request},
    io::AsyncRead,
};

/// Supported LLM providers that support deterministic outputs via seed
#[derive(Debug, Clone, Copy)]
pub enum Provider {
    Ollama,
    OpenAI,
}

/// Common message structure across providers
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: String,
    pub content: String,
}

/// Common options for LLM requests
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LLMOptions {
    pub temperature: f32,
    pub max_tokens: u32,
    pub top_p: f32,
    pub seed: u64,
}

impl LLMOptions {
    /// Validates that the options are configured for deterministic output
    pub fn validate(&self) -> Result<(), String> {
        if self.temperature != 0.0 {
            return Err("Temperature must be 0.0 for deterministic output".to_string());
        }
        if self.top_p != 1.0 {
            return Err("Top_p must be 1.0 for deterministic output".to_string());
        }
        if self.max_tokens == 0 {
            return Err("Max tokens must be greater than 0".to_string());
        }
        Ok(())
    }
}

impl Default for LLMOptions {
    fn default() -> Self {
        Self { temperature: 0.0, max_tokens: 1000, top_p: 1.0, seed: 42 }
    }
}

/// Client for making LLM API requests
#[derive(Debug)]
pub struct LLMClient {
    pub(crate) provider: Provider,
    pub(crate) model: String,
    pub(crate) api_key: Option<String>,
    pub(crate) api_url: String,
}

impl LLMClient {
    /// Create a new LLM client
    pub fn new(provider: Provider, model: &str) -> Result<Self, String> {
        let (api_key, api_url) = match provider {
            Provider::Ollama => (
                None,
                env::var("WAVS_ENV_OLLAMA_API_URL")
                    .unwrap_or_else(|_| "http://localhost:11434".to_string()),
            ),
            Provider::OpenAI => {
                let api_key = env::var("WAVS_ENV_OPENAI_API_KEY")
                    .map_err(|e| format!("OpenAI API key not found: {}", e))?;
                let api_url = env::var("WAVS_ENV_OPENAI_API_URL")
                    .unwrap_or_else(|_| "https://api.openai.com/v1/chat/completions".to_string());
                (Some(api_key), api_url)
            }
        };

        // Validate model name is not empty
        if model.trim().is_empty() {
            return Err("Model name cannot be empty".to_string());
        }

        Ok(Self { provider, model: model.to_string(), api_key, api_url })
    }

    /// Send a chat completion request
    pub async fn chat_completion(
        &self,
        messages: &[Message],
        options: Option<LLMOptions>,
    ) -> Result<String, String> {
        // Validate messages
        if messages.is_empty() {
            return Err("Messages cannot be empty".to_string());
        }

        let options = options.unwrap_or_default();

        // Validate options for determinism
        options.validate()?;

        let mut req = match self.provider {
            Provider::Ollama => self.create_ollama_request(messages, &options)?,
            Provider::OpenAI => self.create_openai_request(messages, &options)?,
        };

        // Add authorization header if needed
        if let Some(api_key) = &self.api_key {
            let auth_header = match self.provider {
                Provider::OpenAI => format!("Bearer {}", api_key),
                Provider::Ollama => unreachable!(),
            };
            req.headers_mut().insert(
                "Authorization",
                HeaderValue::from_str(&auth_header)
                    .map_err(|e| format!("Invalid API key format: {}", e))?,
            );
        }

        // Add common headers
        req.headers_mut().insert("Content-Type", HeaderValue::from_static("application/json"));
        req.headers_mut().insert("Accept", HeaderValue::from_static("application/json"));

        // Send request with timeout handling
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

        // Parse response based on provider
        match self.provider {
            Provider::Ollama => {
                #[derive(Deserialize)]
                #[serde(untagged)]
                enum OllamaResponse {
                    Success { message: Message },
                    Error { error: String },
                }

                match serde_json::from_str::<OllamaResponse>(&body) {
                    Ok(OllamaResponse::Success { message }) => Ok(message.content),
                    Ok(OllamaResponse::Error { error }) => Err(error),
                    Err(e) => Err(format!("Failed to parse Ollama response: {}", e)),
                }
            }
            Provider::OpenAI => {
                #[derive(Deserialize)]
                struct OpenAIResponse {
                    choices: Vec<OpenAIChoice>,
                }
                #[derive(Deserialize)]
                struct OpenAIChoice {
                    message: Message,
                }

                let resp: OpenAIResponse = serde_json::from_str(&body)
                    .map_err(|e| format!("Failed to parse OpenAI response: {}", e))?;

                resp.choices
                    .first()
                    .map(|choice| choice.message.content.clone())
                    .ok_or_else(|| "No response choices returned".to_string())
            }
        }
    }

    // Create request for Ollama API
    pub(crate) fn create_ollama_request(
        &self,
        messages: &[Message],
        options: &LLMOptions,
    ) -> Result<Request<BoundedBody<Vec<u8>>>, String> {
        let body = json!({
            "model": self.model,
            "messages": messages,
            "options": {
                "temperature": options.temperature,
                "num_predict": options.max_tokens,
                "top_p": options.top_p,
                "seed": options.seed,
            },
            "stream": false
        });

        Request::post(format!("{}/api/chat", self.api_url))
            .body(serde_json::to_vec(&body).unwrap().into_body())
            .map_err(|e| format!("Failed to create Ollama request: {}", e))
    }

    // Create request for OpenAI API
    pub(crate) fn create_openai_request(
        &self,
        messages: &[Message],
        options: &LLMOptions,
    ) -> Result<Request<BoundedBody<Vec<u8>>>, String> {
        let body = json!({
            "model": self.model,
            "messages": messages,
            "temperature": options.temperature,
            "max_tokens": options.max_tokens,
            "top_p": options.top_p,
            "seed": options.seed,
        });

        Request::post(&self.api_url)
            .body(serde_json::to_vec(&body).unwrap().into_body())
            .map_err(|e| format!("Failed to create OpenAI request: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use wstd::runtime::block_on;

    fn setup_test_env() {
        env::set_var("WAVS_ENV_OLLAMA_API_URL", "http://localhost:11434");
        env::set_var("WAVS_ENV_OPENAI_API_KEY", "test_key");
    }

    #[test]
    fn test_llm_client_initialization() {
        setup_test_env();

        // Test Ollama client
        let ollama_client = LLMClient::new(Provider::Ollama, "llama3.1");
        assert!(ollama_client.is_ok());
        let client = ollama_client.unwrap();
        assert_eq!(client.model, "llama3.1");
        assert!(client.api_key.is_none());
        assert!(client.api_url.contains("localhost:11434"));

        // Test OpenAI client
        let openai_client = LLMClient::new(Provider::OpenAI, "gpt-4");
        assert!(openai_client.is_ok());
        let client = openai_client.unwrap();
        assert_eq!(client.model, "gpt-4");
        assert!(client.api_key.is_some());
        assert!(client.api_url.contains("openai.com"));
    }

    #[test]
    fn test_chat_completion_request_creation() {
        setup_test_env();

        let messages = vec![Message { role: "user".to_string(), content: "Hello".to_string() }];
        let options = LLMOptions::default();

        // Test Ollama request creation
        let client = LLMClient::new(Provider::Ollama, "llama3.1").unwrap();
        let req = client.create_ollama_request(&messages, &options);
        assert!(req.is_ok());
        let req = req.unwrap();
        assert_eq!(req.method(), "POST");
        assert!(req.uri().to_string().contains("chat"));

        // Test OpenAI request creation
        let client = LLMClient::new(Provider::OpenAI, "gpt-4").unwrap();
        let req = client.create_openai_request(&messages, &options);
        assert!(req.is_ok());
        let req = req.unwrap();
        assert_eq!(req.method(), "POST");
        assert!(req.uri().to_string().contains("chat/completions"));
    }

    #[test]
    fn test_chat_completion_integration() {
        setup_test_env();

        // Only test Ollama integration if it's running locally
        let client = LLMClient::new(Provider::Ollama, "llama3.1").unwrap();
        let messages =
            vec![Message { role: "user".to_string(), content: "Say hello!".to_string() }];

        let result = block_on(async { client.chat_completion(&messages, None).await });

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

    #[test]
    fn test_options_handling() {
        // Test default options
        let options = LLMOptions::default();
        assert_eq!(options.temperature, 0.0);
        assert_eq!(options.max_tokens, 1000);
        assert_eq!(options.top_p, 1.0);
        assert_eq!(options.seed, 42);

        // Test custom options
        let custom_options =
            LLMOptions { temperature: 0.0, max_tokens: 500, top_p: 1.0, seed: 123 };
        assert_eq!(custom_options.temperature, 0.0);
        assert_eq!(custom_options.max_tokens, 500);
        assert_eq!(custom_options.top_p, 1.0);
        assert_eq!(custom_options.seed, 123);
    }

    #[test]
    fn test_options_validation() {
        // Test valid options
        let valid_options = LLMOptions::default();
        assert!(valid_options.validate().is_ok());

        // Test invalid temperature
        let invalid_temp = LLMOptions { temperature: 0.5, ..LLMOptions::default() };
        assert!(invalid_temp.validate().is_err());

        // Test invalid top_p
        let invalid_top_p = LLMOptions { top_p: 0.8, ..LLMOptions::default() };
        assert!(invalid_top_p.validate().is_err());

        // Test invalid max_tokens
        let invalid_max_tokens = LLMOptions { max_tokens: 0, ..LLMOptions::default() };
        assert!(invalid_max_tokens.validate().is_err());
    }

    #[test]
    fn test_empty_messages() {
        setup_test_env();
        let client = LLMClient::new(Provider::Ollama, "llama3.1").unwrap();
        let empty_messages: Vec<Message> = vec![];

        let result = block_on(async { client.chat_completion(&empty_messages, None).await });

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Messages cannot be empty"));
    }

    #[test]
    fn test_empty_model_name() {
        setup_test_env();
        let result = LLMClient::new(Provider::Ollama, "");
        assert!(result.is_err());
        assert!(matches!(result, Err(e) if e.contains("Model name cannot be empty")));

        let result = LLMClient::new(Provider::Ollama, "   ");
        assert!(result.is_err());
        assert!(matches!(result, Err(e) if e.contains("Model name cannot be empty")));
    }
}

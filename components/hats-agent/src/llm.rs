use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::env;
use wstd::{
    http::{Client, HeaderValue, IntoBody, Request},
    io::AsyncRead,
};

/// TODO: Better understand common api formats
/// Supported LLM providers
#[derive(Debug, Clone, Copy)]
pub enum Provider {
    Ollama,
    OpenAI,
    Anthropic,
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
    pub seed: Option<u64>,
}

impl Default for LLMOptions {
    fn default() -> Self {
        Self { temperature: 0.7, max_tokens: 1000, top_p: 0.95, seed: None }
    }
}

/// Client for making LLM API requests
pub struct LLMClient {
    provider: Provider,
    model: String,
    api_key: Option<String>,
    api_url: String,
}

impl LLMClient {
    /// Create a new LLM client
    pub fn new(provider: Provider, model: &str) -> Result<Self, String> {
        let (api_key, api_url) = match provider {
            Provider::Ollama => (
                None,
                env::var("OLLAMA_API_URL").unwrap_or_else(|_| "http://localhost:11434".to_string()),
            ),
            Provider::OpenAI => (
                Some(
                    env::var("OPENAI_API_KEY")
                        .map_err(|e| format!("OpenAI API key not found: {}", e))?,
                ),
                "https://api.openai.com/v1/chat/completions".to_string(),
            ),
            Provider::Anthropic => (
                Some(
                    env::var("ANTHROPIC_API_KEY")
                        .map_err(|e| format!("Anthropic API key not found: {}", e))?,
                ),
                "https://api.anthropic.com/v1/messages".to_string(),
            ),
        };

        Ok(Self { provider, model: model.to_string(), api_key, api_url })
    }

    /// Send a chat completion request
    pub async fn chat_completion(
        &self,
        messages: &[Message],
        options: Option<LLMOptions>,
    ) -> Result<String, String> {
        let options = options.unwrap_or_default();

        let mut req = match self.provider {
            Provider::Ollama => self.create_ollama_request(messages, &options)?,
            Provider::OpenAI => self.create_openai_request(messages, &options)?,
            Provider::Anthropic => self.create_anthropic_request(messages, &options)?,
        };

        // Add authorization header if needed
        if let Some(api_key) = &self.api_key {
            let auth_header = match self.provider {
                Provider::OpenAI => format!("Bearer {}", api_key),
                Provider::Anthropic => api_key.clone(),
                Provider::Ollama => unreachable!(),
            };
            req.headers_mut().insert("Authorization", HeaderValue::from_str(&auth_header).unwrap());
        }

        // Send request
        let mut res = Client::new().send(req).await.map_err(|e| e.to_string())?;

        if res.status() != 200 {
            return Err(format!("API error: status {}", res.status()));
        }

        // Read response body
        let mut body_buf = Vec::new();
        res.body_mut().read_to_end(&mut body_buf).await.unwrap();
        let body = String::from_utf8_lossy(&body_buf);

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
                Ok(resp.choices[0].message.content.clone())
            }
            Provider::Anthropic => {
                #[derive(Deserialize)]
                struct AnthropicResponse {
                    content: Vec<AnthropicContent>,
                }
                #[derive(Deserialize)]
                struct AnthropicContent {
                    text: String,
                }

                let resp: AnthropicResponse = serde_json::from_str(&body)
                    .map_err(|e| format!("Failed to parse Anthropic response: {}", e))?;
                Ok(resp.content[0].text.clone())
            }
        }
    }

    // Create request for Ollama API
    fn create_ollama_request(
        &self,
        messages: &[Message],
        options: &LLMOptions,
    ) -> Result<Request, String> {
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
    fn create_openai_request(
        &self,
        messages: &[Message],
        options: &LLMOptions,
    ) -> Result<Request, String> {
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

    // Create request for Anthropic API
    fn create_anthropic_request(
        &self,
        messages: &[Message],
        options: &LLMOptions,
    ) -> Result<Request, String> {
        // Convert messages to Anthropic format
        let system_message =
            messages.iter().find(|m| m.role == "system").map(|m| m.content.clone());
        let user_messages: Vec<_> = messages
            .iter()
            .filter(|m| m.role == "user" || m.role == "assistant")
            .map(|m| m.content.clone())
            .collect();

        let body = json!({
            "model": self.model,
            "messages": [{
                "role": "user",
                "content": user_messages.join("\n\n"),
            }],
            "system": system_message,
            "max_tokens": options.max_tokens,
            "temperature": options.temperature,
            "top_p": options.top_p,
        });

        Request::post(&self.api_url)
            .body(serde_json::to_vec(&body).unwrap().into_body())
            .map_err(|e| format!("Failed to create Anthropic request: {}", e))
    }
}

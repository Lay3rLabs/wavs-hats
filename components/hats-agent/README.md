# Hats Agent Component

## Run Ollama locally

```bash
ollama pull llama3.1
ollama serve
```

## LLM Client Configuration

The LLM client now supports configurable options through the `LLMConfig` struct. This allows you to customize the behavior of both OpenAI and Ollama requests.

### Basic Usage

```rust
// Create a client with default configuration
let client = LLMClient::new("llama3.2")?;

// Create a client with custom configuration
let config = LLMConfig::new()
    .temperature(0.7)
    .top_p(0.95)
    .seed(42)
    .max_tokens(Some(500));

let client = LLMClient::with_config("gpt-4", config)?;

// Create a client directly from JSON configuration
let config_json = r#"{
    "temperature": 0.2,
    "top_p": 0.9,
    "seed": 42,
    "max_tokens": 500,
    "context_window": 4096
}"#;

let client = LLMClient::from_json("llama3.2", config_json)?;
```

### Configuration Options

| Option           | Description                    | Default            |
| ---------------- | ------------------------------ | ------------------ |
| `temperature`    | Controls randomness (0.0-2.0)  | 0.0                |
| `top_p`          | Controls diversity (0.0-1.0)   | 1.0                |
| `seed`           | Seed for deterministic outputs | 42                 |
| `max_tokens`     | Maximum tokens to generate     | None (100 or 1024) |
| `context_window` | Context window size for Ollama | Some(4096)         |

### JSON Serialization

`LLMConfig` implements `serde::Serialize` and `serde::Deserialize`, allowing you to easily convert configurations to and from JSON:

```rust
// Serialize a configuration to JSON
let config = LLMConfig::new()
    .temperature(0.8)
    .seed(123);

let json_string = serde_json::to_string_pretty(&config)?;
println!("Config JSON: {}", json_string);

// Deserialize from JSON
let config_json = r#"{
    "temperature": 0.5,
    "top_p": 0.9,
    "seed": 42,
    "max_tokens": 200
}"#;

let config: LLMConfig = serde_json::from_str(config_json)?;
```

### Examples

```rust
// High creativity configuration
let creative_config = LLMConfig::new()
    .temperature(0.8)
    .top_p(0.9)
    .seed(123)
    .max_tokens(Some(1000));

// Deterministic configuration
let deterministic_config = LLMConfig::new()
    .temperature(0.0)
    .seed(42);

// Update existing client
let mut client = LLMClient::new("llama3.2")?;
client.update_config(creative_config);
```

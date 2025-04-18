use crate::llm::LLMClient;
use serde::{Deserialize, Serialize};

/// Function parameter for tool calls
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionParameter {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    pub parameter_type: Option<String>,
}

/// Function definition for tool calls
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Function {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parameters: Option<serde_json::Value>,
}

/// Tool definition for chat completions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tool {
    #[serde(rename = "type")]
    pub tool_type: String,
    pub function: Function,
}

/// Tool call for chat completions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCall {
    #[serde(default = "default_tool_id")]
    pub id: String,
    #[serde(rename = "type")]
    #[serde(default = "default_tool_type")]
    pub tool_type: String,
    pub function: ToolCallFunction,
}

/// Function call details
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCallFunction {
    pub name: String,
    #[serde(default)]
    #[serde(deserialize_with = "deserialize_arguments")]
    pub arguments: String,
}

/// Custom deserializer for function arguments that can be either a string or an object
fn deserialize_arguments<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: serde::Deserializer<'de>,
{
    use serde::de::Error;
    use serde_json::Value;

    // First try to deserialize as a Value to handle both string and object
    let value = Value::deserialize(deserializer)?;

    match value {
        // If it's already a string, return it directly
        Value::String(s) => Ok(s),

        // If it's an object, convert it to a JSON string
        Value::Object(_) => serde_json::to_string(&value)
            .map_err(|e| D::Error::custom(format!("Failed to serialize object to string: {}", e))),

        // For any other type, try to convert to string representation
        _ => serde_json::to_string(&value)
            .map_err(|e| D::Error::custom(format!("Failed to serialize value to string: {}", e))),
    }
}

/// Common message structure for chat completions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Message {
    pub role: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub content: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_calls: Option<Vec<ToolCall>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_call_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
}

/// Tool result message
impl Message {
    pub fn new_user(content: String) -> Self {
        Self {
            role: "user".to_string(),
            content: Some(content),
            tool_calls: None,
            tool_call_id: None,
            name: None,
        }
    }

    pub fn new_system(content: String) -> Self {
        Self {
            role: "system".to_string(),
            content: Some(content),
            tool_calls: None,
            tool_call_id: None,
            name: None,
        }
    }

    pub fn new_tool_result(tool_call_id: String, content: String) -> Self {
        Self {
            role: "tool".to_string(),
            content: Some(content),
            tool_calls: None,
            tool_call_id: Some(tool_call_id),
            name: None,
        }
    }
}

/// Helper functions to create common tools
pub mod builders {
    use super::*;
    use serde_json::json;

    /// Create a calculator tool
    pub fn calculator() -> Tool {
        Tool {
            tool_type: "function".to_string(),
            function: Function {
                name: "calculator".to_string(),
                description: Some(
                    "A simple calculator function for arithmetic operations".to_string(),
                ),
                parameters: Some(json!({
                    "type": "object",
                    "properties": {
                        "operation": {
                            "type": "string",
                            "enum": ["add", "subtract", "multiply", "divide"]
                        },
                        "a": {
                            "type": "number"
                        },
                        "b": {
                            "type": "number"
                        }
                    },
                    "required": ["operation", "a", "b"]
                })),
            },
        }
    }
}

/// Tool execution handlers
pub mod handlers {
    use super::*;
    use serde_json::Value;

    /// Execute a tool call and return the result
    pub fn execute_tool_call(tool_call: &ToolCall) -> Result<String, String> {
        match tool_call.function.name.as_str() {
            "calculator" => execute_calculator(tool_call),
            _ => Ok(format!("Unknown tool: {}", tool_call.function.name)),
        }
    }

    /// Execute calculator tool
    fn execute_calculator(tool_call: &ToolCall) -> Result<String, String> {
        // Parse the tool call arguments
        let args: Value = serde_json::from_str(&tool_call.function.arguments)
            .map_err(|e| format!("Failed to parse calculator arguments: {}", e))?;

        println!("Calculator received arguments: {:?}", args);

        // Extract operation
        let operation = args["operation"].as_str().ok_or("Missing operation")?;

        // Extract parameters, handling both number and string formats
        let a = if let Some(num) = args["a"].as_f64() {
            num
        } else if let Some(str_val) = args["a"].as_str() {
            str_val
                .parse::<f64>()
                .map_err(|_| format!("Invalid number for parameter a: {}", str_val))?
        } else {
            return Err("Missing parameter a".to_string());
        };

        let b = if let Some(num) = args["b"].as_f64() {
            num
        } else if let Some(str_val) = args["b"].as_str() {
            str_val
                .parse::<f64>()
                .map_err(|_| format!("Invalid number for parameter b: {}", str_val))?
        } else {
            return Err("Missing parameter b".to_string());
        };

        println!("Parsed calculator parameters: operation={}, a={}, b={}", operation, a, b);

        // Perform calculation
        let result = match operation {
            "add" => a + b,
            "subtract" => a - b,
            "multiply" => a * b,
            "divide" => {
                if b == 0.0 {
                    return Err("Division by zero".to_string());
                }
                a / b
            }
            _ => return Err(format!("Unsupported operation: {}", operation)),
        };

        // Format result
        Ok(format!("The result of {} {} {} is {}", a, operation, b, result))
    }
}

/// Default function for tool ID
fn default_tool_id() -> String {
    // Generate a simple random ID when none is provided (e.g., by Ollama)
    format!(
        "call_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis()
    )
}

/// Default function for tool type
fn default_tool_type() -> String {
    "function".to_string()
}

/// Process tool calls and generate a response
pub async fn process_tool_calls(
    client: &LLMClient,
    initial_messages: Vec<Message>,
    response: Message,
    tool_calls: Vec<ToolCall>,
) -> Result<String, String> {
    println!("Processing tool calls...");

    // Check if we're using Ollama based on the model name
    let model = client.get_model();
    let is_ollama =
        model.starts_with("llama") || model.starts_with("mistral") || !model.contains("gpt");

    // Process each tool call and collect the results
    let mut tool_results = Vec::new();
    for tool_call in &tool_calls {
        let tool_result = handlers::execute_tool_call(tool_call)?;
        println!("Tool result: {}", tool_result);
        tool_results.push(tool_result);
    }

    if is_ollama {
        // For Ollama: Don't make a second call, just use the tool result directly
        println!("Using direct tool result handling for Ollama");

        if tool_results.len() == 1 {
            Ok(tool_results[0].clone())
        } else {
            // For multiple tool calls, combine the results
            Ok(tool_results.join("\n"))
        }
    } else {
        // For OpenAI: Use the standard tool calls protocol
        println!("Using OpenAI-compatible tool call handling");
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
        for (i, tool_call) in tool_calls.iter().enumerate() {
            tool_messages
                .push(Message::new_tool_result(tool_call.id.clone(), tool_results[i].clone()));
        }

        // Get the final response incorporating all tool results
        let final_response = client.chat_completion_text(&tool_messages).await?;
        println!("Final response: {:?}", final_response);
        Ok(final_response)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tool_definition() {
        // Define a simple calculator tool
        let calculator_tool = builders::calculator();

        // Convert to JSON
        let json = serde_json::to_string(&calculator_tool).unwrap();

        // Ensure it can be serialized and deserialized correctly
        let deserialized: Tool = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.tool_type, "function");
        assert_eq!(deserialized.function.name, "calculator");
    }
}

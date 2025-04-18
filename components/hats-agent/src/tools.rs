use serde::{Deserialize, Serialize};
use serde_json::json;

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
    pub id: String,
    #[serde(rename = "type")]
    pub tool_type: String,
    pub function: ToolCallFunction,
}

/// Function call details
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCallFunction {
    pub name: String,
    pub arguments: String,
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

        // Extract operation and parameters
        let operation = args["operation"].as_str().ok_or("Missing operation")?;
        let a = args["a"].as_f64().ok_or("Missing parameter a")?;
        let b = args["b"].as_f64().ok_or("Missing parameter b")?;

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

// Import required crates
use std::time::{SystemTime, UNIX_EPOCH};

// WIT bindings will be generated here by cargo component build
wit_bindgen::generate! {
    world: wavs_component,
    path: "../wit"
}

// Implement the WAVS component interface
struct HatsToggleComponent;

impl exports::wavs::component::Guest for HatsToggleComponent {
    /// Run the hats toggle component with the given trigger action
    /// This function decodes the input data and calls check_hat_status
    fn run(action: exports::wavs::component::TriggerAction) -> Result<Option<Vec<u8>>, String> {
        // Log the trigger action
        println!("Running hats toggle component with trigger action: {:?}", action);

        // Parse the trigger ID
        let trigger_id =
            action.trigger_id.parse::<u64>().map_err(|e| format!("Invalid trigger ID: {}", e))?;
        println!("Trigger ID: {}", trigger_id);

        // Check if we have data to process
        let data = match action.data {
            Some(data) => data,
            None => return Err("No data provided in trigger action".to_string()),
        };

        // For this simple example, we'll just assume the data contains a hat ID
        // In a real implementation, you'd properly decode the ABI-encoded data
        // For now, we'll use a placeholder value
        let hat_id = 42;
        println!("Using placeholder data - Hat ID: {}", hat_id);

        // Call the hat status check function
        let is_active = check_hat_status(hat_id);

        // Encode the result as a simple array of bytes
        // In a real implementation, you'd properly ABI-encode the result
        // For now, we'll just create a simple encoding
        let mut result = Vec::new();

        // Encode the trigger ID as first 8 bytes (u64)
        result.extend_from_slice(&trigger_id.to_be_bytes());

        // Encode the active flag as a single byte
        result.push(if is_active { 1 } else { 0 });

        // Return the encoded result
        Ok(Some(result))
    }
}

/// Check if a hat should be active
/// This contains the actual hat status logic
fn check_hat_status(hat_id: u64) -> bool {
    // Log the call for debugging
    println!("Checking status for hat ID {}", hat_id);

    // Here you would implement your hat status logic
    // This could involve checking on-chain data, querying external APIs, etc.
    // For this example, we'll implement a simple check:

    // 1. Get the current timestamp
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    // 2. Example hat status check:
    // - For this demo: hats with even ID are always active
    // - Other hats are active if the current day is even
    let is_active = (hat_id % 2 == 0) || ((now / 86400) % 2 == 0);

    // Log the result
    println!("Status result for hat ID {}: active={}", hat_id, is_active);

    is_active
}

// Export the component
export!(HatsToggleComponent);

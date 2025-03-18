// Import required crates
use std::time::{SystemTime, UNIX_EPOCH};

// Import WAVS bindings
pub mod bindings;
use crate::bindings::{export, Guest, TriggerAction};

// Implement the WAVS component interface
struct HatsEligibilityComponent;

export!(HatsEligibilityComponent with_types_in bindings);

impl Guest for HatsEligibilityComponent {
    /// Run the hats eligibility component with the given trigger action
    /// This function decodes the input data and calls check_eligibility
    fn run(action: TriggerAction) -> Result<Option<Vec<u8>>, String> {
        // Log the trigger action
        println!("Running hats eligibility component with trigger action: {:?}", action);

        // Parse the trigger ID
        let trigger_id =
            action.trigger_id.parse::<u64>().map_err(|e| format!("Invalid trigger ID: {}", e))?;
        println!("Trigger ID: {}", trigger_id);

        // Check if we have data to process
        let data = match action.data {
            Some(data) => data,
            None => return Err("No data provided in trigger action".to_string()),
        };

        // For this simple example, we'll just assume the data contains a wearer address and hat ID
        // In a real implementation, you'd properly decode the ABI-encoded data
        // For now, we'll use placeholder values
        let wearer = "0x1234567890123456789012345678901234567890";
        let hat_id = 42;
        println!("Using placeholder data - Wearer: {}, Hat ID: {}", wearer, hat_id);

        // Call the eligibility check function
        let (eligible, standing) = check_eligibility(wearer, hat_id);

        // Encode the result as a simple array of bytes
        // In a real implementation, you'd properly ABI-encode the result
        // For now, we'll just create a simple encoding
        let mut result = Vec::new();

        // Encode the trigger ID as first 8 bytes (u64)
        result.extend_from_slice(&trigger_id.to_be_bytes());

        // Encode the eligible flag as a single byte
        result.push(if eligible { 1 } else { 0 });

        // Encode the standing flag as a single byte
        result.push(if standing { 1 } else { 0 });

        // Return the encoded result
        Ok(Some(result))
    }
}

/// Check if a wearer is eligible for a specific hat
/// This contains the actual eligibility logic
fn check_eligibility(wearer: &str, hat_id: u64) -> (bool, bool) {
    // Log the call for debugging
    println!("Checking eligibility for wearer {} and hat ID {}", wearer, hat_id);

    // Here you would implement your eligibility logic
    // This could involve checking on-chain data, querying external APIs, etc.
    // For this example, we'll implement a simple check:

    // 1. Get the current timestamp
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();

    // 2. Example eligibility check:
    // - For this demo: accounts that start with "0x1" are always eligible
    // - Other accounts are eligible if the current timestamp is even
    let is_eligible = wearer.starts_with("0x1") || (now % 2 == 0);

    // 3. Example standing check:
    // - For this demo: accounts that end with "5" are never in good standing
    // - Other accounts are in good standing
    let good_standing = !wearer.ends_with("5");

    // 4. If not in good standing, then not eligible
    let final_eligible = is_eligible && good_standing;

    // Log the result
    println!(
        "Eligibility result for wearer {} and hat ID {}: eligible={}, standing={}",
        wearer, hat_id, final_eligible, good_standing
    );

    (final_eligible, good_standing)
}

// Export the component
export!(HatsEligibilityComponent);

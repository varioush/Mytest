import csv
import json
import os

# Constants
TABLE_NAME = "YourTableName"  # Replace with your DynamoDB table name
OUTPUT_DIR = "batch_delete_files"  # Directory to save JSON files
BATCH_SIZE = 25  # Maximum items per batch

def generate_batch_delete_files_from_csv(csv_file_path, output_dir, batch_size):
    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # List to store DeleteRequest items
    delete_requests = []

    # Read the CSV file
    with open(csv_file_path, mode='r') as file:
        reader = csv.reader(file)
        header = next(reader)  # Skip header if present
        for row in reader:
            if row:  # Check if the row is not empty
                event_id = row[0]  # Assuming the first column is EVENTID
                time_value = row[1]  # Assuming the second column is Time

                # Create DeleteRequest for each item
                delete_requests.append({
                    "DeleteRequest": {
                        "Key": {
                            "EVENTID": {"S": event_id},
                            "Time": {"S": time_value}
                        }
                    }
                })

    # Split into batches and write to JSON files
    batch_files = []
    for i in range(0, len(delete_requests), batch_size):
        batch = delete_requests[i:i + batch_size]
        batch_filename = os.path.join(output_dir, f"batch-delete-{i // batch_size + 1}.json")
        
        # Create JSON structure
        batch_delete_json = {TABLE_NAME: batch}
        
        # Write batch to file
        with open(batch_filename, 'w') as json_file:
            json.dump(batch_delete_json, json_file, indent=4)

        batch_files.append(batch_filename)
        print(f"Generated: {batch_filename}")

    return batch_files

def print_aws_cli_commands(batch_files):
    print("\n### AWS CLI Commands ###")
    for batch_file in batch_files:
        print(f"aws dynamodb batch-write-item --request-items file://{batch_file}")
    print("\n### Notes ###")
    print("1. Copy and run each command in the terminal to execute the deletions.")
    print("2. Ensure you have the required IAM permissions for DynamoDB batch operations.")
    print("3. Verify the generated JSON files before executing the commands.")

# Example usage
csv_file_path = "data.csv"  # Replace with your CSV file path

# Generate JSON files
batch_files = generate_batch_delete_files_from_csv(csv_file_path, OUTPUT_DIR, BATCH_SIZE)

# Print AWS CLI commands
print_aws_cli_commands(batch_files)

Here’s the updated Python script, which generates the batch delete JSON files and outputs **AWS CLI commands** for executing them. The CLI commands are saved in a separate script file (`aws_commands.sh`) to make it easy to run them manually.

---

### **Python Script**
```python
import csv
import json
import os

# Input and Output Files
input_csv = "input.csv"  # Path to your input CSV file
output_folder = "batch_scripts"  # Folder to store batch scripts
table_name = "YourTableName"  # Replace with your DynamoDB table name
region = "us-east-1"  # AWS region
aws_script = "aws_commands.sh"  # Shell script for AWS CLI commands

# Ensure output folder exists
os.makedirs(output_folder, exist_ok=True)

# Function to process the CSV and generate batch delete scripts
def process_csv(input_csv, output_folder, table_name, aws_script, region):
    with open(input_csv, mode="r") as file:
        reader = csv.DictReader(file)
        records = {}

        # Group rows by ID
        for row in reader:
            id = row["ID"]
            if id not in records:
                records[id] = []
            records[id].append(row)

        # Prepare delete requests
        delete_requests = []
        for id, rows in records.items():
            # Sort rows by timein
            rows = sorted(rows, key=lambda x: x["timein"])

            # Identify valid entries: first NEW and first REJECTED
            valid = []
            if rows[0]["Status"] == "NEW":
                valid.append(rows[0])
                for row in rows[1:]:
                    if row["Status"] == "REJECTED":
                        valid.append(row)
                        break

            # Identify invalid rows for deletion
            invalid = [row for row in rows if row not in valid]
            for row in invalid:
                delete_requests.append({
                    "DeleteRequest": {
                        "Key": {
                            "ID": {"S": row["ID"]},
                            "timein": {"S": row["timein"]}
                        }
                    }
                })

        # Create AWS CLI script
        with open(aws_script, mode="w") as aws_file:
            aws_file.write("#!/bin/bash\n\n")
            aws_file.write(f"echo 'Executing batch delete commands in {region}'\n\n")

            # Split into batches of 25 and save each as a JSON file
            batch_number = 1
            for i in range(0, len(delete_requests), 25):
                batch = delete_requests[i:i+25]
                batch_file = os.path.join(output_folder, f"batch_script_{batch_number}.json")
                with open(batch_file, mode="w") as output_file:
                    json.dump({table_name: batch}, output_file, indent=2)

                # Add AWS CLI command for the current batch file
                aws_file.write(
                    f"aws dynamodb batch-write-item --region {region} --request-items file://{batch_file}\n"
                )
                print(f"Batch script saved to {batch_file}")
                batch_number += 1

        print(f"AWS CLI commands saved to {aws_script}")

# Run the function
process_csv(input_csv, output_folder, table_name, aws_script, region)
```

---

### **What This Script Does:**

1. **Parses the Input CSV:**
   - Groups rows by `ID` and sorts by `timein`.
   - Identifies valid rows (`NEW` and first `REJECTED`) and marks others for deletion.

2. **Generates Batch Delete JSON Files:**
   - Creates JSON files (`batch_script_1.json`, `batch_script_2.json`, etc.) with up to 25 `DeleteRequest` items per file.

3. **Creates an AWS CLI Script:**
   - Outputs AWS CLI commands to a file (`aws_commands.sh`) for executing the batch deletes.

---

### **Sample Output**

#### **Batch Delete JSON File (`batch_scripts/batch_script_1.json`):**
```json
{
  "YourTableName": [
    {
      "DeleteRequest": {
        "Key": {
          "ID": {"S": "1"},
          "timein": {"S": "2024-12-03T10:20:00Z"}
        }
      }
    },
    {
      "DeleteRequest": {
        "Key": {
          "ID": {"S": "1"},
          "timein": {"S": "2024-12-03T10:30:00Z"}
        }
      }
    }
  ]
}
```

#### **AWS CLI Script (`aws_commands.sh`):**
```bash
#!/bin/bash

echo 'Executing batch delete commands in us-east-1'

aws dynamodb batch-write-item --region us-east-1 --request-items file://batch_scripts/batch_script_1.json
aws dynamodb batch-write-item --region us-east-1 --request-items file://batch_scripts/batch_script_2.json
```

---

### **Instructions to Execute the Script**

1. **Run the Python Script:**
   ```bash
   python script.py
   ```

2. **Check Generated Files:**
   - JSON files (`batch_script_1.json`, `batch_script_2.json`, etc.) are stored in the `batch_scripts` folder.
   - The AWS CLI script (`aws_commands.sh`) is created in the same directory as the Python script.

3. **Execute the AWS CLI Commands:**
   - Run the generated script to execute all the batch delete commands:
     ```bash
     bash aws_commands.sh
     ```

4. **Verify Deletions:**
   - Use the following command to check the remaining records in the table:
     ```bash
     aws dynamodb scan --table-name YourTableName --region us-east-1
     ```

---

### **Benefits of This Approach**
1. Automates JSON file generation for DynamoDB batch delete.
2. Creates a shell script to simplify execution of AWS CLI commands.
3. Handles DynamoDB’s batch limit of 25 items automatically.

Let me know if you need further assistance!

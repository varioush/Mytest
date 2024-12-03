import csv

# Constants
MAX_QUERY_LENGTH = 8000  # Limit for each query
TABLE_NAME = "YourTableName"  # DynamoDB table name
STATUS_CONDITION = "STATUS='COMPLETED'"  # Condition for each eventid

def generate_queries_from_csv(csv_file_path):
    # Read CSV and collect unique event IDs
    unique_event_ids = set()

    with open(csv_file_path, mode='r') as file:
        reader = csv.reader(file)
        next(reader)  # Skip header if present
        for row in reader:
            if row:  # Check if row is not empty
                event_id = row[0]  # Assuming eventid is in the first column
                unique_event_ids.add(event_id)

    # Generate queries
    queries = []
    current_query = f"DELETE FROM {TABLE_NAME} WHERE "
    current_length = len(current_query)

    for event_id in unique_event_ids:
        condition = f"(EVENTID = '{event_id}' AND {STATUS_CONDITION})"
        if current_length + len(condition) + 4 > MAX_QUERY_LENGTH:  # 4 accounts for " OR "
            queries.append(current_query.rstrip(" OR "))
            current_query = f"DELETE FROM {TABLE_NAME} WHERE {condition} OR "
            current_length = len(current_query)
        else:
            current_query += f"{condition} OR "
            current_length += len(condition) + 4

    # Add the last query if there are remaining conditions
    if current_query.strip():
        queries.append(current_query.rstrip(" OR "))

    return queries


# Example usage
csv_file_path = "data.csv"  # Replace with your CSV file path
queries = generate_queries_from_csv(csv_file_path)

# Save or print the generated queries
for i, query in enumerate(queries, 1):
    print(f"Query {i}:\n{query}\n")

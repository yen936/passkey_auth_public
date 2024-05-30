import json
import boto3
from datetime import datetime


def lambda_handler(event, context):
    
    try:
        
        try:
            data = json.loads(event['body'])
        except KeyError:
            print("The key 'body' does not exist in the dictionary.")
            data = event
        print(data)
        
        # Extract the data from the POST request
        user_id = data['user_id']
        nonce = data['nonce']
        service = data['service']
        raw_timestamp = data['timestamp']
        
        parse_timestamp = datetime.strptime(raw_timestamp, "%Y-%m-%dT%H:%M:%S.%fZ")

        # Create a DynamoDB client
        dynamodb = boto3.client('dynamodb')

        # Write the data to the 'authNonces' table
        response = dynamodb.put_item(
            TableName='authNonces',
            Item={
                'nonce': {'S': f"{nonce}"},
                'user_id': {'S': user_id},
                'service': {'S': service},
                'timestamp': {'S': parse_timestamp.isoformat()}
            }
        )
        print(response)

        # Return a success message
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps(
                {'Success': f'f"{service}:{user_id} event added'}
                )
            
        }
    except Exception as e:
        # Return an error message
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps(
                {'Error': f'{str(e)}'}
                )
        }
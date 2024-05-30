import boto3
import json
from hashlib import sha256
# Custom Layer
import block_helper


def lambda_handler(event, context):
    try:

        # Input Validaiton section
        # ------------------------

        try:
            data = json.loads(event['body'])
        except KeyError:
            data = event
        print(f"input data: {data}")


        # Validate required keys in data
        required_keys = ['user_id', 'service', 'nonce', 'timestamp']
        for key in required_keys:
            if key not in data:
                return {
                    'statusCode': 400,
                    'body': f'Missing parameter: {key}',
                    'isSuccess': False
                }

        user_id = data['user_id']
        service = data['service']
        nonce = data['nonce']
        timestamp = data['timestamp']
        
       
        # Preform Operation  
        # ------------------------

        # get last block
        block_response = block_helper.get_last_block(user_id=user_id, service=service)
        
        # Get attributes of prev block
        prev_block_nonce = block_response['prev_block_nonce']
        prev_block_hash = block_response['prev_block_hash']
        prev_block_timestamp = block_response['prev_block_timestamp']
        
        # Make a DynamoDB client
        dynamodb = boto3.client('dynamodb')
        # Concatenate the service and user_id to form the DynamoDB key
        key = f"{service}:{user_id}"

        # make string for hash
        input_string = f"{service}:{user_id}:{prev_block_nonce}:{prev_block_timestamp}:{prev_block_hash}"
        output_hash = sha256(input_string.encode('utf-8')).hexdigest()
    
        # Write the data to the 'ledger' table
        dynamodb.put_item(
            TableName='dev_ledger',
            Item={
                'service_user' : {'S': key},
                'nonce': {'S': nonce},
                'timestamp': {'S': timestamp},
                'block_hash': {'S': output_hash}
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'isSuccess': True})
        }
        
        
    except Exception as e:
        print(f'top level error: {e}')
        # Return an error message
        return {
            'statusCode': 400,
            'body': f'Error: {str(e)}',
            'isSuccess': False
        }
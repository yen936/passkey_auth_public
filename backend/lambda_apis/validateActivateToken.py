import json
import boto3
from datetime import datetime
import secrets

# Initialize AWS DynamoDB client
dynamodb = boto3.client('dynamodb')

# DynamoDB Table Names
reg_tokens_table_name = 'regTokens'
keys_table_name = 'keys'

def lambda_handler(event, context):
    try:

        # Verify the inputs
        token = event['queryStringParameters']['token']
        
        # Get the entry from the 'regTokens' DynamoDB table
        response = dynamodb.get_item(
            TableName=reg_tokens_table_name,
            Key={
                'activation_token': {'S': token}
            }
        )
        
        if 'Item' not in response:
            return {
                'statusCode': 400,
                'body': json.dumps({'reason': 'Token not found'})
            }
        
        # Verify token expiration
        token_data = response['Item']
        expiration_time = token_data['expiration_time']['S']
        current_time = datetime.today().isoformat()
        
        if current_time > expiration_time:
            return {
                'statusCode': 400,
                'body': json.dumps({'reason': 'Timeout'})
            }
        service = token_data['service']['S']
        user_id = token_data['user_id']['S']

        # Update 'isActive' in the 'keys' DynamoDB table
        dynamodb.update_item(
            TableName=keys_table_name,
            Key={
                'service_user': {'S': f'{service}:{user_id}'}
            },
            UpdateExpression="SET isActive = :val",
            ExpressionAttributeValues={
                ':val': {'N': '1'}
            }
        )


        # write to auth event API ARN
        validateBlockARN = 'arn:aws:lambda:myuri:function:validateBlocks'
        nonce = secrets.token_hex(64)
        timestamp = datetime.today().strftime("%Y-%m-%dT%H:%M:%S.%fZ") # check datetime 
        l_client = boto3.client('lambda')
        wae_data = {
            'user_id': user_id,
            'service': service,
            'nonce': nonce,
            'timestamp': timestamp

        }
        response = l_client.invoke(FunctionName=validateBlockARN,
                                    InvocationType='Event', # asynchronous
                                    Payload=json.dumps(wae_data))
        
        # Prepare response data
        response_data = {
            'user_id': user_id,
            'service': service,
            'nonce': nonce,
            'timestamp': timestamp,
            'function': 'register'
        }
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps(response_data)
        }
    
    except Exception as e:
        exc_type = type(e).__name__
        line_number = e.__traceback__.tb_lineno
        function_name = lambda_handler.__name__ 
        print(f'{function_name} - top level error: {exc_type} at line {line_number}: {e}')
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps({'reason': str(e)})
        }

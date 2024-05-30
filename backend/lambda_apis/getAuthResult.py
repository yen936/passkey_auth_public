import boto3
import json
import time

def lambda_handler(event, context):
    try:
        
        nonce = event['queryStringParameters']['nonce']
        print(nonce)
        
        # get auth object from db
        # Make a DynamoDB client
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('authNonces')
        attribute = 'auth_result' # The attribute to check
  
        retry_count = 0
        
        # Loop until the attribute is populated or the maximum number of retries is reached
        while retry_count < 30:
            # Get the item
            response = table.get_item(
                Key={
                    'nonce': nonce
                }
            )
        
            # Check if the attribute exists
            if attribute in response['Item']:
                if response['Item']['auth_result'] is not None:
                    break
        
            # Increment the retry count
            retry_count += 1
        
            # Sleep for 1 second
            time.sleep(1)
        
        # Check if the item exists in the table
        if 'Item' not in response:
            raise Exception('nonce not found')
        item = response['Item']
        print(item)
        
        # TODO: verify that timetamp is still valid ~5min?
        
        # return auth response, with redirect url
        payload = {
             'auth_response': item['auth_result'],
             'redirect': 'https://myURI.com'
         }
        
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': json.dumps(payload)
        }
        
    except Exception as e:
        print(f'top level error: {e}')
        # Return an error message
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Origin':  '*',
                'Access-Control-Allow-Methods': 'GET'
            },
            'body': f'Error: {str(e)}'
        }

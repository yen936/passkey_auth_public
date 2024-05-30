import boto3
import json

def lambda_handler(event, context):
    try:

        # Input Validaiton 
        # ------------------------

        try:
            data = json.loads(event['body'])
        except KeyError:
            data = event

        print(data)

        # Validate required keys in data
        required_keys = ['user_id', 'service']
        for key in required_keys:
            if key not in data:
                return {
                    'statusCode': 400,
                    'body': f'Missing parameter: {key}',
                    'isSuccess': False
                }
           
        # Extract the data from the POST request
        user_id = data['user_id']
        service = data['service']

        
        # Preform Operation  
        # ------------------------
    
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('dev_ledger')
        # Concatenate the service and user_id to form the DynamoDB key
        key = f"{service}:{user_id}"

        response = table.query(
            KeyConditionExpression=boto3.dynamodb.conditions.Key('service_user').eq(key),
            ScanIndexForward=False,
            Limit=1
        )

        print(response)

        # Return Results  
        # ------------------------

        if 'Items' in response:
            print(response['Items'])
            # Check if record exists
            if response['Count'] != 0 :
                # Always want to return a single block
                block = response['Items'][0]

                service_user = block['service_user']
                nonce = block['nonce']
                block_hash = block['block_hash']
                timestamp = block['timestamp']

                # split service_user key into two vars
                service, user_id = service_user.split(":")
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'user_id': user_id,
                        'service': service,
                        'nonce': nonce,
                        'timestamp': timestamp,
                        'block_hash': block_hash
                    }),
                    'isSuccess': True
                }
            else:
                return {
                    'statusCode': 404,
                    'body': 'No matching record found',
                    'isSuccess': False
                }
        else:
            return {
                'statusCode': 500,
                'body': 'Internal server error',
                'isSuccess': False
            }
    except Exception as e:
        print(f'top level error: {e}')
        return {
            'statusCode': 400,
            'body': 'Other Error',
            'isSuccess': False
        }

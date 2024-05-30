import json
import boto3


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
        pub_key = data['pub_key']
        service = data['service']

        # Create a DynamoDB client
        dynamodb = boto3.client('dynamodb')

        # Write the data to the 'keys' table
        response = dynamodb.update_item(
            TableName='keys',
            Key={
                'service_user': {'S': f'{service}:{user_id}'}
            },
            UpdateExpression="SET pub_key = :val",
            ExpressionAttributeValues={
                ':val': {'S': pub_key}
            }
        )

        # Return a success message
        return {
            'statusCode': 200,
            'body': json.dumps(
                {'Success': f'{user_id} updated successfully'}
                )
        }
    except Exception as e:
        # Return an error message
        return {
            'statusCode': 500,
            'body': json.dumps(
                {'Error': f'{str(e)}'}
                )
        }
        
    
  
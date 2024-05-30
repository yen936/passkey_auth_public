import secrets
import json
import boto3
from datetime import datetime, timedelta

# Initialize AWS clients for SES and DynamoDB
ses_client = boto3.client('ses', region_name='us-east-2')
dynamodb_client = boto3.client('dynamodb')
# DynamoDB Table Name
ddb_table_name = 'regTokens'

# SES Email Configuration
sender_email = 'donotreply@mycompany.com'
# template_name = 'register_keys'


def get_user(service, user_id):
    """Gets a user object from a DynamoDB table called "keys".

    Args:
        service (str): The name of the service.
        user_id (str): The ID of the user.

    Returns:
        dict: The user object.
    """

    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table("keys")
    key = f"{service}:{user_id}"

    # Retrieve the item from the 'keys' table based on the key
    response = table.get_item( Key={ 'service_user': key } )

    # Check if the item exists in the table
    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': 'Service:user not found',
            'isSuccess': False
        }
    item = response['Item']
    return item


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
        required_keys = ['user_id', 'service']
        for key in required_keys:
            if key not in data:
                return {
                    'statusCode': 400,
                    'body': f'Missing parameter: {key}',
                    'isSuccess': False
                }

        user_id = data['user_id']
        service = data['service']

        # Preform Operation  
        # ------------------------

        # Get Email for user - sync 
        user_response = get_user(service=service, user_id=user_id)
        print(user_response)
    
        activation_token = secrets.token_urlsafe()

        # Make the activation URL
        activation_url = f'https://myappURI.amplifyapp.com/?token={activation_token}'

        # Calculate the expiration time for the activation link (e.g., 3 min from now)
        expiration_time = datetime.now() + timedelta(minutes=3)

        # Save the activation token and expiration time in DynamoDB
        # Write the data to the 'authNonces' table
        dynamodb_client.put_item(
            TableName=ddb_table_name,
            Item={
                'activation_token': {'S': activation_token},
                'user_id': {'S': user_id},
                'service': {'S': service},
                'expiration_time': {'S': expiration_time.isoformat()}
            }
        )

        bodyText = """Please open this link from your work computer to get your keys
        \n{}
        \nLink will expire in 3 minutes
        \n\n\nPowered by Cothura
        """.format(activation_url)

        # Send Email to address 
        ses_client.send_email(
            Destination={
                'ToAddresses': [user_response['email']]
            },
            Message={
                'Body': {
                    'Text': {
                        'Charset': 'UTF-8',
                        'Data': bodyText,
                    }
                },
                'Subject': {
                    'Charset': 'UTF-8',
                    'Data': f'Key Registration: {user_id} for {service}',
                },
            },
            Source='donotreply@cothura.com'
        )

        return {
            'statusCode': 200,
            'body': json.dumps('Email sent successfully')
        }
    
    except Exception as e:
            print(f'top level error: {e}')
            # Return an error message
            return {
                'statusCode': 400,
                'body': f'Error: {str(e)}',
                'isSuccess': False
            }

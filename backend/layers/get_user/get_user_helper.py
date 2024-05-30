import boto3

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
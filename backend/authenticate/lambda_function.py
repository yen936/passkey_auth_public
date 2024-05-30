import boto3
import json
import base64
from datetime import datetime

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_der_public_key
from cryptography.hazmat.backends import default_backend
from cryptography.exceptions import InvalidSignature 


def verify_signature(pub_key, sig, signed_data):
    """Verifies signature

    arguments:
        key -- public key for verification
        sig --signature on payload

    returns:
        Bool Verification as True; rejction as False
    """
    try:

        derdata = base64.b64decode(pub_key)
        pubkey = load_der_public_key(derdata, default_backend())

        decode_sig = base64.b64decode(sig)
        data = signed_data.encode('ascii')

        try:
            # returns None if verified 
            pubkey.verify(
                signature=decode_sig, 
                data=data, 
                signature_algorithm=ec.ECDSA(hashes.SHA256())
            )
            print("SUCCESS: Signature Verified!")
            return True
        except InvalidSignature:
            print('FAILED: Signature failed verification')
            return False
        
    except Exception as e:
        print('error in verify')
        return False


def verify_block(user_id, service, block_hash): 

    try:
        # Add ARN for verify ledger then TEST
        validateBlockARN = 'arn:aws:lambda:myARN:function:validateBlocks'
        l_client = boto3.client('lambda')
        block_payload = {
                "user_id": user_id,
                "service": service,
                "prev_block_hash": block_hash}
        response = l_client.invoke(FunctionName=validateBlockARN,
                                    InvocationType='RequestResponse', # synchronous
                                    Payload=json.dumps(block_payload))
        
        try:
            payload_data = json.loads(response['Payload'].read().decode('utf-8'))

            print(payload_data)
            print(type(payload_data))
                
            if payload_data['statusCode'] == 200:
                # Block hashs match
                print("SUCCESS: Block Hashs Match!")
                return True
            else:
                print("FAILURE: Block hashs dont match")
                # Block hashs dont match 
                return False 

        except Exception as payload_error:
            print(f'Error decoding payload: {payload_error}')
            return None
        
    except Exception as e:
        exc_type = type(e).__name__
        line_number = e.__traceback__.tb_lineno
        function_name = verify_block.__name__ 
        print(f'{function_name} - top level error: {exc_type} at line {line_number}: {e}')

        raise Exception(e)
    

def update_auth_event_status(nonce, auth_result, complete_datetime):
    # Create a DynamoDB client
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('authNonces')

    try:
        response = table.update_item(
            Key={'nonce': nonce},
            UpdateExpression="set auth_result = :r, result_timestamp = :t",
            ExpressionAttributeValues={
                ':r': auth_result,
                ':t': complete_datetime
            },
            ReturnValues="UPDATED_NEW")
        print(response)
        
    except Exception as e:
        exc_type = type(e).__name__
        line_number = e.__traceback__.tb_lineno
        function_name = update_auth_event_status.__name__ 
        print(f'{function_name} - top level error: {exc_type} at line {line_number}: {e}')
        print(f"Couldn't update auth status in {table.name}, heres why: {e}")
        raise Exception(e)
    

def handler(event, context):
    try:

        # Input Validaiton section
        # ------------------------

        try:
            data = json.loads(event['body'])
        except KeyError:
            print("The key 'body' does not exist in the dictionary.")
            data = event
        print(data)

        # Validate required keys in data
        required_keys = ['user_id', 'service', 'signature', 'nonce', 'prev_block_hash']
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
        signature = data['signature']
        nonce = data['nonce']
        prev_block_hash = data['prev_block_hash']

        print(f"prev_block_hash: {prev_block_hash}")
        
        # Preform Operation  
        # ------------------------
        
        # Make a DynamoDB client
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('keys')

        
        # Concatenate the service and user_id to form the DynamoDB key
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

        # TODO: check if user is isActive
        
        # Validate the signature of the nonce
        signature_response = verify_signature(pub_key=item['pub_key'], sig=signature, signed_data=nonce)

        # Validate new Block
     
        if signature_response:
            # Write the authenticaiton result to the db
            auth_event_complete_time = datetime.now().isoformat()
            update_auth_event_status(nonce=nonce, auth_result=signature_response, complete_datetime=auth_event_complete_time)
            
            # write to ledger 
            ledger_payload = {
                "user_id": user_id,
                "service": service,
                "nonce": nonce,
                "timestamp": auth_event_complete_time
            }

            
            # TODO: change to 'auth_result'
            ledger_payload['signature_result'] = signature_response

            return {
                'statusCode': 200,
                'body': json.dumps(ledger_payload)
            }
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'body': {
                            'signature_result': signature_response,
                            'ledger_block': False
                            },
                    'isSuccess': False
                    }
                )
            }
        
    except Exception as e:

        exc_type = type(e).__name__
        line_number = e.__traceback__.tb_lineno
        function_name = handler.__name__
        print(f'{function_name} - error: {exc_type} at line {line_number}: {e}')

        # Return an error message
        return {
            'statusCode': 400,
            'body': {
                'signature_result': False,
                'error': f'Error: {str(e)}'
                },
            'isSuccess': False
        }
    

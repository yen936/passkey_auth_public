import json
import boto3
import base64
import datetime
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import load_der_public_key
from cryptography.hazmat.backends import default_backend
from cryptography.exceptions import InvalidSignature 

# Custom Layer
import get_user

def verify_sig_key(pub_key, sig, signed_data):
    derdata = base64.b64decode(pub_key)
    pubkey = load_der_public_key(derdata, default_backend())

    decode_sig = base64.b64decode(sig)
    data = signed_data.encode('ascii')
    try:
        pubkey.verify(signature=decode_sig, data=data, signature_algorithm=ec.ECDSA(hashes.SHA256()))
        return True
    except InvalidSignature:
        return False

def handler(event, context):
    try:
        # Input Validaiton section
        # ------------------------

        try:
            data = json.loads(event['body'])
        except KeyError:
            data = event
        print(f"input data: {data}")

        # Validate required keys in data
        required_keys = ['user_id', 'service', 'signature', 'nonce', 'prev_block_hash']
        for key in required_keys:
            if key not in data:
                return {
                    'statusCode': 400,
                    'body': f'Missing parameter: {key}',
                    'isSuccess': False
                }

        user_id = data['user_id']
        service = data['service']
        signature = data['signature']
        nonce = data['nonce']
        # prev_block_hash = data['prev_block_hash']

        # Preform Operation  
        # ------------------------

        user_response = get_user(service=service, user_id=user_id)
        if user_response['isSuccess'] == False:
            return user_response


        decode_sig = base64.b64decode(signature)
        input_data = nonce.encode('ascii')

        signature_response = verify_sig_key(pub_key=user_response['pub_key'], sig=decode_sig, signed_data=input_data)

        if signature_response:
            return {
                'statusCode': 200,
                'body': json.dumps(signature_response)
            }

        else:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'body': {
                            'signature': signature_response,
                            #'ledger_block': block_response
                            },
                    'isSuccess': False
                    }
                )
            } 
    
    except Exception as e:
            print(f'top level error: {e}')
            # Return an error message
            return {
                'statusCode': 400,
                'body': f'Error: {str(e)}',
                'isSuccess': False
            }
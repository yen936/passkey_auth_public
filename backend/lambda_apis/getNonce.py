import json
import secrets
import boto3


def lambda_handler(event, context):
    
    # Generate Secure Nonce
    nonce = secrets.token_hex(64)
    
    
    # TODO implement
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Origin':  '*',
            'Access-Control-Allow-Methods': 'GET'
        },
        'body': json.dumps({'nonce': f'{nonce}'})
    }
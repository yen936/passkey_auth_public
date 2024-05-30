import boto3
import json

def get_last_block(user_id, service):
    getLastBlockARN = 'myarn:function:getLastBlockLedger'
    l_client = boto3.client('lambda')
    ledger_payload = {
        "user_id": user_id,
        "service": service,
    }
    response = l_client.invoke(FunctionName=getLastBlockARN,
                                InvocationType='RequestResponse',
                                Payload=json.dumps(ledger_payload))
    try:
        payload_data = json.loads(response['Payload'].read().decode('utf-8'))
    except Exception as payload_error:
        print(f'Error decoding payload: {payload_error}')
        return None

    if 'statusCode' in payload_data and 'body' in payload_data:
        status_code = payload_data['statusCode']
        body = json.loads(payload_data['body'])
        
        if status_code == 200 and 'user_id' in body and 'service' in body:
            prev_block_nonce = body['nonce']
            prev_block_hash = body['block_hash']
            prev_block_timestamp = body['timestamp']
            return {
                'prev_block_nonce': prev_block_nonce,
                'prev_block_hash': prev_block_hash,
                'prev_block_timestamp': prev_block_timestamp
            }
        else :
            raise Exception(body) 
    else:
        raise Exception(f"Invalid response format: {payload_data}")
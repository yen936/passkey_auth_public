import json
# Custom Layer
import block_helper


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
        required_keys = ['user_id', 'service', 'prev_block_hash']
        for key in required_keys:
            if key not in data:
                return {
                    'statusCode': 400,
                    'body': json.dumps({
                        'Missing parameter': key,
                        'isSuccess': False})
                }
            
        user_id = data['user_id']
        service = data['service']
        block_hash = data['prev_block_hash']
        
        # Preform Operation  
        # ------------------------

        # get last block
        block_response = block_helper.get_last_block(user_id=user_id, service=service)
        prev_block_hash = block_response['prev_block_hash']

        if block_hash == prev_block_hash:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    "message": "Block Hashs Match",
                    'isSuccess': True})
            }
        
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    "message": "Block Hashs dont Match",
                    'isSuccess': False})
            }

        
    except Exception as e:
        print(f'top level error: {e}')
    # Return an error message
    return {
        'statusCode': 400,
        'body': json.dumps({
            "message": f'Error: {str(e)}',
            'isSuccess': False})
    }


import boto3

def lambda_handler(event, context):
    client = boto3.client('codepipeline')
    response = client.start_pipeline_execution(name='your-pipeline-name')
    return {
        'statusCode': 200,
        'body': 'Pipeline triggered!'
    }

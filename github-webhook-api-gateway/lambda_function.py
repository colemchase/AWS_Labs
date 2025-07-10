import boto3

def lambda_handler(event, context):
    sns = boto3.client('sns')
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:940797399432:webhook-email-alert',
        Subject='GitHub Webhook Triggered',
        Message='A GitHub push triggered this Lambda via webhook.'
    )
    return {
        'statusCode': 200,
        'body': 'SNS email sent!'
    }

import base64
import boto3
import gzip
import json
import logging
import os
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def logpayload(event):
    logger.setLevel(logging.DEBUG)
    logger.debug(event['awslogs']['data'])
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_payload = json.loads(uncompressed_payload)
    return log_payload


def error_details(payload):
    log_events = payload['logEvents']
    logger.debug(payload)
    loggroup = payload['logGroup']
    logstream = payload['logStream']
    lambda_func_name = loggroup.split('/')
    logger.debug(f'LogGroup: {loggroup}')
    logger.debug(f'Logstream: {logstream}')
    logger.debug(f'Function name: {lambda_func_name}')
    logger.debug(log_events)
    return loggroup, logstream, log_events, lambda_func_name


def get_exclusion_patterns():
    """Get exclusion patterns from environment variable or use defaults."""
    patterns_str = os.environ.get('EXCLUSION_PATTERNS', '')
    if patterns_str:
        return [p.strip() for p in patterns_str.split(',')]
    return ["Rate Exceeded", "request rate is too high"]


def publish_message(loggroup, logstream, log_events, lambda_func_name):
    exclusion_patterns = get_exclusion_patterns()

    # Filter out individual log events that match exclusion patterns
    filtered_events = []
    for event in log_events:
        message = event['message']
        should_exclude = False
        
        for pattern in exclusion_patterns:
            if pattern in message:
                logger.info(f"Excluding log entry - matched pattern: {pattern}")
                logger.debug(f"Excluded message: {message[:100]}...")
                should_exclude = True
                break
        
        if not should_exclude:
            filtered_events.append(message)

    # If all errors were filtered out, don't send notification
    if not filtered_events:
        logger.info("All errors matched exclusion patterns - no notification sent")
        return

    # Reconstruct the error message with only non-excluded errors
    filtered_error_msg = ''.join(filtered_events)
    
    logger.info(f"Sending notification for {len(filtered_events)} error(s) (excluded {len(log_events) - len(filtered_events)})")

    # SNS publishing logic
    sns_arn = os.environ['snsARN']
    snsclient = boto3.client('sns')
    try:
        message = "\nLambda error summary\n\n"
        message += "##########################################################\n"
        message += "# LogGroup Name:- " + str(loggroup) + "\n"
        message += "# LogStream:- " + str(logstream) + "\n"
        message += "# Log Message:-\n"
        message += "# \t\t" + str(filtered_error_msg) + "\n"
        message += "##########################################################\n"

        snsclient.publish(
            TargetArn=sns_arn,
            Subject=f'Execution error for Lambda - {lambda_func_name}',
            Message=message
        )
        logger.info("Notification sent successfully")
    except ClientError as e:
        logger.error("An error occurred: %s" % e)


def lambda_handler(event, context):
    pload = logpayload(event)
    lgroup, lstream, log_events, lambdaname = error_details(pload)
    publish_message(lgroup, lstream, log_events, lambdaname)
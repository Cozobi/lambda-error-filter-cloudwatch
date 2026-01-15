import logging
import random

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


def lambda_handler(event, context):
    logger.setLevel(logging.DEBUG)

    # Generate different types of errors for testing
    error_types = [
        "This is a sample ERROR message - Database connection failed",
        "ERROR: Rate Exceeded - Too many requests to API",
        "ERROR: request rate is too high - Throttling applied",
        "CRITICAL: Memory allocation failed",
        "ERROR: Timeout connecting to external service"
    ]

    # Randomly log different errors
    selected_error = random.choice(error_types)
    logger.error(selected_error)

    return {
        'statusCode': 200,
        'body': f'Error logged: {selected_error}'
    }
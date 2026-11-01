import json
import logging
import os

import requests

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SOURCE_URL = os.environ.get("SOURCE_URL", "https://api.apis.guru/v2/providers.json")
MOUNT_PATH = os.environ.get("MOUNT_PATH", "/mnt/efs")
OUTPUT_FILE = os.path.join(MOUNT_PATH, "providers.json")


def lambda_handler(event, context):
    try:
        response = requests.get(SOURCE_URL, timeout=10)
        response.raise_for_status()
        data = response.json()

        with open(OUTPUT_FILE, "w") as file:
            json.dump(data, file, indent=2)
    except (requests.RequestException, ValueError, OSError):
        logger.exception("Failed to fetch %s and write to %s", SOURCE_URL, OUTPUT_FILE)
        raise  # surface the failure to Lambda metrics / EventBridge

    count = len(data.get("data", [])) if isinstance(data, dict) else len(data)
    logger.info("Wrote %d entries from %s to %s", count, SOURCE_URL, OUTPUT_FILE)

    return {"statusCode": 200, "body": f"Saved {count} entries to {OUTPUT_FILE}"}

import json
import requests
from bs4 import BeautifulSoup

def lambda_handler (event, context):

    url = "https://api.apis.guru/v2/providers.json"
    result = requests.get(url)  
    
    soup = BeautifulSoup(result.content, "html.parser")
    data = soup.text
    file_path = "/mnt/efs/providers.json"
    with open(file_path, "w") as file:
        file.write(data)

    return {"statusCode": 200, "body": "Data scraped and saved to EFS"}



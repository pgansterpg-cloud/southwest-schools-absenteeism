import requests
import time
from pprint import pprint 
import psycopg
import os
from dotenv import load_dotenv

url = "https://educationdata.urban.org/api/v1/schools/ccd/directory/2022/"
params = {"fips": 32}

response = requests.get(url, params=params, timeout=30)
data = response.json()

school_list = [] 

data = response.json()
ccsd_schools = [] 

for school in data["results"]: 
    if school["lea_name"] == "CLARK COUNTY SCHOOL DISTRICT": 
        ccsd_schools.append({"ncessch": school["ncessch"], "seasch": school["seasch"], "school_name": school["school_name"]})

# pprint(ccsd_schools[:3]) 

load_dotenv()

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        for ccsd_school in ccsd_schools: 
            cur.execute(
                "INSERT INTO school_id_crosswalk (ncessch, seasch, school_name) VALUES (%s, %s, %s)",
                (ccsd_school["ncessch"], ccsd_school["seasch"], ccsd_school["school_name"])
            )
import requests
import psycopg
import os
from dotenv import load_dotenv
from config import YEAR,FIPS,DISTRICT_NAME,BASE_URL

load_dotenv()

url = f"{BASE_URL}{YEAR}/"
params = {"fips": FIPS}
print(url) 

response = requests.get(url, params=params, timeout=30)
data = response.json()

ccsd_schools = [] 

for school in data["results"]: 
    if school["lea_name"] == DISTRICT_NAME: 
        ccsd_schools.append({"ncessch": school["ncessch"], "seasch": school["seasch"], "school_name": school["school_name"]})


with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        for ccsd_school in ccsd_schools: 
            cur.execute(
                """
                INSERT INTO school_id_crosswalk (ncessch, seasch, school_name) 
                VALUES (%s, %s, %s) 
                ON CONFLICT (ncessch) 
                DO UPDATE SET
                    seasch = EXCLUDED.seasch, 
                    school_name = EXCLUDED.school_name
                """,
                (ccsd_school["ncessch"], ccsd_school["seasch"], ccsd_school["school_name"])
            )
            
import requests
import psycopg
import os
from dotenv import load_dotenv
from config import YEAR,FIPS,BASE_URL

load_dotenv()

url = f"{BASE_URL}{YEAR}/"
params = {"fips": FIPS}
print(url) 

response = requests.get(url, params=params, timeout=30)
data = response.json()

nv_schools = [] 

for school in data["results"]: 
    nv_schools.append({"ncessch": school["ncessch"], "seasch": school["seasch"], "school_name": school["school_name"]})


with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        for nv_school in nv_schools: 
            cur.execute(
                """
                INSERT INTO school_id_crosswalk (ncessch, seasch, school_name) 
                VALUES (%s, %s, %s) 
                ON CONFLICT (ncessch) 
                DO UPDATE SET
                    seasch = EXCLUDED.seasch, 
                    school_name = EXCLUDED.school_name
                """,
                (nv_school["ncessch"], nv_school["seasch"], nv_school["school_name"])
            )

print(len(nv_schools))
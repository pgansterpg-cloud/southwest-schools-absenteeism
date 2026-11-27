import csv 
import os 
import psycopg
from dotenv import load_dotenv

load_dotenv()

with open("data/raw/nv_chronic_absenteeism_schools.csv", newline="", encoding="utf-8-sig") as f:
    reader = csv.reader(f)

    found_header = False
    ca_rows = []

    for row in reader:
        if not row: 
            continue
        elif row[0] == "Name":
            found_header = True
            continue
        elif not found_header:
            continue
    
        ca_rows.append(row)

with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE ca_raw;") 
        cur.executemany(
            """
            INSERT INTO ca_raw (school_name, school_year, org_code, district_name, ca_rate_all_students)
            VALUES (%s, %s, %s, %s, %s)
            """,
            ca_rows
            )

print(len(ca_rows))
print(ca_rows[:3])

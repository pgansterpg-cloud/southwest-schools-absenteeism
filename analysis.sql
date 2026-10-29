--Southwest Schools rate of chronically absent students,(Urban Institute Education Data Portal, 2022–23, schools in AZ, NM, NV and UT), 
--schools_raw was imported from the CSV as all TEXT columns before this file runs.

-- Build the clean table from the raw import:
--convert text columns to numbers, rename a few columns, and drop closed/inactive/future schools
CREATE TABLE schools_clean AS
SELECT ncessch, school_name, leaid, lea_name, state_location AS state, city_location AS city,
    school_level, school_type, charter, virtual, urban_centric_locale, school_status,
    NULLIF(enrollment, '')::INTEGER AS enrollment,
    NULLIF(students_chronically_absent, '')::INTEGER AS chronically_absent,
    latitude::NUMERIC AS latitude, longitude::NUMERIC AS longitude
FROM schools_raw
WHERE school_status NOT IN ('Inactive', 'Closed', 'Future');

ALTER TABLE schools_clean ADD PRIMARY KEY (ncessch);

-- Shows how many schools per state have both enrollment and absenteeism data
-- Result: AZ 1911, NM 832, NV 715, UT 1008
SELECT state, COUNT(*)
FROM schools_clean
WHERE chronically_absent IS NOT NULL AND enrollment IS NOT NULL
GROUP BY state;

-- Shows how many schools report more chronically absent students than enrolled students.
-- Result: 109 (mostly alternative and vocational schools)
SELECT COUNT(state)
FROM schools_clean
WHERE chronically_absent > enrollment;

-- This shows which schools are they, and which ones have the largest gap between enrollment and chronically_absent.
SELECT school_name, state, school_type, enrollment, chronically_absent
FROM schools_clean
WHERE chronically_absent > enrollment
ORDER BY chronically_absent - enrollment DESC;

-- A view that I created to get "Regular schools" only with valid enrollment, and no schools reporting more absent than enrolled.
CREATE VIEW schools_analysis AS
SELECT *
FROM schools_clean
WHERE school_type = 'Regular school'
	AND enrollment > 0
	AND enrollment >= chronically_absent;

-- Shows the rate and how many schools in each state
--NM 29.7, AZ 26.3, NV 25.2, UT 14.0
SELECT state, COUNT(*) AS schools,
	ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate 
FROM schools_analysis
GROUP BY state 
ORDER BY rate DESC; 

--One row per school level, with the number of schools and the absenteeism rate, highest rate first.
--High 25.0, Middle 24.0, Primary 22.8: absenteeism rises with grade level
SELECT school_level,COUNT(*)AS schools,
	ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate
FROM schools_analysis
GROUP BY school_level
ORDER BY rate DESC; 

--The same thing as above,this time broken down by state and level.
--Utah is the opposite: high schools 12.0 vs. elementary 16.2
SELECT state,school_level,COUNT(*)AS schools,
	ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate
FROM schools_analysis
GROUP BY state,school_level
ORDER BY state,rate DESC;

--The rate by urban_centric_locale, highest first.
--Rural, remote highest (31.8), Suburb, small lowest (16.1)
SELECT urban_centric_locale,COUNT(*)AS schools,
	ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate
FROM schools_analysis
GROUP BY urban_centric_locale
ORDER BY rate DESC,schools DESC;

-- All schools in nevada and the rate of chronically_absent 
--Clark 28.9, Washoe 19.2, state-sponsored charters 14.3
SELECT lea_name,COUNT(*)AS schools,
	ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate
FROM schools_analysis
WHERE state = 'NV'
GROUP BY lea_name
ORDER BY schools DESC ,rate DESC;

-- CCSD compared to the rest of Nevada
--Clark County 28.9 vs. rest of Nevada 18.6, about a 10-point gap
SELECT 
	CASE 
		WHEN lea_name = 'CLARK COUNTY SCHOOL DISTRICT' THEN 'Clark County' 
		ELSE 'Rest of Nevada' 
	END AS area,
  COUNT(*)AS schools,
  ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate
FROM schools_analysis
WHERE state = 'NV'
GROUP BY area
ORDER BY schools DESC ,rate DESC;

--creating the districts_raw table
CREATE TABLE districts_raw (
	year TEXT,
	leaid TEXT,
	lea_name TEXT,
	state_location TEXT,
	city_location TEXT,
	agency_type TEXT, 
	enrollment TEXT,
	number_of_schools TEXT, 
	urban_centric_locale TEXT
);

SELECT * FROM districts_raw

--making sure that all the district ids are unique
SELECT COUNT (DISTINCT leaid) AS distinct_ids, COUNT(*) AS total_rows 
FROM districts_raw;

--Making sure that all the IDs are the right length
SELECT COUNT(*) AS wrong_length
FROM districts_raw 
WHERE LENGTH(leaid) != 7;

--Show each distinct year value in districts_raw and how many rows have it 
SELECT year,COUNT(*) AS districts
FROM districts_raw
GROUP BY year; 

--How many districts are in each state
SELECT state_location,COUNT(*) AS districts 
FROM districts_raw 
GROUP BY state_location
ORDER BY districts DESC;

-- Found a mystery state 
SELECT * FROM districts_raw 
WHERE state_location = 'IL';

-- This district had zero schools and blank for enrollment so I decided to drop it 
SELECT COUNT(*) AS districts_kept 
FROM districts_raw 
WHERE state_location != 'IL'; 

--Shows where enrollment and schools are blank or zero 
SELECT 
	COUNT(*) FILTER (WHERE enrollment = '') AS enrollment_blank,
	COUNT(*) FILTER (WHERE enrollment = '0') AS enrollment_zero,
	COUNT(*) FILTER (WHERE number_of_schools = '') AS schools_blank,
	COUNT(*) FILTER (WHERE number_of_schools = '0') AS schools_zero
FROM districts_raw;

--Which kinds of agencies have 0 schools 
-- Many of these don't run schools directly: regional service agencies support other districts,
-- and some charter agencies were closed or not yet open in 2022.
SELECT agency_type, COUNT(*) FILTER (WHERE number_of_schools = '0') AS districts
FROM districts_raw 
GROUP BY agency_type
ORDER BY districts DESC;

--Creating a districts_clean table 
-- Build districts_clean: rename state/city, convert enrollment and number_of_schools to integers
-- (blanks become NULL), and leave out the Illinois-address agency (see check 4)
CREATE TABLE districts_clean AS
SELECT leaid,
	   lea_name,
	   agency_type,
	   urban_centric_locale,
	   year,
	   state_location AS state,
	   city_location AS city,
	   NULLIF(enrollment, '')::INTEGER AS enrollment,
       NULLIF(number_of_schools, '')::INTEGER AS number_of_schools
FROM districts_raw
WHERE state_location != 'IL';

ALTER TABLE districts_clean ADD PRIMARY KEY (leaid); 

-- SELECT COUNT(*) FROM districts_clean

-- SELECT COUNT(*)  
-- FROM districts_clean
-- WHERE enrollment IS NULL;

-- SELECT COUNT(*) 
-- FROM districts_clean 
-- WHERE number_of_schools = 0;

--every school matched exactly to one district. 
SELECT s.school_name,s.state,s.lea_name,d.agency_type,d.enrollment AS district_enrollment
FROM schools_analysis AS s 
INNER JOIN districts_clean AS d
ON s.leaid = d.leaid;

-- Showing that every school from schools_analysis has a district Result: 0 schools without a district
SELECT s.school_name,s.state,s.lea_name 
FROM schools_analysis AS s 
LEFT JOIN districts_clean AS d 
ON s.leaid = d.leaid 
WHERE d.leaid IS NULL 

-- Sanity check: with Nevada removed from districts, the same query returns 682 (all NV schools), so it does catch missing matches
SELECT s.school_name,s.state,s.lea_name
FROM schools_analysis AS s 
LEFT JOIN (SELECT * FROM districts_clean WHERE state <> 'NV') AS d
ON s.leaid = d.leaid
WHERE d.leaid IS NUll; 

SELECT d.agency_type, COUNT(*) AS districts
FROM districts_clean AS d
LEFT JOIN schools_analysis AS s 
ON d.leaid = s.leaid 
WHERE s.ncessch IS NULL 
GROUP BY d.agency_type 
ORDER BY districts DESC;

--calculate the chronic absenteeism rate for schools in a regular local school district vs a Charter agency
SELECT 
d.agency_type, 
COUNT(*) AS schools,
ROUND(SUM(s.chronically_absent) * 100.0 / SUM(s.enrollment), 1) AS rate 
FROM schools_analysis AS s 
JOIN districts_clean AS d 
ON s.leaid = d.leaid 
GROUP BY d.agency_type 
ORDER BY rate DESC;

-- finds the miising charter schools that are in regular school districts 
SELECT s.charter, d.agency_type, COUNT(*) AS schools 
FROM schools_analysis AS s 
JOIN districts_clean AS d 
ON s.leaid = d.leaid 
GROUP BY s.charter, d.agency_type 
ORDER BY schools DESC; 

-- 62 charter schools sit inside regular districts (Albuquerque 29, Clark 11, Washoe 10, plus a few others).
-- These are district-authorized charters: the school is a charter, but it reports under its local district's leaid.
-- So "charter school" (s.charter) and "charter agency" (d.agency_type) aren't the same thing:
-- comparing charter vs. non-charter schools should use s.charter (731), not agency_type (669). 
SELECT s.state, s.lea_name, COUNT(*) AS charter_schools 
FROM schools_analysis AS s 
JOIN districts_clean AS d
ON s.leaid = d.leaid 
WHERE s.charter = 'Yes' 
	AND d.agency_type = 'Regular local school district' 
GROUP BY s.state, s.lea_name 
ORDER BY charter_schools DESC; 

-- CASE STATEMENTS 

--Put every school into a tier base using it's own absenteeism rate, count how many schools 
--in each state fall into each tier 
SELECT 
school_name,
state,
ROUND(chronically_absent * 100.0 / enrollment, 1) AS rate,
	CASE
		WHEN chronically_absent * 100.0 / enrollment < 10 THEN 'Low' 
		WHEN chronically_absent * 100.0 / enrollment < 20 THEN 'Moderate' 
		WHEN chronically_absent * 100.0 / enrollment < 30 THEN 'High'
		ELSE 'Severe'
	END AS tier
FROM schools_analysis 
ORDER BY rate DESC;

--For each state count how many schools fall into each tier. 
SELECT 
state,
COUNT(*) AS schools, 
	CASE
		WHEN chronically_absent * 100.0 / enrollment < 10 THEN 'Low' 
		WHEN chronically_absent * 100.0 / enrollment < 20 THEN 'Moderate' 
		WHEN chronically_absent * 100.0 / enrollment < 30 THEN 'High'
		ELSE 'Severe'
	END AS tier
FROM schools_analysis
GROUP BY state,tier
ORDER BY state;

--Get enrollment size of each school then calculate the absenteeism rate for each size group
SELECT 
COUNT(*) AS schools,
ROUND(SUM(chronically_absent) * 100.0 / SUM(enrollment), 1) AS rate,
	CASE 
		WHEN enrollment < 300 THEN 'Small'
		WHEN enrollment < 700 THEN 'Medium'
		WHEN enrollment < 1500 THEN 'Large'
		ELSE 'Very Large'
	END AS size
FROM schools_analysis
GROUP BY size
ORDER BY rate DESC;



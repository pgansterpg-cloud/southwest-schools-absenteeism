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
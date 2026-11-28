DROP TABLE IF EXISTS ca_clean;

CREATE TABLE ca_clean AS (
SELECT 
	school_name, 
	school_year, 
	SPLIT_PART(school_year, '-', 2)::INT AS end_year,
	ca_rate_all_students,
	org_code,
	CASE 
		WHEN ca_rate_all_students = '-' THEN 'suppressed'
		WHEN ca_rate_all_students = '<5' THEN 'under 5%'
		WHEN ca_rate_all_students = '>95' THEN 'over 95%' 
	END AS rate_note,
	CASE 
		WHEN ca_rate_all_students IN ('-', '<5', '>95') THEN NULL
		ELSE ca_rate_all_students::NUMERIC
	END AS ca_rate,
	CASE 
		WHEN district_name = '' THEN 'state' 
		WHEN district_name = 'State' THEN 'district' 
		WHEN district_name = 'Clark' THEN 'school'
		ELSE 'unknown'
	END AS row_level
FROM ca_raw
);
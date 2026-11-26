SELECT count(*) FROM school_id_crosswalk

SELECT * FROM school_id_crosswalk 
LIMIT 5;

SELECT COUNT(cw.ncessch)
FROM school_id_crosswalk AS cw 
JOIN schools_clean AS sc 
ON cw.ncessch = sc.ncessch;

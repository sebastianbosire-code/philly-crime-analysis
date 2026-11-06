-- =====================================================================
-- Philadelphia Crime Incidents Analysis (2020 to 2025)
-- Author: Sebastian Ombati
-- Data: Philadelphia Police Department, Part 1 & Part 2 Crime Incidents
--       via OpenDataPhilly (metadata.phila.gov)
-- Tools: MySQL, VS Code, Power BI
-- =====================================================================


-- =====================================================================
-- STEP 1: SETUP
-- =====================================================================

-- Combine six yearly files into one table (900K+ rows)
USE crime_data;

CREATE TABLE crime_incidents_all AS
SELECT * FROM `2020` UNION ALL
SELECT * FROM `2021` UNION ALL
SELECT * FROM `2022` UNION ALL
SELECT * FROM `2023` UNION ALL
SELECT * FROM `2024` UNION ALL
SELECT * FROM `2025`;


-- =====================================================================
-- STEP 2: DATA CLEANING
-- =====================================================================

-- Check for coordinates that fall outside Philadelphia
SELECT COUNT(*) AS outlier_rows
FROM crime_incidents_all
WHERE lat NOT BETWEEN 39.8 AND 40.15
   OR lng NOT BETWEEN -75.3 AND -74.95;

-- Set outlier coordinates to NULL so they don't distort the map
UPDATE crime_incidents_all
SET lat = NULL, lng = NULL
WHERE lat NOT BETWEEN 39.8 AND 40.15
   OR lng NOT BETWEEN -75.3 AND -74.95;

-- Check for missing hour values by year
-- (Found 102,175 blanks, 100,619 of them in 2023)
SELECT YEAR(dispatch_date) AS yr,
       SUM(hour IS NULL) AS blank_hour
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY yr
ORDER BY yr;

-- Rebuild missing hour values from dispatch time
UPDATE crime_incidents_all
SET hour = HOUR(dispatch_time)
WHERE hour IS NULL;

-- Note: dispatch_date_time is stored in UTC, so the yearly downloads
-- include 55 incidents dated 12/31/2019 (local time). Queries below
-- filter on dispatch_date (local time) to keep only 2020 to 2025.


-- =====================================================================
-- STEP 3: VALIDATION
-- =====================================================================

-- Confirm no missing hours remain (should return 0)
SELECT COUNT(*) AS remaining_blank_hours
FROM crime_incidents_all
WHERE hour IS NULL;

-- Yearly totals (used to check the Power BI dashboard)
SELECT YEAR(dispatch_date) AS crime_year,
       COUNT(*) AS total_incidents
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY crime_year
ORDER BY crime_year;


-- =====================================================================
-- STEP 4: ANALYSIS
-- =====================================================================

-- Top 10 most common crime types
SELECT text_general_code,
       COUNT(*) AS incident_count
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY text_general_code
ORDER BY incident_count DESC
LIMIT 10;

-- Yearly trend for key crime types
SELECT YEAR(dispatch_date) AS yr,
       COUNT(*) AS total,
       SUM(text_general_code = 'Motor Vehicle Theft') AS car_theft,
       SUM(text_general_code = 'Homicide - Criminal') AS homicide,
       SUM(text_general_code = 'Robbery Firearm') AS gun_robbery,
       SUM(text_general_code = 'Aggravated Assault Firearm') AS gun_assault
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY yr
ORDER BY yr;

-- Which crime types changed the most from 2020 to 2025?
SELECT text_general_code,
       SUM(CASE WHEN YEAR(dispatch_date) = 2020 THEN 1 ELSE 0 END) AS count_2020,
       SUM(CASE WHEN YEAR(dispatch_date) = 2025 THEN 1 ELSE 0 END) AS count_2025
FROM crime_incidents_all
GROUP BY text_general_code
ORDER BY (count_2025 - count_2020) ASC;

-- Peak hours of the day (dispatch time)
SELECT hour,
       COUNT(*) AS incident_count
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY hour
ORDER BY incident_count DESC
LIMIT 3;

-- Day of the week and hour of the day heatmap
SELECT DAYNAME(dispatch_date) AS day_of_week,
       HOUR(dispatch_time) AS hour_of_day,
       COUNT(*) AS incident_count
FROM crime_incidents_all
WHERE YEAR(dispatch_date) BETWEEN 2020 AND 2025
GROUP BY day_of_week, hour_of_day
ORDER BY FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
               'Friday', 'Saturday', 'Sunday'), hour_of_day;

-- Before/after comparison by district: violent gun crime in the early
-- pandemic years vs. the most recent years
SELECT dc_dist,
       CASE WHEN YEAR(dispatch_date) IN (2020, 2021) THEN 'Early (2020-2021)'
            ELSE 'Recent (2024-2025)' END AS period,
       COUNT(*) AS violent_incident_count
FROM crime_incidents_all
WHERE text_general_code IN ('Homicide - Criminal', 'Robbery Firearm',
                            'Aggravated Assault Firearm')
  AND YEAR(dispatch_date) IN (2020, 2021, 2024, 2025)
GROUP BY dc_dist, period
ORDER BY dc_dist, period;

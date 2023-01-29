/* Create table with offense groups,
   types and crime catregory */
CREATE TABLE spd_offense(
             report_number  VARCHAR(50) NOT NULL, 
             offense_id     BIGINT NOT NULL PRIMARY KEY, 
             crime_category VARCHAR(100), 
             offense_group  VARCHAR(100), 
             offense        VARCHAR(100)
);

/* Import data from excel file */
COPY spd_offense(
     report_number, offense_id, crime_category, 
     offense_group, offense
)
FROM '/Users/leilaizmailova/Desktop/SPD Project/SPD_offense.csv'
DELIMITER ','
CSV HEADER;


/* Create table with offense date and time */
CREATE TABLE spd_datetime(
             offense_id    BIGINT NOT NULL, 
             offense_date  DATE, 
             offense_year  INT NOT NULL, 
             offense_month VARCHAR(15), 
             offense_time  TIME, 
             FOREIGN KEY (offense_id) REFERENCES spd_offense(offense_id)
);


/* Import data from excel file */
COPY spd_datetime(
     offense_id, offense_date, offense_year, 
     offense_month, offense_time
)
FROM '/Users/leilaizmailova/Desktop/SPD Project/SPD_datetime.csv'
DELIMITER ','
CSV HEADER;


/* Delete rows where offense years 
   not between 2018 and 2023 */
DELETE FROM spd_datetime 
WHERE       offense_year 
            NOT BETWEEN 2018 AND 2023;



/* Replace missed times with null value,
   because downloaded data has default set offense time */
UPDATE spd_datetime
SET    offense_time = NULL
WHERE  offense_time = '00:00:00'
       OR offense_time = '12:00:00' ;



/* Create table with offense location */
CREATE TABLE spd_location(
             offense_id   BIGINT NOT NULL,
             offense_area VARCHAR(100) NOT NULL,
             address      VARCHAR(100),
             longitude    VARCHAR(100),
             latitude     VARCHAR(100),
             FOREIGN KEY (offense_id) REFERENCES spd_offense(offense_id)
);


/* Import data from excel file */
COPY spd_location(
     offense_id,
     offense_area,
     address,
     longitude,
     latitude
)
FROM '/Users/leilaizmailova/Desktop/SPD Project/SPD_location.csv'
DELIMITER ','
CSV HEADER;


/* Create table with national holiday dates */
CREATE TABLE spd_holidays(
             holiday_name VARCHAR(50) NOT NULL 
             holidays_2022 DATE, 
             holidays_2021 DATE, 
             holidays_2020 DATE, 
             holidays_2019 DATE, 
             holidays_2018 DATE
);

/* Import data from excel file */
COPY spd_holidays(
     holiday_name, holidays_2022, holidays_2021, 
     holidays_2020, holidays_2019, holidays_2018
)
FROM '/Users/leilaizmailova/Desktop/SPD Project/SPD_holidays.csv'
CSV HEADER;

/* Union all US national holidays for 
   last 5 years dates into one column */
CREATE VIEW all_holidays AS
SELECT      holidays_2022 AS holidays_date,
            holiday_name 
FROM        spd_holidays
UNION ALL
            SELECT holidays_2021, 
                   holiday_name 
            FROM   spd_holidays
UNION ALL
            SELECT holidays_2020, 
                   holiday_name 
            FROM   spd_holidays
UNION ALL
            SELECT holidays_2019, 
                   holiday_name 
            FROM   spd_holidays
UNION ALL
            SELECT holidays_2018, 
                   holiday_name 
            FROM   spd_holidays;

/* Create view with joined data 
   and offense tables */
CREATE VIEW spd_prep_offenses AS 
SELECT      o.offense_id, 
            o.crime_category, 
            o.offense_group,
            o.offense,
            l.offense_area,
            d.offense_date, 
            d.offense_year,
            d.offense_time
FROM        spd_offense AS o 
LEFT JOIN   spd_datetime AS d 
            ON o.offense_id = d.offense_id 
LEFT JOIN   spd_location AS l 
            ON o.offense_id = l.offense_id 
WHERE       offense_date IN (
            SELECT holidays_date 
            FROM   all_holidays
);


/* Create table with added holidays names 
   to view created above */
SELECT    s.*, h.holiday_name
INTO      all_holidays_offenses
FROM      spd_prep_offenses AS s
LEFT JOIN all_holidays AS h 
          ON s.offense_date = h.holidays_date;


/* Total quantity of offenses on holidays */
SELECT COUNT(offense_id) AS offense_quantity
FROM   all_holidays_offenses;


/* Total quantity of offenses on days 
   except for holidays */
SELECT COUNT(offense_id) AS offense_quantity
FROM   spd_all_data
WHERE  offense_date NOT IN(SELECT offense_date
                           FROM spd_holiday_offenses);


/* Show Top 3 holidays with 
   the highest number of offenses */
SELECT holiday_name,
       COUNT(offense_id) AS offense_quantity
FROM   spd_holiday_offenses
WHERE  offense_year BETWEEN 2018 AND 2023
GROUP  BY holiday_name
ORDER  BY offense_quantity DESC
LIMIT 3;

/* Show sum of offenses by year */
SELECT offense_year,
       COUNT(offense_id) AS offense_numbers
FROM   spd_holiday_offenses
GROUP  BY offense_year
ORDER  BY offense_year DESC;

/* Number of offenses by Area */
SELECT offense_area,
       COUNT(offense_id) AS offense_quantity
FROM   spd_holiday_offenses
GROUP  BY offense_area
ORDER  BY offense_quantity DESC;

/* Show 5 highest offense types on holidays */
SELECT offense AS offense_type,
       COUNT(offense_id) AS offense_numbers
FROM   spd_holiday_offenses
WHERE  offense_year BETWEEN 2018 AND 2023
GROUP  BY offense
ORDER  BY offense_numbers DESC
LIMIT 5;

/* Most frequent time of offenses */
SELECT offense_time,
       COUNT(offense_id) AS offense_numbers
FROM   spd_holiday_offenses
WHERE  offense_year >= 2018  
       AND offense_time IS NOT NULL
GROUP  BY offense_time
ORDER  BY offense_numbers DESC;

/* Most weapon law violations are on holidays */
SELECT offense_area,
       offense,
       COUNT(offense_id) AS offense_numbers
FROM   spd_holiday_offenses
WHERE  offense_group LIKE ('WEAPON%')
       AND offense_year BETWEEN
       2018-01-01 AND 2023-01-01
GROUP  BY offense, offense_area
ORDER  BY offense_numbers DESC;


/* Create view with sum of offense numbers */
CREATE VIEW offense_sum AS
SELECT holiday_name, 
       offense_area, 
       offense_time, 
       COUNT(offense_id) AS offense_numbers
FROM   spd_holiday_offenses
GROUP  BY offense_area, 
          holiday_name,
          offense_time;



/* Most frequent offense time by area
   Some areas may have more than 1 frequent offense time
   Querying time approx. 135 s */
SELECT offense_area, 
       offense_time, 
       offense_numbers 
FROM   offense_sum AS ver1
WHERE  offense_numbers = (SELECT MAX(ver2.offense_numbers)
                          FROM   offense_sum AS ver2
                          WHERE  ver1.offense_area = ver2.offense_area
                                 AND offense_time IS NOT NULL 
)
       AND offense_time IS NOT NULL
;


/* Most frequent offense time on each holiday
   Some holidays may have more than 1 frequent offense time */
SELECT offense_sum.holiday_name, 
       offense_sum.offense_time, 
       holiday_rank.max_offense_numbers 
FROM  (SELECT holiday_name,  
              MAX (offense_numbers) AS max_offense_numbers 
       FROM   offense_sum
       WHERE  offense_time IS NOT NULL
       GROUP  BY holiday_name
)      AS holiday_rank
INNER JOIN offense_sum
           ON offense_sum.holiday_name = holiday_rank.holiday_name 
           AND offense_sum.offense_numbers = holiday_rank.max_offense_numbers
WHERE  offense_time IS NOT NULL
ORDER  BY holiday_name, 
          offense_time;


/* Most frequent offenses in Capitol Hill 
   and Downtown Area */
SELECT offense_sum.offense_area, 
       offense_sum.offense_time, 
       holiday_rank.max_offense_numbers 
FROM  (SELECT offense_area,  
       MAX    (offense_numbers) AS max_offense_numbers 
       FROM   offense_sum
       WHERE  offense_area IN ('DOWNTOWN COMMERCIAL', 'CAPITOL HILL') 
              AND offense_time IS NOT NULL
       GROUP  BY offense_area
)      AS holiday_rank
INNER JOIN offense_sum
       ON offense_sum.offense_area = holiday_rank.offense_area 
       AND offense_sum.offense_numbers = holiday_rank.max_offense_numbers
WHERE  offense_time IS NOT NULL 
ORDER  BY offense_area, 
          offense_time;

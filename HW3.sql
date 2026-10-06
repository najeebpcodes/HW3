-- Name: Najeeb Phillips | Assignment: HW3
-- Global Energy and Power Plants | MySQL 8.0 or later (CTEs required).
-- Run SECTION A first. Then import all six CSVs into EXISTING tables.
-- Import order: countries, operators, fuel_types, power_plants,
-- generation_records, emission_metrics. Map CSV headings to lowercase columns.
-- Do not run SECTION A again after importing; tables already exist.
-- No DROP statements: existing data is never erased by this script.
-- ON UPDATE CASCADE propagates changes to referenced keys.
-- ON DELETE RESTRICT protects country/operator/fuel records used by children.
-- ON DELETE CASCADE removes generation/emission logs when a plant is deleted.
-- Composite keys enforce one record per plant per year in each history table.
-- CTE names and output-column aliases are used; there are NO table aliases.
-- Q4/Q5 include all operators/countries; absent totals are displayed as zero.

-- SECTION A: SCHEMA
CREATE DATABASE IF NOT EXISTS global_energy;
USE global_energy;

CREATE TABLE countries (
    countrycode CHAR(3) NOT NULL,
    countryname VARCHAR(100) NOT NULL,
    continent VARCHAR(50) NOT NULL,
    PRIMARY KEY (countrycode)
);

CREATE TABLE operators (
    operatorid INT NOT NULL,
    operatorname VARCHAR(150) NOT NULL,
    headquarterscountry CHAR(3) NOT NULL,
    PRIMARY KEY (operatorid),
    FOREIGN KEY (headquarterscountry) REFERENCES countries(countrycode)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE fuel_types (
    fuelid INT NOT NULL,
    fuelcategory VARCHAR(50) NOT NULL,
    fuelname VARCHAR(50) NOT NULL,
    PRIMARY KEY (fuelid)
);

CREATE TABLE power_plants (
    plantid INT NOT NULL,
    plantname VARCHAR(150) NOT NULL,
    countrycode CHAR(3) NOT NULL,
    operatorid INT NOT NULL,
    fuelid INT NOT NULL,
    capacitymw DECIMAL(12,2) NOT NULL,
    commissionyear SMALLINT NOT NULL,
    PRIMARY KEY (plantid),
    FOREIGN KEY (countrycode) REFERENCES countries(countrycode)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (operatorid) REFERENCES operators(operatorid)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (fuelid) REFERENCES fuel_types(fuelid)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE generation_records (
    plantid INT NOT NULL,
    year SMALLINT NOT NULL,
    generationgwh DECIMAL(15,2) NOT NULL,
    PRIMARY KEY (plantid, year),
    FOREIGN KEY (plantid) REFERENCES power_plants(plantid)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE emission_metrics (
    plantid INT NOT NULL,
    year SMALLINT NOT NULL,
    co2emissionstonnes DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (plantid, year),
    FOREIGN KEY (plantid) REFERENCES power_plants(plantid)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- SECTION B: Run only after importing CSV files.

-- Problem 1
SELECT power_plants.plantname, countries.countryname,
       operators.operatorname, fuel_types.fuelcategory,
       fuel_types.fuelname, power_plants.capacitymw,
       power_plants.commissionyear
FROM power_plants
JOIN countries ON power_plants.countrycode = countries.countrycode
JOIN operators ON power_plants.operatorid = operators.operatorid
JOIN fuel_types ON power_plants.fuelid = fuel_types.fuelid
ORDER BY power_plants.capacitymw DESC;

-- Problem 2
SELECT power_plants.plantname, power_plants.countrycode,
       generation_records.year, generation_records.generationgwh
FROM power_plants
JOIN generation_records
    ON power_plants.plantid = generation_records.plantid
WHERE generation_records.year = 2024
ORDER BY generation_records.generationgwh DESC;

-- Problem 3
SELECT power_plants.plantname, power_plants.countrycode,
       generation_records.year, generation_records.generationgwh,
       emission_metrics.co2emissionstonnes
FROM power_plants
JOIN generation_records
    ON power_plants.plantid = generation_records.plantid
JOIN emission_metrics
    ON generation_records.plantid = emission_metrics.plantid
   AND generation_records.year = emission_metrics.year
WHERE generation_records.year = 2024
ORDER BY emission_metrics.co2emissionstonnes ASC;

-- Problem 4
WITH operator_generation AS (
    SELECT power_plants.operatorid,
           SUM(generation_records.generationgwh) AS total_generation_gwh
    FROM power_plants
    JOIN generation_records
        ON power_plants.plantid = generation_records.plantid
    GROUP BY power_plants.operatorid
)
SELECT operators.operatorname, operators.headquarterscountry,
       COALESCE(operator_generation.total_generation_gwh, 0) AS total_generation_gwh
FROM operators
LEFT JOIN operator_generation
    ON operators.operatorid = operator_generation.operatorid
ORDER BY total_generation_gwh DESC;

-- Problem 5
WITH country_generation AS (
    SELECT power_plants.countrycode,
           SUM(generation_records.generationgwh) AS total_generation_gwh
    FROM power_plants
    JOIN generation_records
        ON power_plants.plantid = generation_records.plantid
    GROUP BY power_plants.countrycode
),
country_emissions AS (
    SELECT power_plants.countrycode,
           SUM(emission_metrics.co2emissionstonnes) AS total_co2_emissions_tonnes
    FROM power_plants
    JOIN emission_metrics
        ON power_plants.plantid = emission_metrics.plantid
    GROUP BY power_plants.countrycode
)
SELECT countries.countryname,
       COALESCE(country_generation.total_generation_gwh, 0) AS total_generation_gwh,
       COALESCE(country_emissions.total_co2_emissions_tonnes, 0) AS total_co2_emissions_tonnes
FROM countries
LEFT JOIN country_generation
    ON countries.countrycode = country_generation.countrycode
LEFT JOIN country_emissions
    ON countries.countrycode = country_emissions.countrycode
ORDER BY total_generation_gwh DESC;

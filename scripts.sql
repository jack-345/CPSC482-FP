-- cleaning nasa dataset after running into header problems
CREATE OR REPLACE TABLE `jou-cpsc482-finalproject.project_sets.cleaned_nasa` AS
SELECT Year, SAFE_CAST(Jan AS FLOAT64) AS Jan, SAFE_CAST(Feb AS FLOAT64) AS Feb, SAFE_CAST(JD AS FLOAT64) AS annual_temp_anomaly
FROM `jou-cpsc482-finalproject.project_sets.nasa2`
WHERE Year IS NOT NULL;

-- query to join both tables into one
CREATE OR REPLACE TABLE `jou-cpsc482-finalproject.project_sets.full` AS
WITH cleaned_nasa AS (
  SELECT Year, SAFE_CAST(JD AS FLOAT64) AS annual_temp_anomaly
  FROM `jou-cpsc482-finalproject.project_sets.nasa2`
  WHERE Year IS NOT NULL
)
SELECT 
  g.Entity,
  g.Year,
  SAFE_CAST(g.`Electricity from fossil fuels _TWh_` AS FLOAT64) AS fossil_fuel_usage,
  SAFE_CAST(g.`Electricity from renewables _TWh_` AS FLOAT64) AS renewable_usage,
  SAFE_CAST(g.`Renewable energy share in the total final energy consumption _%_` AS FLOAT64) AS renewable_percentage,
  SAFE_CAST(g.`Value_co2_emissions_kt_by_country` AS FLOAT64) AS co2_emissions,
  c.annual_temp_anomaly
FROM 
  `jou-cpsc482-finalproject.project_sets.global_sustain` g
JOIN 
  cleaned_nasa c ON CAST(g.Year AS INT64) = c.Year
WHERE 
  g.`Value_co2_emissions_kt_by_country` IS NOT NULL;

-- converting individual country values per year into totals per year
CREATE OR REPLACE TABLE `jou-cpsc482-finalproject.project_sets.global_aggregate` AS
SELECT Year,SUM(fossil_fuel_usage) AS total_fossil_fuel, SUM(renewable_usage) AS total_renewable, SUM(co2_emissions) AS total_co2, ANY_VALUE(annual_temp_anomaly) AS annual_temp_anomaly
FROM `jou-cpsc482-finalproject.project_sets.full`
GROUP BY Year
ORDER BY Year;

-- creating linear regression model
CREATE OR REPLACE MODEL `jou-cpsc482-finalproject.project_sets.country_prediction_model`
OPTIONS(model_type='linear_reg', input_label_cols=['co2_emissions']) AS
SELECT 
  Entity,
  fossil_fuel_usage, 
  renewable_usage, 
  renewable_percentage,
  annual_temp_anomaly, 
  co2_emissions 
FROM `jou-cpsc482-finalproject.project_sets.full`;

-- predicting US emissions for 2030
SELECT predicted_co2_emissions
FROM
  ML.PREDICT(MODEL `jou-cpsc482-finalproject.project_sets.country_prediction_model`,
    (
      SELECT 
        'United States' AS Entity, 
        3000.0 AS fossil_fuel_usage, 
        1500.0 AS renewable_usage, 
        40.0 AS renewable_percentage,
        1.5 AS annual_temp_anomaly -- Projected anomaly for 2030
    )
  );
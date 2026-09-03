CREATE DATABASE linkedin_jobs;
USE linkedin_jobs;

CREATE TABLE job_postings (
  job_id                     BIGINT,
  company_name               VARCHAR(300),
  title                      VARCHAR(300),
  location                   VARCHAR(200),
  company_id                 BIGINT,
  views                      INT,
  formatted_work_type        VARCHAR(100),
  applies                    INT,
  remote_allowed             VARCHAR(10),
  formatted_experience_level VARCHAR(100),
  listed_time                BIGINT,
  work_type                  VARCHAR(100),
  normalized_salary          VARCHAR(50)
);

CREATE TABLE companies (
  company_id    BIGINT,
  name          VARCHAR(300),
  company_size  VARCHAR(100),
  city          VARCHAR(100),
  country       VARCHAR(100)
);

CREATE TABLE salaries (
  salary_id         INT,
  job_id            BIGINT,
  max_salary        VARCHAR(50),
  med_salary        VARCHAR(50),
  min_salary        VARCHAR(50),
  pay_period        VARCHAR(50),
  currency          VARCHAR(20),
  compensation_type VARCHAR(100)
);

CREATE TABLE job_skills (
  job_id  BIGINT,
  domain  VARCHAR(100)
);

CREATE TABLE job_industries (
  job_id      BIGINT,
  industry_id INT
);

SET SESSION sql_mode = '';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/job_postings_clean.csv'
INTO TABLE job_postings
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/companies_clean.csv'
INTO TABLE companies
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/salaries_clean.csv'
INTO TABLE salaries
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/job_skills_clean.csv'
INTO TABLE job_skills
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/job_industries_clean.csv'
INTO TABLE job_industries
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM job_postings;
SELECT * FROM job_postings LIMIT 5;

SELECT 'job_postings'   AS table_name, COUNT(*) AS total FROM job_postings   UNION ALL
SELECT 'job_skills',                   COUNT(*)           FROM job_skills      UNION ALL
SELECT 'job_industries',               COUNT(*)           FROM job_industries  UNION ALL
SELECT 'companies',                    COUNT(*)           FROM companies       UNION ALL
SELECT 'salaries',                     COUNT(*)           FROM salaries;

-- See actual data in each table
SELECT * FROM job_postings LIMIT 3;
SELECT * FROM job_skills LIMIT 3;
SELECT * FROM companies LIMIT 3;
SELECT * FROM salaries LIMIT 3;

-- Q1: Top  most in-demand domains across all job postings
-- Business Question: Which domain appear in the most job listings?

SELECT 
  domain,
  COUNT(*) AS job_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM job_skills), 1) AS pct_of_market
FROM job_skills
GROUP BY domain
ORDER BY job_count DESC
LIMIT 20;

-- Q2: Work type distribution
-- Business Question: How is the market split between work arrangements?

SELECT 
  formatted_work_type AS work_type,
  COUNT(*) AS job_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total,
  ROUND(AVG(CAST(normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(AVG(CAST(applies AS DECIMAL(10,2))), 1) AS avg_applicants
FROM job_postings
WHERE formatted_work_type IS NOT NULL
  AND formatted_work_type != ''
GROUP BY formatted_work_type
ORDER BY job_count DESC;

-- Q3: Salary by experience level
-- Business Question: How much does salary grow from entry to senior level?

SELECT 
  formatted_experience_level AS experience_level,
  COUNT(*) AS job_count,
  ROUND(AVG(CAST(normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(MIN(CAST(normalized_salary AS DECIMAL(12,2))), 0) AS min_salary,
  ROUND(MAX(CAST(normalized_salary AS DECIMAL(12,2))), 0) AS max_salary
FROM job_postings
WHERE formatted_experience_level IS NOT NULL
  AND formatted_experience_level != ''
  AND normalized_salary IS NOT NULL
  AND normalized_salary != ''
GROUP BY formatted_experience_level
ORDER BY avg_salary DESC;

-- Q4: Top 15 hiring locations
-- Business Question: Which cities/states have the most job opportunities?

SELECT 
  location,
  COUNT(*) AS job_count,
  ROUND(AVG(CAST(normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM job_postings
WHERE location IS NOT NULL
  AND location != ''
GROUP BY location
ORDER BY job_count DESC
LIMIT 15;

-- Q5: Top 15 companies by job postings
-- Business Question: Which companies are hiring most aggressively?

SELECT 
  jp.company_name,
  COUNT(*) AS total_postings,
  ROUND(AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(AVG(CAST(jp.applies AS DECIMAL(10,2))), 1) AS avg_applicants,
  jp.formatted_work_type AS primary_work_type
FROM job_postings jp
WHERE jp.company_name IS NOT NULL
  AND jp.company_name != ''
GROUP BY jp.company_name, jp.formatted_work_type
ORDER BY total_postings DESC
LIMIT 15;

-- Q6: Average salary per job domain
-- Business Question: Which job function pays the highest salary?

SELECT 
  js.domain,
  COUNT(DISTINCT js.job_id) AS job_count,
  ROUND(AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(MIN(CAST(jp.normalized_salary AS DECIMAL(12,2))), 0) AS min_salary,
  ROUND(MAX(CAST(jp.normalized_salary AS DECIMAL(12,2))), 0) AS max_salary,
  RANK() OVER (ORDER BY AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))) DESC) AS salary_rank
FROM job_skills js
JOIN job_postings jp ON js.job_id = jp.job_id
WHERE jp.normalized_salary IS NOT NULL
  AND jp.normalized_salary != ''
GROUP BY js.domain
HAVING COUNT(DISTINCT js.job_id) > 20
ORDER BY avg_salary DESC;

-- Q7: Competition analysis — how many applicants per job posting per domain
-- Business Question: Which domains are most and least competitive to get into?

SELECT 
  js.domain,
  COUNT(DISTINCT js.job_id) AS job_count,
  ROUND(AVG(CAST(jp.applies AS DECIMAL(10,2))), 1) AS avg_applicants,
  ROUND(AVG(CAST(jp.views AS DECIMAL(10,2))), 1) AS avg_views,
  ROUND(AVG(CAST(jp.applies AS DECIMAL(10,2))) /
        NULLIF(AVG(CAST(jp.views AS DECIMAL(10,2))), 0) * 100, 1) AS apply_rate_pct
FROM job_skills js
JOIN job_postings jp ON js.job_id = jp.job_id
WHERE jp.applies IS NOT NULL AND jp.applies != ''
  AND jp.views IS NOT NULL AND jp.views != ''
GROUP BY js.domain
HAVING COUNT(DISTINCT js.job_id) > 10
ORDER BY avg_applicants DESC;

-- Q8: Domain Opportunity Score
-- Business Question: Which domains offer the best salary-to-competition ratio?

SELECT 
  js.domain,
  COUNT(DISTINCT js.job_id) AS job_count,
  ROUND(AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))), 0) AS avg_salary,
  ROUND(AVG(CAST(jp.applies AS DECIMAL(10,2))), 1) AS avg_applicants,
  ROUND(
    AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))) / 
    NULLIF(AVG(CAST(jp.applies AS DECIMAL(10,2))), 0)
  , 0) AS opportunity_score,
  CASE 
    WHEN AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))) > 40000 
     AND AVG(CAST(jp.applies AS DECIMAL(10,2))) < 8
    THEN 'Sweet Spot'
    WHEN AVG(CAST(jp.normalized_salary AS DECIMAL(12,2))) > 40000 
    THEN 'High Pay'
    WHEN AVG(CAST(jp.applies AS DECIMAL(10,2))) < 5
    THEN 'Low Competition'
    ELSE 'Standard'
  END AS opportunity_label
FROM job_skills js
JOIN job_postings jp ON js.job_id = jp.job_id
WHERE jp.normalized_salary IS NOT NULL AND jp.normalized_salary != ''
  AND jp.applies IS NOT NULL AND jp.applies != ''
GROUP BY js.domain
HAVING COUNT(DISTINCT js.job_id) > 10
ORDER BY opportunity_score DESC;


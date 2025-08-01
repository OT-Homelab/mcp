-- Create the uns_raw table
CREATE TABLE uns_raw (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    dataType VARCHAR(50) NOT NULL,
    value NUMERIC NOT NULL,
    timestamp BIGINT NOT NULL,
    qualityCode INTEGER NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX idx_uns_raw_name ON uns_raw(name);
CREATE INDEX idx_uns_raw_timestamp ON uns_raw(timestamp);
CREATE INDEX idx_uns_raw_name_timestamp ON uns_raw(name, timestamp);

-- Generate 6 months of factory data (January 2025 - June 2025)
-- This will create approximately 43,800 records across multiple production lines

WITH 
-- Define the time series (hourly data for 6 months)
time_series AS (
    SELECT 
        1735689600000::bigint + (n::bigint * 3600000::bigint) as ts -- Start: Jan 1, 2025 00:00:00 UTC, increment by 1 hour
    FROM generate_series(0, 4383) n -- 6 months * 30.5 days * 24 hours ≈ 4,383 hours
),

-- Define factory hierarchy and metrics
factory_metrics AS (
    SELECT * FROM (VALUES
        -- Site Roosendaal - Area Packaging
        ('homelab-uns/site-roosendaal/area-packaging/line-901/mes/current-shift/OEE Percentage', 'Float', 75.0, 95.0),
        ('homelab-uns/site-roosendaal/area-packaging/line-901/mes/current-shift/Production Count', 'Integer', 450, 650),
        ('homelab-uns/site-roosendaal/area-packaging/line-901/mes/current-shift/Downtime Minutes', 'Integer', 0, 45),
        ('homelab-uns/site-roosendaal/area-packaging/line-901/sensors/temperature/packaging-zone', 'Float', 18.5, 24.5),
        ('homelab-uns/site-roosendaal/area-packaging/line-901/sensors/humidity/packaging-zone', 'Float', 45.0, 65.0),
        
        ('homelab-uns/site-roosendaal/area-packaging/line-902/mes/current-shift/OEE Percentage', 'Float', 70.0, 92.0),
        ('homelab-uns/site-roosendaal/area-packaging/line-902/mes/current-shift/Production Count', 'Integer', 380, 580),
        ('homelab-uns/site-roosendaal/area-packaging/line-902/mes/current-shift/Downtime Minutes', 'Integer', 0, 60),
        
        -- Site Roosendaal - Area Production  
        ('homelab-uns/site-roosendaal/area-production/line-501/mes/current-shift/OEE Percentage', 'Float', 80.0, 96.0),
        ('homelab-uns/site-roosendaal/area-production/line-501/mes/current-shift/Production Count', 'Integer', 850, 1200),
        ('homelab-uns/site-roosendaal/area-production/line-501/mes/current-shift/Quality Rate', 'Float', 92.0, 99.5),
        ('homelab-uns/site-roosendaal/area-production/line-501/sensors/pressure/hydraulic-system', 'Float', 145.0, 165.0),
        ('homelab-uns/site-roosendaal/area-production/line-501/sensors/vibration/motor-1', 'Float', 0.5, 3.2),
        
        ('homelab-uns/site-roosendaal/area-production/line-502/mes/current-shift/OEE Percentage', 'Float', 78.0, 94.0),
        ('homelab-uns/site-roosendaal/area-production/line-502/mes/current-shift/Production Count', 'Integer', 780, 1100),
        ('homelab-uns/site-roosendaal/area-production/line-502/mes/current-shift/Quality Rate', 'Float', 90.0, 98.8),
        
        -- Site Amsterdam - Area Assembly
        ('homelab-uns/site-amsterdam/area-assembly/line-301/mes/current-shift/OEE Percentage', 'Float', 72.0, 89.0),
        ('homelab-uns/site-amsterdam/area-assembly/line-301/mes/current-shift/Production Count', 'Integer', 320, 480),
        ('homelab-uns/site-amsterdam/area-assembly/line-301/mes/current-shift/Cycle Time', 'Float', 145.0, 185.0),
        ('homelab-uns/site-amsterdam/area-assembly/line-301/sensors/temperature/work-zone', 'Float', 20.0, 26.0),
        
        ('homelab-uns/site-amsterdam/area-assembly/line-302/mes/current-shift/OEE Percentage', 'Float', 76.0, 91.0),
        ('homelab-uns/site-amsterdam/area-assembly/line-302/mes/current-shift/Production Count', 'Integer', 290, 440),
        ('homelab-uns/site-amsterdam/area-assembly/line-302/mes/current-shift/Cycle Time', 'Float', 150.0, 190.0),
        
        -- Site Utrecht - Area Testing
        ('homelab-uns/site-utrecht/area-testing/line-201/mes/current-shift/OEE Percentage', 'Float', 85.0, 97.0),
        ('homelab-uns/site-utrecht/area-testing/line-201/mes/current-shift/Tests Completed', 'Integer', 180, 280),
        ('homelab-uns/site-utrecht/area-testing/line-201/mes/current-shift/Pass Rate', 'Float', 94.0, 99.2),
        ('homelab-uns/site-utrecht/area-testing/line-201/sensors/temperature/test-chamber', 'Float', 22.0, 25.0),
        ('homelab-uns/site-utrecht/area-testing/line-201/sensors/pressure/pneumatic-system', 'Float', 85.0, 95.0)
    ) AS metrics(name, dataType, min_val, max_val)
),

-- Generate realistic data with some seasonal and daily patterns
generated_data AS (
    SELECT 
        fm.name,
        fm.dataType,
        CASE 
            -- Add seasonal variation (slightly lower performance in summer months)
            WHEN EXTRACT(month FROM to_timestamp(ts.ts/1000)) IN (6,7,8) THEN
                fm.min_val + (fm.max_val - fm.min_val) * 
                (0.3 + 0.6 * random() + 
                 0.1 * sin(2 * pi() * EXTRACT(hour FROM to_timestamp(ts.ts/1000)) / 24) + -- Daily pattern
                 0.05 * sin(2 * pi() * EXTRACT(doy FROM to_timestamp(ts.ts/1000)) / 365)) -- Yearly pattern
            ELSE
                fm.min_val + (fm.max_val - fm.min_val) * 
                (0.2 + 0.7 * random() + 
                 0.1 * sin(2 * pi() * EXTRACT(hour FROM to_timestamp(ts.ts/1000)) / 24) + -- Daily pattern
                 0.05 * sin(2 * pi() * EXTRACT(doy FROM to_timestamp(ts.ts/1000)) / 365)) -- Yearly pattern
        END as value,
        ts.ts as timestamp,
        CASE 
            -- Good quality most of the time
            WHEN random() < 0.95 THEN 192  -- Good quality
            WHEN random() < 0.03 THEN 64   -- Uncertain quality  
            ELSE 0                         -- Bad quality
        END as qualityCode
    FROM time_series ts
    CROSS JOIN factory_metrics fm
),

-- Round values appropriately based on data type
final_data AS (
    SELECT 
        name,
        dataType,
        CASE 
            WHEN dataType = 'Integer' THEN ROUND(value)
            WHEN dataType = 'Float' THEN ROUND(value::numeric, 1)
            ELSE value
        END as value,
        timestamp,
        qualityCode
    FROM generated_data
)

-- Insert the generated data
INSERT INTO uns_raw (name, dataType, value, timestamp, qualityCode)
SELECT name, dataType, value, timestamp, qualityCode 
FROM final_data
ORDER BY timestamp, name;

-- Add some summary statistics
SELECT 
    'Data generation completed successfully!' as status,
    COUNT(*) as total_records,
    COUNT(DISTINCT name) as unique_metrics,
    MIN(to_timestamp(timestamp/1000)) as earliest_timestamp,
    MAX(to_timestamp(timestamp/1000)) as latest_timestamp
FROM uns_raw;

-- Sample queries to verify the data
SELECT 
    '=== Sample OEE Data ===' as section,
    name,
    dataType,
    value,
    to_timestamp(timestamp/1000) as readable_timestamp,
    qualityCode
FROM uns_raw 
WHERE name LIKE '%OEE Percentage%' 
  AND name LIKE '%line-901%'
ORDER BY timestamp 
LIMIT 10;

-- Quality code distribution
SELECT 
    '=== Quality Code Distribution ===' as section,
    qualityCode,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentage
FROM uns_raw
GROUP BY qualityCode
ORDER BY qualityCode;

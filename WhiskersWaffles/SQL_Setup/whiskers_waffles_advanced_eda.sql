-- ==============================================================================
-- WHISKERS & WAFFLES CAT CAFE
-- Advanced Exploratory Data Analysis for Data Science
-- ==============================================================================
--
-- PPOL 5206: Massive Data Fundamentals
-- Georgetown University | McCourt School of Public Policy
--
-- PURPOSE:
-- This script explores the EXPANDED dataset (~16,000 visits, ~250 customers,
-- ~70 cats) and demonstrates how to build analytical extracts suitable for
-- data science workflows in Python, Snowflake, or SageMaker.
--
-- Unlike the introductory EDA, this script focuses on:
--   - Distribution analysis at scale
--   - Correlation exploration between variables
--   - Building flat analytical datasets for downstream modeling
--   - Identifying relationships planted in the data
--   - Data quality assessment and cleaning
--
-- PREREQUISITES:
-- 1. Run whiskers_waffles_database.sql (schema + seed data)
-- 2. Run whiskers_waffles_expansion.sql (expanded data + new tables)
--
-- ==============================================================================


-- ##############################################################################
-- PART 1: UNDERSTANDING THE EXPANDED DATASET
-- ##############################################################################
-- First, get oriented. How much data do we have now? What's different from
-- the small teaching database?
-- ##############################################################################


-- -----------------------------------------------------------------------------
-- 1.1 RECORD COUNTS — THE SCALE OF OUR DATA
-- -----------------------------------------------------------------------------
-- Compare this to the original: we went from ~100 visits to ~16,000+

SELECT 'membership_tiers' AS table_name, COUNT(*) AS row_count FROM membership_tiers
UNION ALL SELECT 'breeds', COUNT(*) FROM breeds
UNION ALL SELECT 'interaction_types', COUNT(*) FROM interaction_types
UNION ALL SELECT 'shelters', COUNT(*) FROM shelters
UNION ALL SELECT 'menu_items', COUNT(*) FROM menu_items
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'cats', COUNT(*) FROM cats
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'visits', COUNT(*) FROM visits
UNION ALL SELECT 'interactions', COUNT(*) FROM interactions
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'daily_weather', COUNT(*) FROM daily_weather
UNION ALL SELECT 'cat_health_records', COUNT(*) FROM cat_health_records
UNION ALL SELECT 'customer_surveys', COUNT(*) FROM customer_surveys
UNION ALL SELECT 'menu_price_history', COUNT(*) FROM menu_price_history
ORDER BY row_count DESC;

-- WHAT TO NOTICE:
-- - Transactional tables (visits, interactions, order_items) are largest
-- - Reference tables barely changed (breeds, tiers, types)
-- - New tables added: events, daily_weather, cat_health_records,
--   customer_surveys, menu_price_history
-- - This pattern (small reference, large transactional) is universal in
--   business databases


-- -----------------------------------------------------------------------------
-- 1.2 TEMPORAL COVERAGE
-- -----------------------------------------------------------------------------
-- How much time does our data span? Critical for time series work.

SELECT
    MIN(visit_date) AS first_visit,
    MAX(visit_date) AS last_visit,
    MAX(visit_date) - MIN(visit_date) AS days_of_data,
    COUNT(DISTINCT visit_date) AS days_with_visits,
    COUNT(*) AS total_visits,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT visit_date), 0), 1) AS avg_visits_per_day
FROM visits;


-- -----------------------------------------------------------------------------
-- 1.3 NEW COLUMNS AND TABLES
-- -----------------------------------------------------------------------------
-- Explore the new fields added to existing tables

-- Temperament score distribution for cats
SELECT
    ROUND(temperament_score) AS score_bucket,
    COUNT(*) AS cat_count,
    ROUND(AVG(weight_lbs), 1) AS avg_weight,
    COUNT(*) FILTER (WHERE status = 'adopted') AS adopted_count
FROM cats
WHERE temperament_score IS NOT NULL
GROUP BY ROUND(temperament_score)
ORDER BY score_bucket;

-- Customer zip code distribution
SELECT
    zip_code,
    COUNT(*) AS customer_count,
    ROUND(AVG(CASE WHEN tier_id IS NOT NULL THEN tier_id END), 1) AS avg_tier
FROM customers
WHERE zip_code IS NOT NULL
GROUP BY zip_code
ORDER BY customer_count DESC
LIMIT 15;


-- ##############################################################################
-- PART 2: DISTRIBUTION ANALYSIS
-- ##############################################################################
-- With thousands of records, we can now examine distributions meaningfully.
-- These queries produce the kind of summary statistics you'd compute in
-- Python before fitting a model.
-- ##############################################################################


-- -----------------------------------------------------------------------------
-- 2.1 DAILY VISIT COUNT DISTRIBUTION
-- -----------------------------------------------------------------------------
-- Understanding the distribution of your dependent variable is step one
-- in any modeling exercise.

WITH daily_visits AS (
    SELECT
        visit_date,
        COUNT(*) AS visit_count
    FROM visits
    GROUP BY visit_date
)
SELECT
    COUNT(*) AS total_days,
    ROUND(AVG(visit_count), 1) AS mean_visits,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY visit_count) AS median_visits,
    ROUND(STDDEV(visit_count), 2) AS std_dev,
    MIN(visit_count) AS min_visits,
    MAX(visit_count) AS max_visits,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY visit_count) AS p25,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY visit_count) AS p75
FROM daily_visits;

-- Histogram of daily visit counts (binned)
WITH daily_visits AS (
    SELECT visit_date, COUNT(*) AS visit_count
    FROM visits
    GROUP BY visit_date
)
SELECT
    CASE
        WHEN visit_count BETWEEN 1 AND 5 THEN '01-05'
        WHEN visit_count BETWEEN 6 AND 10 THEN '06-10'
        WHEN visit_count BETWEEN 11 AND 15 THEN '11-15'
        WHEN visit_count BETWEEN 16 AND 20 THEN '16-20'
        WHEN visit_count BETWEEN 21 AND 25 THEN '21-25'
        WHEN visit_count BETWEEN 26 AND 30 THEN '26-30'
        ELSE '31+'
    END AS visit_bin,
    COUNT(*) AS day_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct
FROM daily_visits
GROUP BY
    CASE
        WHEN visit_count BETWEEN 1 AND 5 THEN '01-05'
        WHEN visit_count BETWEEN 6 AND 10 THEN '06-10'
        WHEN visit_count BETWEEN 11 AND 15 THEN '11-15'
        WHEN visit_count BETWEEN 16 AND 20 THEN '16-20'
        WHEN visit_count BETWEEN 21 AND 25 THEN '21-25'
        WHEN visit_count BETWEEN 26 AND 30 THEN '26-30'
        ELSE '31+'
    END
ORDER BY visit_bin;


-- -----------------------------------------------------------------------------
-- 2.2 CUSTOMER VISIT FREQUENCY DISTRIBUTION
-- -----------------------------------------------------------------------------
-- Is this a power law? Are most customers one-time visitors?

WITH customer_visits AS (
    SELECT customer_id, COUNT(*) AS visit_count
    FROM visits
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN visit_count = 1 THEN '1 visit'
        WHEN visit_count BETWEEN 2 AND 5 THEN '2-5 visits'
        WHEN visit_count BETWEEN 6 AND 15 THEN '6-15 visits'
        WHEN visit_count BETWEEN 16 AND 30 THEN '16-30 visits'
        WHEN visit_count BETWEEN 31 AND 50 THEN '31-50 visits'
        ELSE '51+ visits'
    END AS frequency_bucket,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct_of_customers
FROM customer_visits
GROUP BY
    CASE
        WHEN visit_count = 1 THEN '1 visit'
        WHEN visit_count BETWEEN 2 AND 5 THEN '2-5 visits'
        WHEN visit_count BETWEEN 6 AND 15 THEN '6-15 visits'
        WHEN visit_count BETWEEN 16 AND 30 THEN '16-30 visits'
        WHEN visit_count BETWEEN 31 AND 50 THEN '31-50 visits'
        ELSE '51+ visits'
    END
ORDER BY
    CASE
        WHEN frequency_bucket = '1 visit' THEN 1
        WHEN frequency_bucket = '2-5 visits' THEN 2
        WHEN frequency_bucket = '6-15 visits' THEN 3
        WHEN frequency_bucket = '16-30 visits' THEN 4
        WHEN frequency_bucket = '31-50 visits' THEN 5
        ELSE 6
    END;


-- -----------------------------------------------------------------------------
-- 2.3 ORDER VALUE DISTRIBUTION
-- -----------------------------------------------------------------------------

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(total), 2) AS avg_order_total,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)::NUMERIC, 2) AS median_order,
    ROUND(STDDEV(total), 2) AS std_dev,
    MIN(total) AS min_order,
    MAX(total) AS max_order
FROM orders;


-- ##############################################################################
-- PART 3: EXPLORING RELATIONSHIPS (What students will model)
-- ##############################################################################
-- These queries reveal the statistical relationships planted in the data.
-- Each one corresponds to a potential modeling exercise.
-- ##############################################################################


-- -----------------------------------------------------------------------------
-- 3.1 WEEKEND EFFECT ON VISITS
-- -----------------------------------------------------------------------------
-- Question: Are weekends significantly busier? (Yes — ~40% higher)

WITH daily_stats AS (
    SELECT
        visit_date,
        EXTRACT(DOW FROM visit_date) AS dow,
        CASE WHEN EXTRACT(DOW FROM visit_date) IN (0, 6) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
        COUNT(*) AS visit_count
    FROM visits
    GROUP BY visit_date
)
SELECT
    day_type,
    COUNT(*) AS num_days,
    ROUND(AVG(visit_count), 2) AS avg_daily_visits,
    ROUND(STDDEV(visit_count), 2) AS std_dev,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY visit_count)::NUMERIC, 1) AS median
FROM daily_stats
GROUP BY day_type
ORDER BY day_type;

-- By individual day of week
WITH daily_stats AS (
    SELECT
        visit_date,
        EXTRACT(DOW FROM visit_date) AS dow,
        COUNT(*) AS visit_count
    FROM visits
    GROUP BY visit_date
)
SELECT
    dow,
    CASE dow
        WHEN 0 THEN 'Sunday'   WHEN 1 THEN 'Monday'    WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday' WHEN 4 THEN 'Thursday'  WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    ROUND(AVG(visit_count), 2) AS avg_visits,
    COUNT(*) AS sample_size
FROM daily_stats
GROUP BY dow
ORDER BY dow;


-- -----------------------------------------------------------------------------
-- 3.2 WEATHER EFFECT ON VISITS
-- -----------------------------------------------------------------------------
-- Question: Does weather predict foot traffic? (Yes — optimal around 65-75F,
-- rain/snow reduce visits)

WITH daily_combined AS (
    SELECT
        v.visit_date,
        COUNT(*) AS visit_count,
        w.high_temp_f,
        w.condition,
        w.precipitation_in
    FROM visits v
    JOIN daily_weather w ON v.visit_date = w.observation_date
    WHERE w.high_temp_f IS NOT NULL  -- Exclude missing weather data
    GROUP BY v.visit_date, w.high_temp_f, w.condition, w.precipitation_in
)
SELECT
    condition,
    COUNT(*) AS num_days,
    ROUND(AVG(visit_count), 2) AS avg_visits,
    ROUND(AVG(high_temp_f), 1) AS avg_temp
FROM daily_combined
GROUP BY condition
ORDER BY avg_visits DESC;

-- Temperature bins and visits
WITH daily_combined AS (
    SELECT
        v.visit_date,
        COUNT(*) AS visit_count,
        w.high_temp_f
    FROM visits v
    JOIN daily_weather w ON v.visit_date = w.observation_date
    WHERE w.high_temp_f IS NOT NULL
    GROUP BY v.visit_date, w.high_temp_f
)
SELECT
    CASE
        WHEN high_temp_f < 35 THEN 'Below 35F'
        WHEN high_temp_f < 50 THEN '35-49F'
        WHEN high_temp_f < 65 THEN '50-64F'
        WHEN high_temp_f < 80 THEN '65-79F (optimal)'
        WHEN high_temp_f < 90 THEN '80-89F'
        ELSE '90F+'
    END AS temp_range,
    COUNT(*) AS num_days,
    ROUND(AVG(visit_count), 2) AS avg_visits,
    ROUND(STDDEV(visit_count), 2) AS std_dev
FROM daily_combined
GROUP BY
    CASE
        WHEN high_temp_f < 35 THEN 'Below 35F'
        WHEN high_temp_f < 50 THEN '35-49F'
        WHEN high_temp_f < 65 THEN '50-64F'
        WHEN high_temp_f < 80 THEN '65-79F (optimal)'
        WHEN high_temp_f < 90 THEN '80-89F'
        ELSE '90F+'
    END
ORDER BY avg_visits DESC;


-- -----------------------------------------------------------------------------
-- 3.3 EVENT EFFECT ON VISITS
-- -----------------------------------------------------------------------------
-- Question: Do cafe events boost foot traffic? (Yes — ~30% lift)

WITH daily_visits AS (
    SELECT
        v.visit_date,
        COUNT(*) AS visit_count,
        CASE WHEN e.event_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_event_day,
        e.event_type
    FROM visits v
    LEFT JOIN events e ON v.visit_date = e.event_date
    GROUP BY v.visit_date, e.event_id, e.event_type
)
SELECT
    is_event_day,
    COUNT(*) AS num_days,
    ROUND(AVG(visit_count), 2) AS avg_visits,
    ROUND(STDDEV(visit_count), 2) AS std_dev
FROM daily_visits
GROUP BY is_event_day
ORDER BY is_event_day;

-- Breakdown by event type
WITH daily_visits AS (
    SELECT
        v.visit_date,
        COUNT(*) AS visit_count,
        COALESCE(e.event_type, 'No Event') AS event_type
    FROM visits v
    LEFT JOIN events e ON v.visit_date = e.event_date
    GROUP BY v.visit_date, e.event_type
)
SELECT
    event_type,
    COUNT(*) AS num_days,
    ROUND(AVG(visit_count), 2) AS avg_visits
FROM daily_visits
GROUP BY event_type
ORDER BY avg_visits DESC;


-- -----------------------------------------------------------------------------
-- 3.4 ADOPTION PREDICTION FEATURES
-- -----------------------------------------------------------------------------
-- Question: What predicts whether a cat gets adopted?
-- (Temperament score, age at arrival, interaction count)

-- Cat-level dataset with adoption features
SELECT
    c.cat_id,
    c.name,
    c.temperament_score,
    c.weight_lbs,
    b.breed_name,
    c.status,
    CASE WHEN c.status = 'adopted' THEN 1 ELSE 0 END AS adopted_flag,
    c.arrival_date,
    c.adoption_date,
    CASE WHEN c.adoption_date IS NOT NULL
         THEN c.adoption_date - c.arrival_date
    END AS days_to_adoption,
    -- Age at arrival (approximate)
    CASE WHEN c.birth_date IS NOT NULL
         THEN ROUND((c.arrival_date - c.birth_date)::NUMERIC / 365, 1)
    END AS age_at_arrival_years,
    c.is_featured,
    -- Interaction summary
    COUNT(i.interaction_id) AS total_interactions,
    COUNT(DISTINCT v.customer_id) AS unique_customers,
    ROUND(AVG(i.duration_mins), 1) AS avg_interaction_mins,
    SUM(i.duration_mins) AS total_interaction_mins
FROM cats c
LEFT JOIN breeds b ON c.breed_id = b.breed_id
LEFT JOIN interactions i ON c.cat_id = i.cat_id
LEFT JOIN visits v ON i.visit_id = v.visit_id
WHERE c.status IN ('adopted', 'available')  -- Binary classification target
GROUP BY c.cat_id, c.name, c.temperament_score, c.weight_lbs,
         b.breed_name, c.status, c.arrival_date, c.adoption_date,
         c.birth_date, c.is_featured
ORDER BY c.cat_id;

-- Correlation check: temperament vs adoption
SELECT
    CASE
        WHEN temperament_score < 4 THEN 'Low (1-3)'
        WHEN temperament_score < 7 THEN 'Medium (4-6)'
        ELSE 'High (7-10)'
    END AS temperament_group,
    COUNT(*) AS total_cats,
    COUNT(*) FILTER (WHERE status = 'adopted') AS adopted,
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'adopted') / COUNT(*), 1) AS adoption_rate_pct
FROM cats
WHERE temperament_score IS NOT NULL
    AND status IN ('adopted', 'available')
GROUP BY
    CASE
        WHEN temperament_score < 4 THEN 'Low (1-3)'
        WHEN temperament_score < 7 THEN 'Medium (4-6)'
        ELSE 'High (7-10)'
    END
ORDER BY adoption_rate_pct DESC;


-- -----------------------------------------------------------------------------
-- 3.5 CUSTOMER SATISFACTION AND MEMBERSHIP
-- -----------------------------------------------------------------------------
-- Question: Does membership tier predict satisfaction? (Yes)

SELECT
    COALESCE(mt.tier_name, 'No Membership') AS tier,
    COUNT(s.survey_id) AS survey_count,
    ROUND(AVG(s.overall_satisfaction), 2) AS avg_satisfaction,
    ROUND(AVG(s.likelihood_recommend), 2) AS avg_nps,
    ROUND(AVG(s.cat_experience), 2) AS avg_cat_experience,
    ROUND(AVG(s.food_quality), 2) AS avg_food_quality
FROM customer_surveys s
JOIN customers c ON s.customer_id = c.customer_id
LEFT JOIN membership_tiers mt ON c.tier_id = mt.tier_id
GROUP BY COALESCE(mt.tier_name, 'No Membership'), mt.monthly_price
ORDER BY mt.monthly_price DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 3.6 SEASONAL MENU PATTERNS
-- -----------------------------------------------------------------------------
-- Question: Do menu item sales vary by season? (Yes — cold brew summer,
-- hot drinks winter)

SELECT
    mi.item_name,
    mi.category,
    EXTRACT(MONTH FROM o.order_datetime) AS month,
    SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN menu_items mi ON oi.item_id = mi.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE mi.item_id IN (1, 4, 7, 8, 20)  -- Latte, Cold Brew, Catnip Latte, Matcha, Ice Cream
GROUP BY mi.item_name, mi.category, EXTRACT(MONTH FROM o.order_datetime)
ORDER BY mi.item_name, month;


-- ##############################################################################
-- PART 4: BUILDING ANALYTICAL EXTRACTS
-- ##############################################################################
-- These queries produce the flat, rectangular datasets that students will
-- export to Python/Snowflake/SageMaker for modeling. Each extract is designed
-- for a specific analytical question.
-- ##############################################################################


-- -----------------------------------------------------------------------------
-- 4.1 DAILY REVENUE DATASET (for Time Series Forecasting)
-- -----------------------------------------------------------------------------
-- Each row = one day. This is what you'd use for revenue forecasting,
-- time series decomposition, or regression on daily factors.
--
-- EXPORT THIS to CSV for Python analysis.

SELECT
    v_day.visit_date,
    v_day.visit_count,
    v_day.visit_revenue,
    COALESCE(o_day.order_revenue, 0) AS order_revenue,
    v_day.visit_revenue + COALESCE(o_day.order_revenue, 0) AS total_revenue,
    EXTRACT(DOW FROM v_day.visit_date) AS day_of_week,
    CASE WHEN EXTRACT(DOW FROM v_day.visit_date) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend,
    EXTRACT(MONTH FROM v_day.visit_date) AS month,
    EXTRACT(YEAR FROM v_day.visit_date) AS year,
    w.high_temp_f,
    w.low_temp_f,
    w.precipitation_in,
    w.condition AS weather_condition,
    w.humidity_pct,
    CASE WHEN e.event_id IS NOT NULL THEN 1 ELSE 0 END AS is_event_day,
    e.event_type,
    v_day.unique_customers,
    v_day.avg_discount_pct
FROM (
    SELECT
        visit_date,
        COUNT(*) AS visit_count,
        SUM(cover_charge - discount_applied) AS visit_revenue,
        COUNT(DISTINCT customer_id) AS unique_customers,
        ROUND(AVG(discount_applied / NULLIF(cover_charge, 0)), 3) AS avg_discount_pct
    FROM visits
    GROUP BY visit_date
) v_day
LEFT JOIN (
    SELECT
        DATE(order_datetime) AS order_date,
        SUM(total) AS order_revenue
    FROM orders
    GROUP BY DATE(order_datetime)
) o_day ON v_day.visit_date = o_day.order_date
LEFT JOIN daily_weather w ON v_day.visit_date = w.observation_date
LEFT JOIN events e ON v_day.visit_date = e.event_date
ORDER BY v_day.visit_date;


-- -----------------------------------------------------------------------------
-- 4.2 CAT ADOPTION DATASET (for Classification)
-- -----------------------------------------------------------------------------
-- Each row = one cat. Binary target: adopted (1) or not (0).
-- Features include attributes, interaction history, and health data.
--
-- EXPORT THIS to CSV for classification modeling (logistic regression,
-- random forest, etc.)

WITH cat_interactions AS (
    SELECT
        i.cat_id,
        COUNT(*) AS total_interactions,
        COUNT(DISTINCT v.customer_id) AS unique_customers_met,
        ROUND(AVG(i.duration_mins), 1) AS avg_interaction_mins,
        SUM(i.duration_mins) AS total_interaction_mins,
        COUNT(*) FILTER (WHERE it.type_name = 'Lap Time') AS lap_time_count,
        COUNT(*) FILTER (WHERE it.type_name = 'Play Session') AS play_count,
        COUNT(*) FILTER (WHERE it.type_name = 'Photo Session') AS photo_count
    FROM interactions i
    JOIN visits v ON i.visit_id = v.visit_id
    JOIN interaction_types it ON i.type_id = it.type_id
    GROUP BY i.cat_id
),
cat_health AS (
    SELECT
        cat_id,
        ROUND(AVG(health_score), 1) AS avg_health_score,
        ROUND(AVG(weight_lbs), 1) AS avg_weight,
        COUNT(*) FILTER (WHERE vet_visit = TRUE) AS vet_visits
    FROM cat_health_records
    GROUP BY cat_id
)
SELECT
    c.cat_id,
    -- TARGET VARIABLE
    CASE WHEN c.status = 'adopted' THEN 1 ELSE 0 END AS adopted,
    -- FEATURES
    c.temperament_score,
    c.weight_lbs,
    b.breed_name,
    b.avg_lifespan_years AS breed_avg_lifespan,
    ROUND((c.arrival_date - c.birth_date)::NUMERIC / 365, 1) AS age_at_arrival,
    c.is_featured::INTEGER AS is_featured,
    sh.shelter_name AS source_shelter,
    -- Interaction features
    COALESCE(ci.total_interactions, 0) AS total_interactions,
    COALESCE(ci.unique_customers_met, 0) AS unique_customers_met,
    COALESCE(ci.avg_interaction_mins, 0) AS avg_interaction_mins,
    COALESCE(ci.lap_time_count, 0) AS lap_time_count,
    COALESCE(ci.play_count, 0) AS play_count,
    -- Health features
    COALESCE(ch.avg_health_score, 0) AS avg_health_score,
    COALESCE(ch.vet_visits, 0) AS vet_visit_count
FROM cats c
JOIN breeds b ON c.breed_id = b.breed_id
LEFT JOIN shelters sh ON c.shelter_id = sh.shelter_id
LEFT JOIN cat_interactions ci ON c.cat_id = ci.cat_id
LEFT JOIN cat_health ch ON c.cat_id = ch.cat_id
WHERE c.status IN ('adopted', 'available')  -- Exclude medical_hold, foster, etc.
    AND c.birth_date IS NOT NULL
    AND c.temperament_score IS NOT NULL
ORDER BY c.cat_id;


-- -----------------------------------------------------------------------------
-- 4.3 CUSTOMER SEGMENTATION DATASET (for Clustering / RFM Analysis)
-- -----------------------------------------------------------------------------
-- Each row = one customer with Recency, Frequency, Monetary (RFM) features
-- plus survey and membership data.
--
-- EXPORT THIS for customer segmentation, clustering, or lifetime value modeling.

WITH customer_rfm AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        COALESCE(mt.tier_name, 'No Membership') AS membership_tier,
        mt.monthly_price AS tier_price,
        c.join_date,
        c.zip_code,
        -- Recency: days since last visit
        CURRENT_DATE - MAX(v.visit_date) AS days_since_last_visit,
        -- Frequency: total visits
        COUNT(v.visit_id) AS total_visits,
        -- Monetary: total spend
        SUM(v.cover_charge - v.discount_applied) AS total_visit_spend,
        -- Additional features
        ROUND(AVG(v.cover_charge - v.discount_applied), 2) AS avg_visit_spend,
        MIN(v.visit_date) AS first_visit,
        MAX(v.visit_date) AS last_visit,
        -- Tenure in days
        MAX(v.visit_date) - MIN(v.visit_date) AS customer_tenure_days,
        -- Visit frequency (visits per month)
        CASE WHEN MAX(v.visit_date) > MIN(v.visit_date)
             THEN ROUND(
                 COUNT(v.visit_id)::NUMERIC /
                 GREATEST(1, (MAX(v.visit_date) - MIN(v.visit_date))::NUMERIC / 30),
                 2
             )
        END AS visits_per_month
    FROM customers c
    LEFT JOIN membership_tiers mt ON c.tier_id = mt.tier_id
    LEFT JOIN visits v ON c.customer_id = v.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name,
             mt.tier_name, mt.monthly_price, c.join_date, c.zip_code
),
customer_orders AS (
    SELECT
        customer_id,
        COALESCE(SUM(total), 0) AS total_order_spend,
        COUNT(*) AS total_orders,
        ROUND(AVG(total), 2) AS avg_order_value
    FROM orders
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
customer_satisfaction AS (
    SELECT
        customer_id,
        ROUND(AVG(overall_satisfaction), 2) AS avg_satisfaction,
        ROUND(AVG(likelihood_recommend), 2) AS avg_nps,
        COUNT(*) AS survey_responses
    FROM customer_surveys
    GROUP BY customer_id
)
SELECT
    r.customer_id,
    r.membership_tier,
    r.tier_price,
    -- RFM features
    r.days_since_last_visit AS recency_days,
    r.total_visits AS frequency,
    ROUND(r.total_visit_spend + COALESCE(co.total_order_spend, 0), 2) AS monetary_total,
    -- Additional features
    r.avg_visit_spend,
    COALESCE(co.avg_order_value, 0) AS avg_order_value,
    r.customer_tenure_days,
    r.visits_per_month,
    -- Satisfaction
    COALESCE(cs.avg_satisfaction, 0) AS avg_satisfaction,
    COALESCE(cs.avg_nps, 0) AS avg_nps_score,
    r.zip_code
FROM customer_rfm r
LEFT JOIN customer_orders co ON r.customer_id = co.customer_id
LEFT JOIN customer_satisfaction cs ON r.customer_id = cs.customer_id
WHERE r.total_visits > 0  -- Exclude customers who never visited
ORDER BY monetary_total DESC;


-- -----------------------------------------------------------------------------
-- 4.4 MONTHLY BUSINESS METRICS (for Trend Analysis / Forecasting)
-- -----------------------------------------------------------------------------
-- Each row = one month. Aggregated metrics suitable for time series analysis,
-- trend identification, and business reporting.

WITH monthly_visits AS (
    SELECT
        DATE_TRUNC('month', visit_date) AS month,
        COUNT(*) AS visit_count,
        SUM(cover_charge - discount_applied) AS visit_revenue,
        COUNT(DISTINCT customer_id) AS unique_visitors,
        ROUND(AVG(cover_charge - discount_applied), 2) AS avg_revenue_per_visit
    FROM visits
    GROUP BY DATE_TRUNC('month', visit_date)
),
monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_datetime) AS month,
        COUNT(*) AS order_count,
        SUM(total) AS order_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_datetime)
),
monthly_events AS (
    SELECT
        DATE_TRUNC('month', event_date) AS month,
        COUNT(*) AS event_count
    FROM events
    GROUP BY DATE_TRUNC('month', event_date)
),
monthly_weather AS (
    SELECT
        DATE_TRUNC('month', observation_date) AS month,
        ROUND(AVG(high_temp_f), 1) AS avg_high_temp,
        SUM(precipitation_in) AS total_precip,
        COUNT(*) FILTER (WHERE condition IN ('Rain', 'Snow')) AS rainy_days
    FROM daily_weather
    WHERE high_temp_f IS NOT NULL
    GROUP BY DATE_TRUNC('month', observation_date)
)
SELECT
    mv.month,
    mv.visit_count,
    mv.visit_revenue,
    COALESCE(mo.order_revenue, 0) AS order_revenue,
    mv.visit_revenue + COALESCE(mo.order_revenue, 0) AS total_revenue,
    mv.unique_visitors,
    mv.avg_revenue_per_visit,
    COALESCE(me.event_count, 0) AS events_held,
    mw.avg_high_temp,
    mw.total_precip,
    mw.rainy_days,
    -- Year-over-year growth
    LAG(mv.visit_count, 12) OVER (ORDER BY mv.month) AS visits_same_month_last_year,
    ROUND(100.0 * (mv.visit_count - LAG(mv.visit_count, 12) OVER (ORDER BY mv.month)) /
        NULLIF(LAG(mv.visit_count, 12) OVER (ORDER BY mv.month), 0), 1) AS visit_yoy_growth_pct
FROM monthly_visits mv
LEFT JOIN monthly_orders mo ON mv.month = mo.month
LEFT JOIN monthly_events me ON mv.month = me.month
LEFT JOIN monthly_weather mw ON mv.month = mw.month
ORDER BY mv.month;


-- ##############################################################################
-- PART 5: DATA QUALITY ASSESSMENT
-- ##############################################################################
-- Before exporting for modeling, always check data quality. These queries
-- identify the intentional (and any unintentional) issues in the data.
-- ##############################################################################


-- -----------------------------------------------------------------------------
-- 5.1 NULL VALUE AUDIT
-- -----------------------------------------------------------------------------

-- Comprehensive NULL check across key analytical columns
SELECT
    'cats.temperament_score' AS field,
    COUNT(*) AS total,
    COUNT(*) - COUNT(temperament_score) AS nulls,
    ROUND(100.0 * (COUNT(*) - COUNT(temperament_score)) / COUNT(*), 1) AS null_pct
FROM cats
UNION ALL
SELECT 'cats.weight_lbs', COUNT(*), COUNT(*) - COUNT(weight_lbs),
       ROUND(100.0 * (COUNT(*) - COUNT(weight_lbs)) / COUNT(*), 1) FROM cats
UNION ALL
SELECT 'customers.zip_code', COUNT(*), COUNT(*) - COUNT(zip_code),
       ROUND(100.0 * (COUNT(*) - COUNT(zip_code)) / COUNT(*), 1) FROM customers
UNION ALL
SELECT 'daily_weather.high_temp_f', COUNT(*), COUNT(*) - COUNT(high_temp_f),
       ROUND(100.0 * (COUNT(*) - COUNT(high_temp_f)) / COUNT(*), 1) FROM daily_weather
UNION ALL
SELECT 'surveys.food_quality', COUNT(*), COUNT(*) - COUNT(food_quality),
       ROUND(100.0 * (COUNT(*) - COUNT(food_quality)) / COUNT(*), 1) FROM customer_surveys
ORDER BY null_pct DESC;


-- -----------------------------------------------------------------------------
-- 5.2 OUTLIER DETECTION
-- -----------------------------------------------------------------------------

-- Flag potential outliers in daily visit counts using IQR method
WITH daily_stats AS (
    SELECT visit_date, COUNT(*) AS visit_count
    FROM visits
    GROUP BY visit_date
),
quartiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY visit_count) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY visit_count) AS q3
    FROM daily_stats
)
SELECT
    ds.visit_date,
    ds.visit_count,
    CASE
        WHEN ds.visit_count < q.q1 - 1.5 * (q.q3 - q.q1) THEN 'LOW OUTLIER'
        WHEN ds.visit_count > q.q3 + 1.5 * (q.q3 - q.q1) THEN 'HIGH OUTLIER'
        ELSE 'Normal'
    END AS outlier_flag
FROM daily_stats ds, quartiles q
WHERE ds.visit_count < q.q1 - 1.5 * (q.q3 - q.q1)
   OR ds.visit_count > q.q3 + 1.5 * (q.q3 - q.q1)
ORDER BY ds.visit_count DESC;


-- -----------------------------------------------------------------------------
-- 5.3 REFERENTIAL INTEGRITY VERIFICATION
-- -----------------------------------------------------------------------------

-- Surveys referencing non-existent visits
SELECT COUNT(*) AS orphaned_surveys
FROM customer_surveys cs
LEFT JOIN visits v ON cs.visit_id = v.visit_id
WHERE v.visit_id IS NULL;

-- Health records for cats that don't exist
SELECT COUNT(*) AS orphaned_health_records
FROM cat_health_records chr
LEFT JOIN cats c ON chr.cat_id = c.cat_id
WHERE c.cat_id IS NULL;


-- ##############################################################################
-- PART 6: EXPORT TEMPLATES
-- ##############################################################################
-- These are templates for exporting data. In practice, students would run
-- these queries and save results to CSV, then load into Python/SageMaker.
--
-- INSTRUCTIONS FOR STUDENTS:
-- 1. Choose the analytical question you want to investigate
-- 2. Run the corresponding query from Part 4
-- 3. Export the result set to CSV
-- 4. Load into your Python/Snowflake environment
-- 5. Proceed with modeling (regression, classification, clustering, etc.)
--
-- SUGGESTED PROJECTS:
--
-- PROJECT A: Revenue Forecasting (Time Series)
--   → Use Extract 4.1 (Daily Revenue Dataset)
--   → Technique: ARIMA, Prophet, or linear regression with features
--   → Key predictors: day_of_week, is_weekend, weather, events
--
-- PROJECT B: Adoption Prediction (Classification)
--   → Use Extract 4.2 (Cat Adoption Dataset)
--   → Technique: Logistic regression, random forest, gradient boosting
--   → Key features: temperament_score, age_at_arrival, total_interactions
--
-- PROJECT C: Customer Segmentation (Clustering)
--   → Use Extract 4.3 (Customer Segmentation Dataset)
--   → Technique: K-means, hierarchical clustering
--   → Key features: RFM (recency, frequency, monetary)
--
-- PROJECT D: Business Growth Analysis (Trend + Regression)
--   → Use Extract 4.4 (Monthly Business Metrics)
--   → Technique: Time series decomposition, regression
--   → Key question: What drives month-to-month revenue changes?
--
-- PROJECT E: Price Elasticity (Regression)
--   → Combine order_items with menu_price_history
--   → Technique: Regression on quantity vs price changes
--   → Key question: Did the 2023 and 2024 price increases affect demand?
--
-- ##############################################################################


-- ##############################################################################
-- PART 7: CHALLENGE EXERCISES
-- ##############################################################################

/*
EXERCISE 1: Build a Regression-Ready Dataset
Write a SQL query that produces a daily-level dataset with:
- Daily total revenue (visits + orders)
- Weather variables
- Day of week indicators (dummy variables)
- Month indicators
- Event indicator
- Lagged revenue (yesterday's revenue, 7-day moving average)
This should be directly usable for a linear regression in Python.

EXERCISE 2: Customer Lifetime Value
Calculate the expected lifetime value of customers by membership tier.
Include: average monthly spend, average tenure, churn indicators
(no visit in last 90 days), and the ratio of order spend to visit spend.

EXERCISE 3: Cat Adoption Risk Model
Build a dataset where each row is a cat-week (one row per cat per week
they were at the cafe). The target variable is whether the cat was adopted
that week (1/0). Features should include: cumulative interactions to date,
week number at the cafe, temperament score, and current season.
This is a survival analysis / hazard model setup.

EXERCISE 4: Event ROI Analysis
For each event type, calculate:
- Average daily revenue on event days vs non-event days (same day of week)
- The marginal revenue attributable to the event
- Compare to marketing_spend to estimate ROI
Control for weather and seasonal effects.

EXERCISE 5: Menu Optimization
Using order_items, menu_items, and the daily dataset, determine:
- Which items are frequently purchased together? (market basket)
- Which items have the highest margin? (price - cost)
- Did the Jul 2023 and Jun 2024 price increases reduce demand?
- What items should be promoted during slow seasons?
*/


-- ##############################################################################
-- END OF ADVANCED EDA
-- ##############################################################################
--
-- WHAT WE COVERED:
--   1. Scale assessment and temporal coverage
--   2. Distribution analysis (histograms, quantiles, summary stats)
--   3. Relationship exploration (weekend effect, weather, events, adoption)
--   4. Building flat analytical extracts for downstream modeling
--   5. Data quality assessment (NULLs, outliers, integrity)
--   6. Export templates with suggested modeling projects
--   7. Advanced challenge exercises
--
-- KEY TAKEAWAY:
-- The SQL here is the DATA ENGINEERING step. You determine what data you
-- need from the normalized database, write the query to assemble and
-- reshape it, and export a flat dataset for analysis. The modeling
-- happens in Python/Snowflake/SageMaker — not in SQL.
--
-- ==============================================================================

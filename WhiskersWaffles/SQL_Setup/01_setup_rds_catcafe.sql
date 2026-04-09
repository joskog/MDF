-- ==============================================================================
-- PPOL 5206 Week 7 Lab — RDS Setup (Instructor Pre-Provisioning)
-- ==============================================================================
--
-- This script prepares the RDS PostgreSQL instance for Exercise 1.
-- Run BEFORE class. Students will connect and find the familiar
-- Whiskers & Waffles database from Weeks 3–5.
--
-- PREREQUISITES:
--   1. RDS instance ppol5206-transactional is running (see lab doc)
--   2. whiskers_waffles_database.sql is available in your S3 bucket
--
-- STEPS:
--   1. Connect to the RDS instance from CloudShell:
--
--      psql -h YOUR_RDS_ENDPOINT.rds.amazonaws.com \
--           -U ppol_admin -d ppol5206 -W
--
--   2. Run the cat cafe database script:
--
--      \i whiskers_waffles_database.sql
--
--      This creates 12 tables with sample data spanning ~2.5 years.
--      Takes about 10 seconds to complete.
--
--   3. Run the verification queries below to confirm the load.
--
-- ==============================================================================


-- ==============================================================================
-- VERIFICATION QUERIES (run after loading whiskers_waffles_database.sql)
-- ==============================================================================

-- Check all 12 tables were created
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'public'
ORDER  BY table_name;

-- Expected output: breeds, cats, customers, interaction_types,
-- interactions, membership_tiers, menu_items, order_items, orders,
-- shelters, staff, visits

-- Quick row counts for key tables
SELECT 'cats' AS tbl, COUNT(*) AS rows FROM cats
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'visits', COUNT(*) FROM visits
UNION ALL
SELECT 'interactions', COUNT(*) FROM interactions
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'staff', COUNT(*) FROM staff;

-- Expected: cats=18, customers=19, visits=106, interactions=108,
--           orders=24, staff=9

-- Verify foreign keys are intact (this JOIN should work cleanly)
SELECT c.name AS cat_name, b.breed_name, c.status
FROM   cats c
JOIN   breeds b ON c.breed_id = b.breed_id
ORDER  BY c.name;


-- ==============================================================================
-- EXERCISE 1 QUERIES (students will run these)
-- ==============================================================================

-- Step 2: Explore the cat cafe database
SELECT c.name AS cat_name, b.breed_name, c.status, c.personality_notes
FROM   cats c
JOIN   breeds b ON c.breed_id = b.breed_id
LIMIT  10;

-- Step 3: Insert a row and read it back immediately
INSERT INTO customers (first_name, last_name, email, join_date)
VALUES ('Georgetown', 'Student', 'student@georgetown.edu', '2026-02-18');

SELECT * FROM customers WHERE email = 'student@georgetown.edu';

-- Cleanup: remove the test row after demonstrating
DELETE FROM customers WHERE email = 'student@georgetown.edu';


-- ==============================================================================
-- ADDITIONAL QUERIES FOR DEEPER EXPLORATION (optional, if time allows)
-- ==============================================================================

-- Show constraints — this is what makes RDS different from Athena/S3
SELECT tc.constraint_name, tc.constraint_type, tc.table_name
FROM   information_schema.table_constraints tc
WHERE  tc.table_schema = 'public'
ORDER  BY tc.table_name, tc.constraint_type;

-- Try violating a constraint (this SHOULD fail — that's the point)
-- INSERT INTO cats (name, breed_id, status, arrival_date)
-- VALUES ('Ghost Cat', 999, 'available', '2026-01-01');
-- ERROR: violates foreign key constraint on breed_id

-- Show indexes (performance metadata)
SELECT tablename, indexname
FROM   pg_indexes
WHERE  schemaname = 'public'
ORDER  BY tablename;


-- ==============================================================================
-- POST-LAB CLEANUP (run after class if desired)
-- ==============================================================================

-- Drop all cat cafe tables (CASCADE handles FK dependencies)
-- DROP TABLE IF EXISTS interactions CASCADE;
-- DROP TABLE IF EXISTS order_items CASCADE;
-- DROP TABLE IF EXISTS orders CASCADE;
-- DROP TABLE IF EXISTS visits CASCADE;
-- DROP TABLE IF EXISTS cats CASCADE;
-- DROP TABLE IF EXISTS customers CASCADE;
-- DROP TABLE IF EXISTS staff CASCADE;
-- DROP TABLE IF EXISTS menu_items CASCADE;
-- DROP TABLE IF EXISTS interaction_types CASCADE;
-- DROP TABLE IF EXISTS breeds CASCADE;
-- DROP TABLE IF EXISTS membership_tiers CASCADE;
-- DROP TABLE IF EXISTS shelters CASCADE;

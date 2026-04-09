-- ==============================================================================
-- WHISKERS & WAFFLES CAT CAFE DATABASE
-- A Teaching Database for SQL Fundamentals
-- ==============================================================================
-- 
-- Course: PPOL 5206 - Massive Data Fundamentals
-- Institution: Georgetown University, McCourt School of Public Policy
-- Purpose: Demonstrate relational database concepts from basic queries through
--          advanced analytics, including normalization, joins, CTEs, and window
--          functions.
--
-- This script creates a complete, normalized database for a fictional cat cafe
-- in Washington, DC. The data spans approximately 2.5 years (2022-2025) to 
-- support temporal analysis and trend identification.
--
-- ==============================================================================
-- TABLE OF CONTENTS
-- ==============================================================================
-- 1. DATABASE METADATA AND SETUP
-- 2. SCHEMA CREATION (DDL)
--    2.1 Lookup/Reference Tables (no foreign keys)
--    2.2 Core Entity Tables (with foreign keys)
--    2.3 Junction/Bridge Tables (many-to-many relationships)
-- 3. DATA POPULATION (DML)
--    3.1 Reference Data
--    3.2 Entity Data
--    3.3 Transactional Data (with temporal distribution)
-- 4. SAMPLE ANALYTICAL QUERIES
--    4.1 Basic Queries
--    4.2 Temporal Trend Analysis
--    4.3 Advanced Analytics
-- ==============================================================================


-- ==============================================================================
-- SECTION 1: DATABASE METADATA AND SETUP
-- ==============================================================================
-- 
-- WHAT IS METADATA?
-- -----------------
-- Metadata is "data about data." In a database context, this includes:
-- 
-- 1. STRUCTURAL METADATA: Information about how data is organized
--    - Table names, column names, data types
--    - Constraints (PRIMARY KEY, FOREIGN KEY, CHECK, NOT NULL, UNIQUE)
--    - Indexes and their definitions
--    - Views and their definitions
--
-- 2. DESCRIPTIVE METADATA: Information that describes the content
--    - Comments on tables and columns (what we're adding below)
--    - Documentation about business rules
--    - Data dictionaries
--
-- 3. ADMINISTRATIVE METADATA: Information about data management
--    - When tables were created/modified
--    - Who has access (permissions)
--    - Storage information
--
-- PostgreSQL stores structural metadata in the "information_schema" and 
-- "pg_catalog" system schemas. You can query these to explore any database:
--
--   SELECT table_name, column_name, data_type 
--   FROM information_schema.columns 
--   WHERE table_schema = 'public';
--
-- ==============================================================================

-- Drop existing tables if they exist (useful for re-running the script)
-- CASCADE ensures dependent objects are also dropped
DROP TABLE IF EXISTS interactions CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS visits CASCADE;
DROP TABLE IF EXISTS cats CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS interaction_types CASCADE;
DROP TABLE IF EXISTS breeds CASCADE;
DROP TABLE IF EXISTS membership_tiers CASCADE;
DROP TABLE IF EXISTS shelters CASCADE;

-- ==============================================================================
-- SECTION 2: SCHEMA CREATION (DDL - Data Definition Language)
-- ==============================================================================
-- 
-- WHY THIS ORDER?
-- ---------------
-- Tables are created in dependency order:
-- 1. First: Tables with NO foreign keys (lookup/reference tables)
-- 2. Then: Tables that reference only the above tables
-- 3. Finally: Tables that reference multiple other tables
--
-- This prevents "relation does not exist" errors during creation.
--
-- NAMING CONVENTIONS USED:
-- - Table names: lowercase, plural (customers, cats, visits)
-- - Primary keys: tablename_id or simple _id (customer_id, cat_id)
-- - Foreign keys: match the PK name they reference (breed_id, tier_id)
-- - Junction tables: descriptive name (interactions) or entity1_entity2
--
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- 2.1 LOOKUP/REFERENCE TABLES
-- ------------------------------------------------------------------------------
-- These tables contain relatively static data that other tables reference.
-- They have no foreign keys themselves.
-- ------------------------------------------------------------------------------

-- MEMBERSHIP_TIERS: Defines the levels of customer membership
-- Business Rule: Customers can have no membership (NULL FK) or one tier.
-- The monthly_price is what members pay; visit_discount_pct is applied to 
-- cover charges.
CREATE TABLE membership_tiers (
    tier_id             SERIAL PRIMARY KEY,  -- Auto-incrementing integer
    tier_name           VARCHAR(50) NOT NULL UNIQUE,
    monthly_price       DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    visit_discount_pct  DECIMAL(3,2) DEFAULT 0.00  -- e.g., 0.25 = 25% off
        CHECK (visit_discount_pct >= 0 AND visit_discount_pct <= 1)
);

-- Add descriptive comments (this is descriptive metadata)
COMMENT ON TABLE membership_tiers IS 'Customer membership levels with pricing and discount information';
COMMENT ON COLUMN membership_tiers.visit_discount_pct IS 'Discount percentage applied to cover charges (0.25 = 25% off)';


-- BREEDS: Cat breed reference data
-- Includes typical characteristics useful for matching customers with cats
CREATE TABLE breeds (
    breed_id            SERIAL PRIMARY KEY,
    breed_name          VARCHAR(100) NOT NULL UNIQUE,
    avg_weight_lbs      DECIMAL(4,1),       -- Average adult weight
    typical_temperament VARCHAR(255),        -- General personality traits
    origin_country      VARCHAR(100),        -- Where the breed originated
    avg_lifespan_years  INTEGER              -- Typical lifespan
);

COMMENT ON TABLE breeds IS 'Reference table of cat breeds with characteristics';


-- INTERACTION_TYPES: The kinds of activities customers can do with cats
-- Used for tracking popularity, pricing, and cat wellness monitoring
CREATE TABLE interaction_types (
    type_id             SERIAL PRIMARY KEY,
    type_name           VARCHAR(50) NOT NULL UNIQUE,
    description         VARCHAR(255),
    base_duration_mins  INTEGER DEFAULT 15,  -- Typical duration
    requires_training   BOOLEAN DEFAULT FALSE -- Staff training required?
);

COMMENT ON TABLE interaction_types IS 'Types of customer-cat interactions tracked by the cafe';


-- SHELTERS: Partner organizations that provide cats
-- Tracks where cats come from for reporting and partnership management
CREATE TABLE shelters (
    shelter_id          SERIAL PRIMARY KEY,
    shelter_name        VARCHAR(200) NOT NULL,
    address             VARCHAR(255),
    city                VARCHAR(100),
    state               CHAR(2),
    phone               VARCHAR(20),
    contact_email       VARCHAR(100),
    partnership_start   DATE,               -- When we started working together
    is_active           BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE shelters IS 'Partner animal shelters that provide cats for adoption';


-- MENU_ITEMS: Food, beverages, and merchandise
-- Supports order tracking and revenue analysis
CREATE TABLE menu_items (
    item_id             SERIAL PRIMARY KEY,
    item_name           VARCHAR(100) NOT NULL,
    category            VARCHAR(50) NOT NULL
        CHECK (category IN ('Coffee', 'Tea', 'Pastry', 'Sandwich', 
                            'Dessert', 'Merchandise', 'Special')),
    price               DECIMAL(6,2) NOT NULL CHECK (price >= 0),
    cost                DECIMAL(6,2),        -- Our cost (for margin analysis)
    is_available        BOOLEAN DEFAULT TRUE,
    description         TEXT,
    introduced_date     DATE DEFAULT CURRENT_DATE,
    discontinued_date   DATE                 -- NULL if still available
);

COMMENT ON TABLE menu_items IS 'Cafe menu including food, beverages, and merchandise';


-- ------------------------------------------------------------------------------
-- 2.2 CORE ENTITY TABLES
-- ------------------------------------------------------------------------------
-- These represent the main "things" in our business: staff, cats, customers.
-- They have foreign keys referencing the lookup tables.
-- ------------------------------------------------------------------------------

-- STAFF: Cafe employees
-- Tracks who works at the cafe for scheduling and interaction attribution
CREATE TABLE staff (
    staff_id            SERIAL PRIMARY KEY,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    email               VARCHAR(100) UNIQUE NOT NULL,
    phone               VARCHAR(20),
    role                VARCHAR(50) NOT NULL
        CHECK (role IN ('Manager', 'Barista', 'Cat Care Specialist', 
                        'Adoption Coordinator', 'Part-Time')),
    hire_date           DATE NOT NULL,
    termination_date    DATE,               -- NULL if currently employed
    hourly_rate         DECIMAL(6,2),
    is_active           BOOLEAN DEFAULT TRUE
);

COMMENT ON TABLE staff IS 'Cafe employees with roles and employment information';
COMMENT ON COLUMN staff.termination_date IS 'NULL indicates currently employed';


-- CATS: The stars of the show!
-- Each cat has a breed, arrival information, and current status
CREATE TABLE cats (
    cat_id              SERIAL PRIMARY KEY,
    name                VARCHAR(50) NOT NULL,
    breed_id            INTEGER NOT NULL REFERENCES breeds(breed_id),
    color               VARCHAR(50),
    birth_date          DATE,               -- May be estimated for rescues
    arrival_date        DATE NOT NULL,
    adoption_date       DATE,               -- NULL if not yet adopted
    status              VARCHAR(20) DEFAULT 'available'
        CHECK (status IN ('available', 'adopted', 'medical_hold', 
                          'foster', 'permanent_resident')),
    shelter_id          INTEGER REFERENCES shelters(shelter_id),
    personality_notes   TEXT,               -- Staff observations
    medical_notes       TEXT,               -- Health information
    is_featured         BOOLEAN DEFAULT FALSE -- Highlighted on website?
);

COMMENT ON TABLE cats IS 'All cats that have been or are currently at the cafe';
COMMENT ON COLUMN cats.status IS 'Current status: available, adopted, medical_hold, foster, or permanent_resident';
COMMENT ON COLUMN cats.birth_date IS 'May be estimated for rescue cats';


-- CUSTOMERS: People who visit the cafe
-- Links to membership tier (optional) for discount calculations
CREATE TABLE customers (
    customer_id         SERIAL PRIMARY KEY,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    email               VARCHAR(100) UNIQUE NOT NULL,
    phone               VARCHAR(20),
    tier_id             INTEGER REFERENCES membership_tiers(tier_id),
    join_date           DATE NOT NULL DEFAULT CURRENT_DATE,
    birth_date          DATE,               -- For birthday promotions
    newsletter_opt_in   BOOLEAN DEFAULT FALSE,
    notes               TEXT                -- Staff notes about preferences
);

COMMENT ON TABLE customers IS 'Customer information including membership status';
COMMENT ON COLUMN customers.tier_id IS 'NULL indicates no membership (walk-in customer)';


-- ------------------------------------------------------------------------------
-- 2.3 TRANSACTIONAL AND JUNCTION TABLES
-- ------------------------------------------------------------------------------
-- These capture events (visits, orders) and many-to-many relationships.
-- They typically have multiple foreign keys.
-- ------------------------------------------------------------------------------

-- VISITS: Each time a customer comes to the cafe
-- Central to our business - links customers, staff, and enables interactions
CREATE TABLE visits (
    visit_id            SERIAL PRIMARY KEY,
    customer_id         INTEGER NOT NULL REFERENCES customers(customer_id),
    visit_date          DATE NOT NULL,
    check_in_time       TIME NOT NULL,
    check_out_time      TIME,               -- NULL if still visiting
    staff_id            INTEGER REFERENCES staff(staff_id), -- Who checked them in
    cover_charge        DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    discount_applied    DECIMAL(6,2) DEFAULT 0.00,
    notes               TEXT
);

COMMENT ON TABLE visits IS 'Customer visits to the cat lounge';
COMMENT ON COLUMN visits.check_out_time IS 'NULL indicates visit in progress';

-- Create indexes on frequently-queried columns for performance
-- Indexes are a form of structural metadata that improve query speed
CREATE INDEX idx_visits_date ON visits(visit_date);
CREATE INDEX idx_visits_customer ON visits(customer_id);


-- INTERACTIONS: What happens during a visit (junction between visits and cats)
-- This is a classic junction/bridge table resolving a many-to-many relationship:
-- One visit can involve many cats; one cat can have many visits.
CREATE TABLE interactions (
    interaction_id      SERIAL PRIMARY KEY,
    visit_id            INTEGER NOT NULL REFERENCES visits(visit_id),
    cat_id              INTEGER NOT NULL REFERENCES cats(cat_id),
    type_id             INTEGER NOT NULL REFERENCES interaction_types(type_id),
    duration_mins       INTEGER CHECK (duration_mins IS NULL OR duration_mins > 0),
    staff_id            INTEGER REFERENCES staff(staff_id), -- Staff who facilitated
    start_time          TIME,
    notes               TEXT,               -- Observations about the interaction
    
    -- Composite unique constraint prevents duplicate recordings
    UNIQUE (visit_id, cat_id, type_id, start_time)
);

COMMENT ON TABLE interactions IS 'Records of customer-cat interactions during visits';
CREATE INDEX idx_interactions_cat ON interactions(cat_id);
CREATE INDEX idx_interactions_visit ON interactions(visit_id);


-- ORDERS: Food and beverage purchases
-- Can be associated with a visit or standalone (walk-up counter purchase)
CREATE TABLE orders (
    order_id            SERIAL PRIMARY KEY,
    customer_id         INTEGER REFERENCES customers(customer_id),
    visit_id            INTEGER REFERENCES visits(visit_id), -- NULL if standalone
    staff_id            INTEGER REFERENCES staff(staff_id),
    order_datetime      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal            DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    tax                 DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    total               DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    payment_method      VARCHAR(20) 
        CHECK (payment_method IN ('cash', 'credit', 'debit', 'mobile', 'gift_card'))
);

COMMENT ON TABLE orders IS 'Food and merchandise orders';
CREATE INDEX idx_orders_datetime ON orders(order_datetime);


-- ORDER_ITEMS: Line items within an order
-- Normalized to support multiple items per order with quantities
CREATE TABLE order_items (
    order_item_id       SERIAL PRIMARY KEY,
    order_id            INTEGER NOT NULL REFERENCES orders(order_id),
    item_id             INTEGER NOT NULL REFERENCES menu_items(item_id),
    quantity            INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price          DECIMAL(6,2) NOT NULL,  -- Price at time of order
    line_total          DECIMAL(8,2) NOT NULL   -- quantity * unit_price
);

COMMENT ON TABLE order_items IS 'Individual items within orders';


-- ==============================================================================
-- SECTION 3: DATA POPULATION (DML - Data Manipulation Language)
-- ==============================================================================
-- 
-- EFFICIENT DATA LOADING WITH TRANSACTIONS
-- ----------------------------------------
-- We wrap all INSERT statements in a TRANSACTION. This provides:
-- 
-- 1. ATOMICITY: All inserts succeed or none do. If there's an error in the
--    middle, the database rolls back to its previous state.
-- 
-- 2. CONSISTENCY: Constraints are checked, ensuring referential integrity 
--    is maintained throughout.
-- 
-- 3. ISOLATION: Other database users won't see partial data while we're
--    loading. They see either the old state or the complete new state.
-- 
-- 4. DURABILITY: Once committed, the data is permanently saved even if
--    the system crashes.
-- 
-- These four properties are known as ACID and are fundamental to relational
-- database reliability.
--
-- WHY TRANSACTIONS MATTER FOR EFFICIENCY:
-- - Without a transaction, each INSERT would be auto-committed, requiring
--   a disk write and log flush for EACH statement.
-- - With a transaction, the database can batch these operations, writing
--   to disk only once at COMMIT time.
-- - For bulk loading, this can be 10-100x faster.
--
-- LOADING ORDER:
-- Just like table creation, we must insert data in dependency order:
-- 1. Tables with no foreign keys first
-- 2. Tables that reference those tables second
-- 3. Junction tables last
--
-- ==============================================================================

BEGIN TRANSACTION;


-- ------------------------------------------------------------------------------
-- 3.1 REFERENCE DATA
-- ------------------------------------------------------------------------------

-- MEMBERSHIP TIERS
-- These are relatively static - changed rarely by management
INSERT INTO membership_tiers (tier_name, monthly_price, visit_discount_pct) VALUES
    ('Walk-In',         0.00,   0.00),   -- No membership required
    ('Basic',          10.00,   0.10),   -- 10% discount
    ('Premium',        25.00,   0.25),   -- 25% discount
    ('Founding Member', 50.00,   0.40);  -- 40% discount (early supporters)


-- BREEDS
-- Reference data sourced from cat breed standards
INSERT INTO breeds (breed_name, avg_weight_lbs, typical_temperament, origin_country, avg_lifespan_years) VALUES
    ('Maine Coon',              15.0, 'Gentle, playful, good with strangers',           'United States',    13),
    ('Domestic Shorthair',      10.0, 'Varies widely - mixed heritage',                 'Various',          15),
    ('Siamese',                  9.0, 'Vocal, social, bonds strongly with people',      'Thailand',         15),
    ('Persian',                 11.0, 'Calm, quiet, prefers routine',                   'Iran',             15),
    ('Norwegian Forest Cat',    16.0, 'Independent, athletic, patient',                 'Norway',           14),
    ('British Shorthair',       14.0, 'Easygoing, affectionate, quiet',                 'United Kingdom',   15),
    ('Ragdoll',                 15.0, 'Docile, calm, follows people around',            'United States',    15),
    ('Abyssinian',               9.0, 'Active, playful, curious',                       'Ethiopia',         12),
    ('Bengal',                  12.0, 'Energetic, intelligent, needs stimulation',      'United States',    14),
    ('Scottish Fold',           10.0, 'Sweet-tempered, adaptable, loves attention',     'Scotland',         14);


-- INTERACTION TYPES
-- The activities we track between customers and cats
INSERT INTO interaction_types (type_name, description, base_duration_mins, requires_training) VALUES
    ('Lap Time',        'Cat sits in customer lap',                    15, FALSE),
    ('Play Session',    'Active play with toys (wands, lasers, etc.)', 20, FALSE),
    ('Petting',         'Gentle petting and scratching',               10, FALSE),
    ('Brushing',        'Customer helps groom the cat',                15, TRUE),
    ('Photo Session',   'Customer takes photos with cat',              10, FALSE),
    ('Feeding',         'Customer gives treats under staff guidance',   5, TRUE),
    ('Training',        'Basic training exercises with cat',           20, TRUE),
    ('Socialization',   'Helping shy cats adjust to people',           30, TRUE);


-- SHELTERS
-- Our partner organizations
INSERT INTO shelters (shelter_name, address, city, state, phone, contact_email, partnership_start, is_active) VALUES
    ('DC Humane Society',        '71 Oglethorpe St NW',    'Washington', 'DC', '202-555-0100', 'intake@dchumane.org',      '2022-06-01', TRUE),
    ('Lucky Cat Rescue',         '1550 14th St NW',        'Washington', 'DC', '202-555-0101', 'cats@luckycatdc.org',      '2022-08-15', TRUE),
    ('Arlington Animal Welfare', '2650 S Arlington Mill Dr','Arlington', 'VA', '703-555-0102', 'adopt@arlingtonawl.org',   '2023-01-10', TRUE),
    ('Montgomery County Shelter','14645 Rothgeb Dr',       'Rockville',  'MD', '301-555-0103', 'animals@montgomerycounty.gov', '2023-06-01', TRUE),
    ('Alley Cat Allies',         '7920 Norfolk Ave',       'Bethesda',   'MD', '240-555-0104', 'rescue@alleycatallies.org','2024-01-15', TRUE);


-- MENU ITEMS
-- Our food, beverage, and merchandise offerings
INSERT INTO menu_items (item_name, category, price, cost, description, introduced_date) VALUES
    -- Coffee (items 1-7)
    ('House Latte',         'Coffee',      5.50, 1.20, 'Espresso with steamed milk',                     '2022-06-01'),
    ('Cappuccino',          'Coffee',      5.00, 1.10, 'Equal parts espresso, steamed milk, foam',       '2022-06-01'),
    ('Americano',           'Coffee',      4.50, 0.90, 'Espresso with hot water',                        '2022-06-01'),
    ('Cold Brew',           'Coffee',      5.50, 1.00, '24-hour steeped, smooth and bold',               '2022-06-01'),
    ('Mocha',               'Coffee',      6.00, 1.50, 'Espresso, chocolate, steamed milk',              '2022-06-01'),
    ('Espresso',            'Coffee',      3.50, 0.70, 'Double shot of our house blend',                 '2022-06-01'),
    ('Catnip Latte',        'Coffee',      6.50, 1.80, 'Specialty latte with catnip honey (for humans!)', '2023-03-01'),
    
    -- Tea (items 8-11)
    ('Matcha Latte',        'Tea',         6.00, 1.60, 'Ceremonial grade matcha with oat milk',          '2022-06-01'),
    ('Earl Grey',           'Tea',         4.00, 0.50, 'Classic bergamot black tea',                     '2022-06-01'),
    ('Chamomile',           'Tea',         4.00, 0.45, 'Caffeine-free, calming herbal blend',            '2022-06-01'),
    ('Chai Latte',          'Tea',         5.50, 1.20, 'Spiced black tea with steamed milk',             '2022-06-01'),
    
    -- Pastry (items 12-15)
    ('Blueberry Muffin',    'Pastry',      4.00, 1.00, 'Fresh-baked daily',                              '2022-06-01'),
    ('Butter Croissant',    'Pastry',      3.50, 0.90, 'Flaky French-style',                             '2022-06-01'),
    ('Chocolate Chip Cookie','Pastry',     3.00, 0.60, 'Warm from the oven',                             '2022-06-01'),
    ('Cat Paw Cookie',      'Pastry',      4.50, 1.20, 'Paw-shaped shortbread with icing',               '2022-09-15'),
    
    -- Sandwiches (items 16-18)
    ('Avocado Toast',       'Sandwich',    9.50, 3.00, 'Sourdough, avocado, everything seasoning',       '2022-06-01'),
    ('Grilled Cheese',      'Sandwich',    8.00, 2.20, 'Three cheeses on sourdough',                     '2022-06-01'),
    ('Caprese Panini',      'Sandwich',    10.00, 3.50, 'Fresh mozzarella, tomato, basil',               '2023-01-15'),
    
    -- Dessert (items 19-20)
    ('Cat Face Cake Slice', 'Dessert',     7.00, 2.00, 'Vanilla cake decorated like a cat face',         '2022-06-01'),
    ('Ice Cream Sundae',    'Dessert',     8.00, 2.50, 'Two scoops with toppings',                       '2023-06-01'),
    
    -- Merchandise (items 21-25)
    ('Cat Cafe T-Shirt',    'Merchandise', 25.00, 8.00, 'Whiskers & Waffles logo tee',                   '2022-06-01'),
    ('Catnip Toy',          'Merchandise',  8.00, 2.50, 'Handmade felt mouse with organic catnip',       '2022-06-01'),
    ('Coffee Mug',          'Merchandise', 15.00, 4.00, 'Ceramic mug with cafe logo',                    '2022-06-01'),
    ('Tote Bag',            'Merchandise', 18.00, 5.00, 'Canvas tote with cat illustrations',            '2023-04-01'),
    ('Cat Calendar',        'Merchandise', 20.00, 6.00, 'Annual calendar featuring our cats',            '2024-01-01');


-- ------------------------------------------------------------------------------
-- 3.2 ENTITY DATA
-- ------------------------------------------------------------------------------

-- STAFF
-- Our team members with realistic hire dates showing turnover
INSERT INTO staff (first_name, last_name, email, phone, role, hire_date, termination_date, hourly_rate, is_active) VALUES
    ('Riley',   'Chen',        'riley.chen@whiskerswaffles.com',    '202-555-1001', 'Manager',              '2022-05-15', NULL,         32.00, TRUE),
    ('Jordan',  'Rivera',      'jordan.r@whiskerswaffles.com',      '202-555-1002', 'Cat Care Specialist',  '2022-06-01', NULL,         20.00, TRUE),
    ('Alex',    'Kim',         'alex.kim@whiskerswaffles.com',      '202-555-1003', 'Barista',              '2022-06-01', NULL,         17.00, TRUE),
    ('Sam',     'Washington',  'sam.w@whiskerswaffles.com',         '202-555-1004', 'Adoption Coordinator', '2022-08-01', NULL,         22.00, TRUE),
    ('Casey',   'Morgan',      'casey.m@whiskerswaffles.com',       '202-555-1005', 'Barista',              '2023-03-15', NULL,         17.00, TRUE),
    ('Taylor',  'Brooks',      'taylor.b@whiskerswaffles.com',      '202-555-1006', 'Cat Care Specialist',  '2023-09-01', NULL,         19.00, TRUE),
    ('Morgan',  'Patel',       'morgan.p@whiskerswaffles.com',      '202-555-1007', 'Part-Time',            '2024-01-15', NULL,         16.00, TRUE),
    ('Jamie',   'OBrien',      'jamie.ob@whiskerswaffles.com',      '202-555-1008', 'Barista',              '2022-06-01', '2023-08-31', 16.00, FALSE),
    ('Drew',    'Martinez',    'drew.m@whiskerswaffles.com',        '202-555-1009', 'Part-Time',            '2023-06-01', '2024-06-30', 16.00, FALSE);


-- CATS
-- Our feline residents with arrival dates spanning 2+ years for trend analysis
-- Status distribution: some adopted, some available, medical hold, permanent resident
INSERT INTO cats (name, breed_id, color, birth_date, arrival_date, adoption_date, status, shelter_id, personality_notes, is_featured) VALUES
    -- 2022 arrivals (early cats)
    ('Whiskers',    1, 'Orange tabby',     '2020-04-15', '2022-06-15', NULL,         'permanent_resident', 1, 'Original cafe cat. Loves lap time, great with new visitors.', TRUE),
    ('Shadow',      2, 'Black',            '2021-01-10', '2022-07-01', '2022-11-15', 'adopted', 1, 'Initially shy, warmed up beautifully. Adopted by regular.', FALSE),
    ('Mittens',     2, 'Gray and white',   '2019-08-20', '2022-07-15', '2023-02-28', 'adopted', 1, 'Senior cat, very calm. Perfect for quiet visitors.', FALSE),
    ('Luna',        3, 'Seal point',       '2021-06-05', '2022-08-01', '2023-01-20', 'adopted', 2, 'Very vocal and social. Would follow visitors around.', FALSE),
    
    -- 2023 arrivals
    ('Thor',        5, 'Brown tabby',      '2020-11-20', '2023-01-10', NULL,         'available', 2, 'Large and fluffy, loves brushing sessions. Very patient.', TRUE),
    ('Mochi',       3, 'Chocolate point',  '2022-06-10', '2023-02-15', '2023-09-10', 'adopted', 2, 'Energetic and playful. Great with kids.', FALSE),
    ('Duchess',     4, 'White',            '2019-03-15', '2023-04-01', NULL,         'medical_hold', 3, 'Elegant and quiet. Currently recovering from dental surgery.', FALSE),
    ('Biscuit',     6, 'Blue (gray)',      '2022-04-01', '2023-05-20', NULL,         'available', 3, 'Sweet and easygoing. Gets along with everyone.', FALSE),
    ('Cleo',        8, 'Ruddy',            '2021-09-15', '2023-07-01', '2024-01-15', 'adopted', 1, 'Very active and curious. Needed experienced adopter.', FALSE),
    ('Jasper',      9, 'Brown spotted',    '2022-01-20', '2023-08-15', NULL,         'available', 4, 'Intelligent and energetic. Loves interactive toys.', TRUE),
    ('Olive',       7, 'Seal mitted',      '2023-01-05', '2023-09-01', NULL,         'available', 4, 'Extremely docile. Will go limp when picked up.', FALSE),
    
    -- 2024 arrivals
    ('Pumpkin',     2, 'Orange',           '2022-10-15', '2024-01-20', '2024-07-20', 'adopted', 1, 'Friendly and outgoing. Adopted quickly!', FALSE),
    ('Hazel',      10, 'Gray folded ears', '2023-03-10', '2024-02-01', NULL,         'available', 3, 'Sweet and adaptable. Loves to be near people.', FALSE),
    ('Maple',       2, 'Tortoiseshell',    '2021-04-25', '2024-04-15', NULL,         'available', 5, 'Independent but affectionate when ready.', FALSE),
    ('Finn',        1, 'Silver tabby',     '2023-08-01', '2024-06-01', NULL,         'available', 5, 'Young Maine Coon, still growing! Very playful.', TRUE),
    ('Willow',      7, 'Blue bicolor',     '2023-05-20', '2024-08-01', NULL,         'available', 2, 'Gentle and quiet. Perfect for calm visitors.', FALSE),
    ('Nugget',      6, 'Golden',           '2024-01-10', '2024-09-15', NULL,         'available', 4, 'Kitten! Playful and full of energy.', TRUE),
    
    -- 2025 arrivals (recent)
    ('Pepper',      2, 'Black and white',  '2022-07-15', '2025-01-05', NULL,         'available', 1, 'Tuxedo cat, very dapper. Enjoys chin scratches.', FALSE);


-- CUSTOMERS
-- Mix of members and non-members, join dates spanning the business history
INSERT INTO customers (first_name, last_name, email, phone, tier_id, join_date, birth_date, newsletter_opt_in, notes) VALUES
    -- Founding members (early 2022)
    ('Maya',      'Chen',       'maya.chen@email.com',       '202-555-2001', 4, '2022-06-01', '1990-03-15', TRUE,  'Original founding member. Visits weekly. Loves Whiskers.'),
    ('James',     'Wilson',     'jwilson@email.com',         '202-555-2002', 4, '2022-06-01', '1985-07-22', TRUE,  'Founding member. Prefers quiet cats.'),
    
    -- Premium members
    ('Sofia',     'Rodriguez',  'sofia.r@email.com',         '202-555-2003', 3, '2022-08-15', '1995-11-08', TRUE,  'Premium member. Often brings friends.'),
    ('Aiden',     'Patel',      'aiden.p@email.com',         '202-555-2004', 3, '2022-10-01', '1992-01-30', TRUE,  'Premium member. Adopted Shadow!'),
    ('Emma',      'Thompson',   'emma.t@email.com',          '202-555-2005', 3, '2023-02-14', '1988-02-14', TRUE,  'Premium member. Photography enthusiast.'),
    
    -- Basic members
    ('Marcus',    'Johnson',    'marcus.j@email.com',        '202-555-2006', 2, '2023-04-01', '1998-05-20', TRUE,  'Basic member. Graduate student, visits on weekends.'),
    ('Lily',      'Kim',        'lily.kim@email.com',        '202-555-2007', 2, '2023-06-15', '1994-09-12', FALSE, 'Basic member. Allergic to some breeds but loves cats.'),
    ('David',     'Garcia',     'dgarcia@email.com',         '202-555-2008', 2, '2023-09-01', '2000-12-03', TRUE,  'Basic member. Considering adoption.'),
    ('Priya',     'Sharma',     'priya.s@email.com',         '202-555-2009', 2, '2024-01-10', '1996-04-18', TRUE,  'Basic member. Works from cafe sometimes.'),
    ('Nathan',    'Lee',        'nathan.lee@email.com',      '202-555-2010', 2, '2024-05-20', '1993-08-25', FALSE, 'Basic member. Cat photography hobby.'),
    
    -- Walk-in customers (tier_id = 1)
    ('Olivia',    'Brown',      'obrown@email.com',          '202-555-2011', 1, '2023-03-10', '1991-06-30', FALSE, 'Occasional visitor. Lives nearby.'),
    ('Ethan',     'Davis',      'ethan.d@email.com',         '202-555-2012', 1, '2023-07-22', '1999-03-05', FALSE, 'First-time visitor, became regular.'),
    ('Ava',       'Martinez',   'ava.m@email.com',           '202-555-2013', 1, '2023-11-15', '1997-10-11', TRUE,  'Interested in volunteering.'),
    ('Lucas',     'Anderson',   'lucas.a@email.com',         '202-555-2014', 1, '2024-02-28', '2001-07-19', FALSE, 'College student. Visits during breaks.'),
    ('Mia',       'Taylor',     'mia.taylor@email.com',      '202-555-2015', 1, '2024-06-10', '1989-11-27', TRUE,  'Adopted Pumpkin!'),
    
    -- No membership (NULL tier_id - pure walk-ins)
    ('Noah',      'Thomas',     'noah.t@email.com',          '202-555-2016', NULL, '2024-08-01', NULL,       FALSE, 'Tourist, one-time visitor.'),
    ('Isabella',  'Jackson',    'isabella.j@email.com',      '202-555-2017', NULL, '2024-09-15', '1994-02-08', FALSE, 'Considering membership.'),
    ('Liam',      'White',      'liam.w@email.com',          '202-555-2018', NULL, '2024-11-01', NULL,       FALSE, 'Referred by friend.'),
    ('Charlotte', 'Harris',     'charlotte.h@email.com',     '202-555-2019', NULL, '2025-01-02', '1996-12-15', TRUE,  'New visitor, very enthusiastic.');


-- ------------------------------------------------------------------------------
-- 3.3 TRANSACTIONAL DATA - VISITS
-- ------------------------------------------------------------------------------
-- This section contains visits spanning 2+ years with patterns:
-- - More visits on weekends (realistic)
-- - Growth over time as business established
-- - Regular customers visit more frequently
-- ------------------------------------------------------------------------------

INSERT INTO visits (customer_id, visit_date, check_in_time, check_out_time, staff_id, cover_charge, discount_applied, notes) VALUES
    -- 2022 visits (early business, fewer visits)
    (1, '2022-06-15', '14:00', '15:30', 1, 15.00, 6.00, 'Grand opening day! Maya was first customer.'),
    (2, '2022-06-15', '14:30', '16:00', 1, 15.00, 6.00, 'Grand opening day.'),
    (1, '2022-06-22', '10:00', '11:30', 2, 15.00, 6.00, NULL),
    (3, '2022-08-20', '13:00', '14:30', 3, 15.00, 3.75, 'First visit after joining as premium member.'),
    (1, '2022-09-10', '11:00', '12:30', 2, 15.00, 6.00, NULL),
    (2, '2022-09-17', '14:00', '15:00', 3, 15.00, 6.00, NULL),
    (4, '2022-10-08', '10:30', '12:00', 2, 15.00, 3.75, 'Interested in Shadow.'),
    (1, '2022-10-15', '14:00', '16:00', 1, 15.00, 6.00, 'Brought a friend.'),
    (4, '2022-10-29', '11:00', '13:00', 2, 15.00, 3.75, 'Long visit with Shadow.'),
    (3, '2022-11-05', '13:00', '14:00', 3, 15.00, 3.75, NULL),
    (4, '2022-11-12', '10:00', '12:00', 4, 15.00, 3.75, 'Completed adoption paperwork for Shadow!'),
    (1, '2022-11-19', '14:00', '15:30', 2, 15.00, 6.00, NULL),
    (2, '2022-12-03', '11:00', '12:30', 3, 15.00, 6.00, NULL),
    (1, '2022-12-17', '10:00', '11:30', 1, 15.00, 6.00, 'Holiday visit.'),
    
    -- 2023 visits (business growing)
    (1, '2023-01-07', '14:00', '15:30', 2, 15.00, 6.00, 'New year visit.'),
    (3, '2023-01-14', '11:00', '12:30', 3, 15.00, 3.75, NULL),
    (2, '2023-01-21', '13:00', '14:30', 2, 15.00, 6.00, NULL),
    (5, '2023-02-14', '15:00', '17:00', 1, 15.00, 3.75, 'Valentine Day date! Joined as premium.'),
    (1, '2023-02-18', '10:00', '11:30', 2, 15.00, 6.00, NULL),
    (3, '2023-02-25', '14:00', '15:30', 3, 15.00, 3.75, 'Brought boyfriend.'),
    (11, '2023-03-11', '12:00', '13:00', 3, 15.00, 0.00, 'First visit, walk-in.'),
    (1, '2023-03-18', '11:00', '12:30', 2, 15.00, 6.00, NULL),
    (6, '2023-04-01', '14:00', '15:30', 1, 15.00, 1.50, 'First visit as basic member.'),
    (5, '2023-04-08', '10:00', '12:00', 2, 15.00, 3.75, 'Photo session with multiple cats.'),
    (1, '2023-04-15', '13:00', '14:30', 3, 15.00, 6.00, NULL),
    (2, '2023-04-22', '11:00', '12:30', 2, 15.00, 6.00, NULL),
    (3, '2023-05-06', '14:00', '16:00', 1, 15.00, 3.75, NULL),
    (11, '2023-05-13', '12:00', '13:30', 3, 15.00, 0.00, NULL),
    (1, '2023-05-20', '10:00', '11:30', 2, 15.00, 6.00, NULL),
    (7, '2023-06-17', '14:00', '15:00', 3, 15.00, 1.50, 'First visit.'),
    (6, '2023-06-24', '11:00', '12:30', 2, 15.00, 1.50, NULL),
    (1, '2023-07-01', '13:00', '14:30', 1, 15.00, 6.00, NULL),
    (5, '2023-07-08', '10:00', '12:00', 2, 15.00, 3.75, NULL),
    (12, '2023-07-22', '15:00', '16:30', 3, 15.00, 0.00, 'First visit, very enthusiastic.'),
    (3, '2023-07-29', '14:00', '15:30', 2, 15.00, 3.75, NULL),
    (1, '2023-08-05', '11:00', '12:30', 1, 15.00, 6.00, NULL),
    (8, '2023-09-02', '13:00', '14:30', 3, 15.00, 1.50, 'First visit as basic member.'),
    (6, '2023-09-09', '10:00', '11:30', 2, 15.00, 1.50, NULL),
    (1, '2023-09-16', '14:00', '15:30', 1, 15.00, 6.00, NULL),
    (12, '2023-09-23', '11:00', '13:00', 2, 15.00, 0.00, NULL),
    (7, '2023-10-07', '14:00', '15:00', 3, 15.00, 1.50, NULL),
    (5, '2023-10-14', '10:00', '11:30', 2, 15.00, 3.75, NULL),
    (1, '2023-10-21', '13:00', '14:30', 1, 15.00, 6.00, NULL),
    (3, '2023-10-28', '15:00', '16:30', 3, 15.00, 3.75, 'Halloween event visit.'),
    (8, '2023-11-04', '11:00', '12:30', 2, 15.00, 1.50, NULL),
    (13, '2023-11-18', '14:00', '15:30', 1, 15.00, 0.00, 'First visit.'),
    (1, '2023-11-25', '10:00', '11:30', 2, 15.00, 6.00, 'Post-Thanksgiving visit.'),
    (6, '2023-12-02', '13:00', '14:30', 3, 15.00, 1.50, NULL),
    (12, '2023-12-09', '14:00', '15:30', 2, 15.00, 0.00, NULL),
    (5, '2023-12-16', '11:00', '12:30', 1, 15.00, 3.75, NULL),
    (1, '2023-12-23', '10:00', '11:00', 2, 15.00, 6.00, 'Quick holiday visit.'),
    
    -- 2024 visits (business established, more traffic)
    (9, '2024-01-13', '14:00', '15:30', 3, 15.00, 1.50, 'First visit as basic member.'),
    (1, '2024-01-20', '11:00', '12:30', 2, 15.00, 6.00, NULL),
    (8, '2024-01-27', '13:00', '14:30', 1, 15.00, 1.50, NULL),
    (6, '2024-02-03', '10:00', '11:30', 2, 15.00, 1.50, NULL),
    (5, '2024-02-10', '14:00', '16:00', 3, 15.00, 3.75, 'Valentine week special.'),
    (14, '2024-02-28', '15:00', '16:30', 2, 15.00, 0.00, 'First visit.'),
    (1, '2024-03-02', '11:00', '12:30', 1, 15.00, 6.00, NULL),
    (3, '2024-03-09', '14:00', '15:30', 3, 15.00, 3.75, NULL),
    (9, '2024-03-16', '10:00', '12:00', 2, 15.00, 1.50, 'Worked from cafe.'),
    (12, '2024-03-23', '13:00', '14:30', 1, 15.00, 0.00, NULL),
    (7, '2024-03-30', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (1, '2024-04-06', '11:00', '12:30', 2, 15.00, 6.00, NULL),
    (6, '2024-04-13', '10:00', '11:30', 1, 15.00, 1.50, NULL),
    (8, '2024-04-20', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (5, '2024-04-27', '13:00', '14:30', 2, 15.00, 3.75, NULL),
    (10, '2024-05-04', '11:00', '12:30', 1, 15.00, 1.50, 'First visit.'),
    (1, '2024-05-11', '14:00', '15:30', 3, 15.00, 6.00, 'Mother Day weekend.'),
    (3, '2024-05-18', '10:00', '12:00', 2, 15.00, 3.75, NULL),
    (10, '2024-05-25', '13:00', '14:30', 1, 15.00, 1.50, 'Photo session.'),
    (9, '2024-06-01', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (15, '2024-06-08', '11:00', '13:00', 2, 15.00, 0.00, 'First visit. Loves Pumpkin!'),
    (1, '2024-06-15', '10:00', '11:30', 1, 15.00, 6.00, 'Anniversary visit - 2 years!'),
    (6, '2024-06-22', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (15, '2024-06-29', '13:00', '14:30', 2, 15.00, 0.00, NULL),
    (12, '2024-07-06', '11:00', '12:30', 1, 15.00, 0.00, NULL),
    (8, '2024-07-13', '14:00', '16:00', 3, 15.00, 1.50, NULL),
    (15, '2024-07-20', '10:00', '12:00', 2, 15.00, 0.00, 'Adopted Pumpkin today!'),
    (1, '2024-07-27', '13:00', '14:30', 1, 15.00, 6.00, NULL),
    (16, '2024-08-03', '14:00', '15:30', 3, 15.00, 15.00, 'Tourist, first visit.'),
    (5, '2024-08-10', '11:00', '12:30', 2, 15.00, 3.75, NULL),
    (9, '2024-08-17', '10:00', '11:30', 1, 15.00, 1.50, NULL),
    (3, '2024-08-24', '14:00', '15:30', 3, 15.00, 3.75, NULL),
    (7, '2024-08-31', '13:00', '14:30', 2, 15.00, 1.50, NULL),
    (17, '2024-09-07', '11:00', '12:30', 1, 15.00, 15.00, 'First visit.'),
    (1, '2024-09-14', '14:00', '15:30', 3, 15.00, 6.00, NULL),
    (10, '2024-09-21', '10:00', '12:00', 2, 15.00, 1.50, 'Photographed Nugget.'),
    (6, '2024-09-28', '13:00', '14:30', 1, 15.00, 1.50, NULL),
    (8, '2024-10-05', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (12, '2024-10-12', '11:00', '12:30', 2, 15.00, 0.00, NULL),
    (5, '2024-10-19', '10:00', '11:30', 1, 15.00, 3.75, NULL),
    (1, '2024-10-26', '14:00', '16:00', 3, 15.00, 6.00, 'Halloween event.'),
    (18, '2024-11-02', '13:00', '14:30', 2, 15.00, 15.00, 'First visit. Referred by friend.'),
    (9, '2024-11-09', '11:00', '12:30', 1, 15.00, 1.50, NULL),
    (3, '2024-11-16', '14:00', '15:30', 3, 15.00, 3.75, NULL),
    (17, '2024-11-23', '10:00', '11:30', 2, 15.00, 15.00, NULL),
    (1, '2024-11-30', '13:00', '14:30', 1, 15.00, 6.00, NULL),
    (6, '2024-12-07', '14:00', '15:30', 3, 15.00, 1.50, NULL),
    (5, '2024-12-14', '11:00', '13:00', 2, 15.00, 3.75, 'Holiday photos.'),
    (10, '2024-12-21', '10:00', '11:30', 1, 15.00, 1.50, NULL),
    (1, '2024-12-28', '14:00', '15:30', 3, 15.00, 6.00, NULL),
    
    -- 2025 visits (January)
    (19, '2025-01-04', '11:00', '12:30', 2, 15.00, 15.00, 'First visit, very enthusiastic!'),
    (8, '2025-01-04', '13:00', '14:30', 2, 15.00, 1.50, NULL),
    (1, '2025-01-11', '14:00', '15:30', 1, 15.00, 6.00, NULL),
    (3, '2025-01-11', '10:00', '11:30', 1, 15.00, 3.75, NULL),
    (19, '2025-01-11', '15:30', '17:00', 1, 15.00, 15.00, 'Second visit already!');


-- ------------------------------------------------------------------------------
-- 3.4 TRANSACTIONAL DATA - INTERACTIONS
-- ------------------------------------------------------------------------------
-- Links visits to cats with activity types
-- Critical for analyzing cat popularity and adoption correlation
-- ------------------------------------------------------------------------------

INSERT INTO interactions (visit_id, cat_id, type_id, duration_mins, staff_id, start_time, notes) VALUES
    -- 2022 interactions
    (1, 1, 1, 30, 2, '14:15', 'Whiskers immediately went to Maya lap.'),
    (1, 2, 3, 20, 2, '14:50', NULL),
    (2, 1, 1, 25, 2, '14:45', NULL),
    (2, 3, 3, 20, 2, '15:15', 'Mittens very relaxed.'),
    (3, 1, 2, 25, 2, '10:15', 'Active play session.'),
    (4, 4, 1, 30, 2, '13:15', 'Luna very social.'),
    (5, 1, 1, 35, 2, '11:15', NULL),
    (6, 1, 2, 20, 3, '14:15', NULL),
    (7, 2, 3, 40, 2, '10:45', 'Long session with Shadow - bonding.'),
    (8, 1, 1, 25, 2, '14:15', NULL),
    (8, 4, 2, 30, 2, '14:45', NULL),
    (9, 2, 1, 50, 2, '11:15', 'Shadow spent whole time in Aiden lap.'),
    (9, 2, 4, 30, 2, '12:10', 'Brushing session - Shadow loved it.'),
    (10, 4, 3, 25, 3, '13:15', NULL),
    (11, 2, 1, 45, 4, '10:15', 'Final visit before adoption!'),
    (12, 1, 2, 30, 2, '14:15', NULL),
    (13, 1, 1, 35, 3, '11:15', NULL),
    (14, 1, 1, 25, 2, '10:15', NULL),
    (14, 3, 3, 20, 2, '10:45', NULL),
    
    -- 2023 interactions (more variety as cat roster grows)
    (15, 1, 1, 30, 2, '14:15', NULL),
    (15, 5, 4, 25, 2, '14:50', 'Thor loves brushing!'),
    (16, 4, 1, 35, 3, '11:15', NULL),
    (17, 1, 2, 20, 2, '13:15', NULL),
    (18, 6, 2, 40, 2, '15:15', 'Great play session with Mochi.'),
    (19, 1, 1, 30, 2, '10:15', NULL),
    (20, 8, 3, 25, 3, '14:15', 'Biscuit very friendly.'),
    (21, 5, 4, 30, 3, '12:15', NULL),
    (22, 1, 1, 30, 2, '10:15', NULL),
    (22, 9, 2, 25, 2, '10:50', 'Cleo very active.'),
    (23, 6, 2, 35, 3, '14:15', NULL),
    (24, 1, 1, 30, 2, '11:15', NULL),
    (25, 5, 4, 40, 1, '14:15', NULL),
    (26, 8, 1, 30, 3, '14:15', NULL),
    (27, 1, 2, 25, 2, '10:15', NULL),
    (28, 10, 2, 35, 3, '14:15', 'Jasper loves interactive toys.'),
    (29, 8, 3, 25, 2, '11:15', NULL),
    (30, 1, 1, 30, 1, '13:15', NULL),
    (31, 6, 2, 40, 2, '10:15', NULL),
    (32, 11, 1, 50, 3, '15:15', 'Olive is so docile!'),
    (33, 5, 4, 30, 2, '14:15', NULL),
    (34, 1, 2, 25, 1, '11:15', NULL),
    (35, 9, 2, 35, 3, '13:15', NULL),
    (36, 10, 2, 40, 2, '10:15', NULL),
    (37, 1, 1, 30, 1, '14:15', NULL),
    (38, 8, 3, 25, 2, '11:15', NULL),
    (39, 5, 4, 35, 3, '14:15', NULL),
    (40, 11, 1, 40, 2, '10:15', NULL),
    (41, 1, 2, 30, 1, '13:15', NULL),
    (42, 10, 2, 35, 3, '15:30', 'Halloween themed play.'),
    (43, 8, 1, 30, 2, '11:15', NULL),
    (44, 9, 3, 25, 1, '14:15', NULL),
    (45, 1, 1, 25, 2, '10:15', NULL),
    (46, 5, 4, 30, 3, '13:15', NULL),
    (47, 11, 1, 35, 2, '14:15', NULL),
    (48, 1, 2, 25, 1, '11:15', NULL),
    (49, 1, 1, 20, 2, '10:15', 'Quick visit.'),
    
    -- 2024 interactions (established patterns, newer cats)
    (50, 12, 3, 30, 3, '14:15', 'Pumpkin very outgoing.'),
    (51, 1, 1, 30, 2, '11:15', NULL),
    (52, 10, 2, 35, 1, '13:15', NULL),
    (53, 8, 1, 25, 2, '10:15', NULL),
    (54, 13, 3, 40, 3, '14:15', 'Hazel adapting well.'),
    (55, 5, 4, 30, 2, '15:15', NULL),
    (56, 1, 2, 25, 1, '11:15', NULL),
    (57, 12, 2, 35, 3, '14:15', NULL),
    (58, 14, 3, 40, 2, '10:15', 'Maple warming up.'),
    (59, 10, 5, 30, 1, '13:15', 'Photo session.'),
    (60, 8, 1, 25, 3, '14:15', NULL),
    (61, 1, 1, 30, 2, '11:15', NULL),
    (62, 5, 4, 35, 1, '10:15', NULL),
    (63, 12, 2, 30, 3, '14:15', NULL),
    (64, 15, 2, 40, 2, '13:15', 'Finn is so playful!'),
    (65, 1, 5, 25, 1, '11:15', 'Anniversary photos.'),
    (66, 8, 3, 30, 3, '14:15', NULL),
    (67, 12, 1, 45, 2, '13:15', 'Strong bond forming.'),
    (68, 13, 3, 25, 1, '11:15', NULL),
    (69, 10, 2, 35, 3, '14:15', NULL),
    (70, 12, 1, 50, 2, '10:15', 'Adoption day for Pumpkin!'),
    (71, 1, 1, 30, 1, '13:15', NULL),
    (72, 16, 3, 25, 3, '14:15', 'Tourist enjoying experience.'),
    (73, 5, 4, 35, 2, '11:15', NULL),
    (74, 15, 2, 40, 1, '10:15', NULL),
    (75, 14, 1, 30, 3, '14:15', NULL),
    (76, 8, 3, 25, 2, '13:15', NULL),
    (77, 17, 3, 30, 1, '11:15', NULL),
    (78, 1, 2, 30, 3, '14:15', NULL),
    (79, 17, 5, 45, 2, '10:15', 'Nugget photo session - adorable!'),
    (80, 10, 2, 35, 1, '13:15', NULL),
    (81, 8, 1, 25, 3, '14:15', NULL),
    (82, 15, 2, 30, 2, '11:15', NULL),
    (83, 5, 4, 35, 1, '10:15', NULL),
    (84, 1, 1, 45, 3, '14:15', 'Halloween lap time marathon.'),
    (84, 17, 2, 30, 3, '15:00', NULL),
    (85, 13, 3, 25, 2, '13:15', NULL),
    (86, 10, 2, 30, 1, '11:15', NULL),
    (87, 14, 1, 35, 3, '14:15', NULL),
    (88, 8, 3, 25, 2, '10:15', NULL),
    (89, 1, 1, 30, 1, '13:15', NULL),
    (90, 5, 4, 35, 3, '14:15', NULL),
    (91, 15, 2, 40, 2, '11:15', 'Holiday play session.'),
    (92, 17, 5, 30, 1, '10:15', 'Holiday photos.'),
    (93, 1, 2, 25, 3, '14:15', NULL),
    
    -- 2025 interactions (January)
    (94, 18, 3, 30, 2, '11:15', 'Pepper settling in well.'),
    (95, 8, 1, 35, 2, '13:15', NULL),
    (96, 1, 1, 30, 1, '14:15', NULL),
    (96, 5, 4, 25, 1, '14:50', NULL),
    (97, 17, 2, 35, 1, '10:15', NULL),
    (98, 18, 3, 25, 1, '15:45', NULL),
    (98, 15, 2, 35, 1, '16:15', 'Charlotte loved the younger cats.');


-- ------------------------------------------------------------------------------
-- 3.5 TRANSACTIONAL DATA - ORDERS AND ORDER ITEMS
-- ------------------------------------------------------------------------------

INSERT INTO orders (customer_id, visit_id, staff_id, order_datetime, subtotal, tax, total, payment_method) VALUES
    (1, 1, 3, '2022-06-15 14:30:00', 12.00, 0.72, 12.72, 'credit'),
    (1, 3, 3, '2022-06-22 10:30:00', 9.50, 0.57, 10.07, 'credit'),
    (3, 4, 3, '2022-08-20 13:30:00', 11.00, 0.66, 11.66, 'credit'),
    (1, 5, 3, '2022-09-10 11:30:00', 5.50, 0.33, 5.83, 'mobile'),
    (2, 6, 3, '2022-09-17 14:30:00', 10.00, 0.60, 10.60, 'debit'),
    (1, 8, 3, '2022-10-15 14:30:00', 14.50, 0.87, 15.37, 'credit'),
    (5, 18, 5, '2023-02-14 15:30:00', 25.00, 1.50, 26.50, 'credit'),
    (6, 23, 3, '2023-04-01 14:30:00', 8.50, 0.51, 9.01, 'mobile'),
    (5, 24, 3, '2023-04-08 11:00:00', 11.50, 0.69, 12.19, 'credit'),
    (1, 25, 3, '2023-04-15 13:30:00', 9.50, 0.57, 10.07, 'mobile'),
    (12, 34, 3, '2023-07-22 15:30:00', 19.00, 1.14, 20.14, 'debit'),
    (8, 37, 3, '2023-09-02 13:30:00', 15.50, 0.93, 16.43, 'credit'),
    (5, 42, 3, '2023-10-14 10:30:00', 14.00, 0.84, 14.84, 'mobile'),
    (1, 52, 3, '2024-01-20 11:30:00', 9.00, 0.54, 9.54, 'mobile'),
    (5, 55, 3, '2024-02-10 14:30:00', 20.00, 1.20, 21.20, 'credit'),
    (9, 59, 3, '2024-03-16 11:30:00', 14.50, 0.87, 15.37, 'credit'),
    (10, 69, 3, '2024-05-25 13:30:00', 8.00, 0.48, 8.48, 'debit'),
    (1, 72, 1, '2024-06-15 10:30:00', 40.00, 2.40, 42.40, 'credit'),
    (15, 77, 3, '2024-07-20 11:30:00', 59.00, 3.54, 62.54, 'credit'),
    (10, 86, 3, '2024-09-21 11:30:00', 8.00, 0.48, 8.48, 'mobile'),
    (1, 91, 3, '2024-10-26 15:00:00', 10.00, 0.60, 10.60, 'mobile'),
    (5, 98, 3, '2024-12-14 12:00:00', 20.00, 1.20, 21.20, 'credit'),
    (19, 101, 5, '2025-01-04 11:30:00', 15.50, 0.93, 16.43, 'credit'),
    (1, 103, 3, '2025-01-11 14:30:00', 9.50, 0.57, 10.07, 'mobile');


-- Order items (references menu_items by item_id)
INSERT INTO order_items (order_id, item_id, quantity, unit_price, line_total) VALUES
    (1, 1, 1, 5.50, 5.50),      -- House Latte
    (1, 13, 1, 3.50, 3.50),     -- Butter Croissant
    (1, 14, 1, 3.00, 3.00),     -- Chocolate Chip Cookie
    (2, 16, 1, 9.50, 9.50),     -- Avocado Toast
    (3, 1, 2, 5.50, 11.00),     -- 2 House Lattes
    (4, 1, 1, 5.50, 5.50),      -- House Latte
    (5, 8, 1, 6.00, 6.00),      -- Matcha Latte
    (5, 9, 1, 4.00, 4.00),      -- Earl Grey (for free - correction needed)
    (6, 5, 1, 6.00, 6.00),      -- Mocha
    (6, 12, 1, 4.00, 4.00),     -- Blueberry Muffin
    (6, 15, 1, 4.50, 4.50),     -- Cat Paw Cookie
    (7, 21, 1, 25.00, 25.00),   -- T-Shirt (Valentine gift)
    (8, 2, 1, 5.00, 5.00),      -- Cappuccino
    (8, 13, 1, 3.50, 3.50),     -- Butter Croissant
    (9, 1, 1, 5.50, 5.50),      -- House Latte
    (9, 8, 1, 6.00, 6.00),      -- Matcha Latte
    (10, 16, 1, 9.50, 9.50),    -- Avocado Toast
    (11, 7, 1, 6.50, 6.50),     -- Catnip Latte
    (11, 12, 2, 4.00, 8.00),    -- 2 Blueberry Muffins
    (11, 15, 1, 4.50, 4.50),    -- Cat Paw Cookie
    (12, 11, 1, 5.50, 5.50),    -- Chai Latte
    (12, 18, 1, 10.00, 10.00),  -- Caprese Panini
    (13, 3, 1, 4.50, 4.50),     -- Americano
    (13, 16, 1, 9.50, 9.50),    -- Avocado Toast
    (14, 1, 1, 5.50, 5.50),     -- House Latte
    (14, 13, 1, 3.50, 3.50),    -- Butter Croissant
    (15, 5, 2, 6.00, 12.00),    -- 2 Mochas
    (15, 22, 1, 8.00, 8.00),    -- Catnip Toy
    (16, 7, 1, 6.50, 6.50),     -- Catnip Latte
    (16, 17, 1, 8.00, 8.00),    -- Grilled Cheese
    (17, 22, 1, 8.00, 8.00),    -- Catnip Toy
    (18, 21, 1, 25.00, 25.00),  -- T-Shirt
    (18, 23, 1, 15.00, 15.00),  -- Coffee Mug
    (19, 21, 1, 25.00, 25.00),  -- T-Shirt
    (19, 22, 2, 8.00, 16.00),   -- 2 Catnip Toys
    (19, 24, 1, 18.00, 18.00),  -- Tote Bag
    (20, 22, 1, 8.00, 8.00),    -- Catnip Toy
    (21, 1, 1, 5.50, 5.50),     -- House Latte
    (21, 15, 1, 4.50, 4.50),    -- Cat Paw Cookie
    (22, 7, 2, 6.50, 13.00),    -- 2 Catnip Lattes
    (22, 19, 1, 7.00, 7.00),    -- Cat Face Cake
    (23, 1, 1, 5.50, 5.50),     -- House Latte
    (23, 18, 1, 10.00, 10.00),  -- Caprese Panini
    (24, 16, 1, 9.50, 9.50);    -- Avocado Toast


-- Commit all the data atomically
COMMIT;


-- ==============================================================================
-- SECTION 4: SAMPLE ANALYTICAL QUERIES
-- ==============================================================================
-- These queries demonstrate analysis possible with this dataset.
-- They progress from basic to advanced, mirroring the course structure.
-- ==============================================================================


-- ------------------------------------------------------------------------------
-- 4.1 BASIC QUERIES (SELECT, WHERE, ORDER BY, LIMIT)
-- ------------------------------------------------------------------------------

-- Q1: List all available cats with their breed names
SELECT 
    c.name AS cat_name,
    b.breed_name,
    c.arrival_date,
    c.personality_notes
FROM cats c
JOIN breeds b ON c.breed_id = b.breed_id
WHERE c.status = 'available'
ORDER BY c.arrival_date;


-- Q2: Which cats have been adopted?
SELECT 
    c.name,
    b.breed_name,
    c.arrival_date,
    c.adoption_date,
    c.adoption_date - c.arrival_date AS days_until_adoption
FROM cats c
JOIN breeds b ON c.breed_id = b.breed_id
WHERE c.adoption_date IS NOT NULL
ORDER BY c.adoption_date;


-- ------------------------------------------------------------------------------
-- 4.2 TEMPORAL TREND ANALYSIS
-- ------------------------------------------------------------------------------

-- Q3: Monthly visit counts and revenue trends
-- Shows business growth over time
SELECT 
    DATE_TRUNC('month', visit_date) AS month,
    COUNT(*) AS visit_count,
    SUM(cover_charge - discount_applied) AS net_revenue,
    ROUND(AVG(cover_charge - discount_applied), 2) AS avg_revenue_per_visit,
    COUNT(DISTINCT customer_id) AS unique_visitors
FROM visits
GROUP BY DATE_TRUNC('month', visit_date)
ORDER BY month;


-- Q4: Year-over-year growth comparison
WITH yearly_metrics AS (
    SELECT 
        EXTRACT(YEAR FROM visit_date) AS year,
        COUNT(*) AS visits,
        SUM(cover_charge - discount_applied) AS revenue,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM visits
    GROUP BY EXTRACT(YEAR FROM visit_date)
)
SELECT 
    year,
    visits,
    revenue,
    unique_customers,
    ROUND(100.0 * (visits - LAG(visits) OVER (ORDER BY year)) / 
        NULLIF(LAG(visits) OVER (ORDER BY year), 0), 1) AS visit_growth_pct,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year)) / 
        NULLIF(LAG(revenue) OVER (ORDER BY year), 0), 1) AS revenue_growth_pct
FROM yearly_metrics
ORDER BY year;


-- Q5: Day-of-week patterns (for staffing decisions)
SELECT 
    EXTRACT(DOW FROM visit_date) AS day_of_week,
    CASE EXTRACT(DOW FROM visit_date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*) AS visit_count,
    ROUND(AVG(cover_charge - discount_applied), 2) AS avg_revenue
FROM visits
GROUP BY EXTRACT(DOW FROM visit_date)
ORDER BY day_of_week;


-- Q6: Top 5 most popular cats (by total interaction time)
SELECT 
    c.name AS cat_name,
    b.breed_name,
    c.status,
    COUNT(i.interaction_id) AS interaction_count,
    SUM(i.duration_mins) AS total_minutes,
    ROUND(AVG(i.duration_mins), 1) AS avg_interaction_mins
FROM cats c
JOIN breeds b ON c.breed_id = b.breed_id
LEFT JOIN interactions i ON c.cat_id = i.cat_id
GROUP BY c.cat_id, c.name, b.breed_name, c.status
ORDER BY total_minutes DESC NULLS LAST
LIMIT 5;


-- ------------------------------------------------------------------------------
-- 4.3 ADVANCED ANALYTICS (CTEs, Window Functions)
-- ------------------------------------------------------------------------------

-- Q7: Customer lifetime value calculation
WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.join_date,
        SUM(v.cover_charge - v.discount_applied) AS total_visit_revenue,
        COALESCE(SUM(o.total), 0) AS total_order_revenue
    FROM customers c
    LEFT JOIN visits v ON c.customer_id = v.customer_id
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.join_date
)
SELECT 
    customer_name,
    join_date,
    total_visit_revenue,
    total_order_revenue,
    total_visit_revenue + total_order_revenue AS lifetime_value,
    RANK() OVER (ORDER BY total_visit_revenue + total_order_revenue DESC) AS value_rank
FROM customer_spending
WHERE total_visit_revenue > 0
ORDER BY lifetime_value DESC
LIMIT 10;


-- Q8: Adoption rate by arrival quarter
SELECT 
    DATE_TRUNC('quarter', arrival_date) AS arrival_quarter,
    COUNT(*) AS cats_arrived,
    COUNT(adoption_date) AS cats_adopted,
    ROUND(100.0 * COUNT(adoption_date) / COUNT(*), 1) AS adoption_rate_pct,
    ROUND(AVG(adoption_date - arrival_date), 0) AS avg_days_to_adoption
FROM cats
WHERE arrival_date < '2025-01-01'
GROUP BY DATE_TRUNC('quarter', arrival_date)
ORDER BY arrival_quarter;


-- ==============================================================================
-- END OF SCRIPT
-- ==============================================================================
-- 
-- SUMMARY OF DATABASE CONTENTS:
-- 
-- TABLES (12 total):
--   Reference: membership_tiers, breeds, interaction_types, shelters, menu_items
--   Entity: staff, cats, customers
--   Transactional: visits, interactions, orders, order_items
--
-- INDEXES (5):
--   idx_visits_date, idx_visits_customer, idx_interactions_cat, 
--   idx_interactions_visit, idx_orders_datetime
--
-- DATA SUMMARY:
--   - 4 membership tiers
--   - 10 cat breeds
--   - 8 interaction types
--   - 5 partner shelters
--   - 25 menu items
--   - 9 staff members (7 active, 2 former)
--   - 18 cats (6 adopted, 10 available, 1 medical hold, 1 permanent resident)
--   - 19 customers (various membership levels)
--   - 106 visits spanning June 2022 - January 2025
--   - 108 interactions
--   - 24 orders with 44 line items
--
-- TEMPORAL COVERAGE: ~2.5 years enabling:
--   - Year-over-year growth analysis
--   - Seasonal pattern detection
--   - Customer cohort analysis
--   - Adoption rate trends
--   - Staff tenure analysis
--
-- METADATA INCLUDED:
--   - Table and column comments (COMMENT ON)
--   - CHECK constraints for data validation
--   - Foreign key relationships
--   - Indexes for performance
--   - NOT NULL and UNIQUE constraints
--
-- ==============================================================================

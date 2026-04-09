#!/usr/bin/env python3
"""
Whiskers & Waffles Cat Cafe — Data Expansion Generator v2
==========================================================
Generates a SQL expansion script with:
  - ~16,000 visits, ~27,000 interactions, ~11,000 orders
  - Planted statistical relationships for data science
  - Planted causal inference scenarios (A/B, DiD, RDD, IV)
  - Deliberate missingness mechanisms (MCAR, MAR, MNAR)

Usage:
    python generate_expansion_data_v2.py

Output:
    whiskers_waffles_expansion.sql

Seed: 5206 (reproducible)
"""

import random
import math
from datetime import datetime, date, timedelta
from collections import defaultdict

# =============================================================================
# CONFIGURATION — GENERAL
# =============================================================================

SEED = 5206
random.seed(SEED)

START_DATE = date(2022, 6, 1)
END_DATE = date(2025, 1, 31)

EXISTING_CUSTOMERS = 19
EXISTING_CATS = 18
EXISTING_STAFF = 9
EXISTING_VISITS = 106
EXISTING_INTERACTIONS = 108
EXISTING_ORDERS = 24
EXISTING_ORDER_ITEMS = 44
EXISTING_MENU_ITEMS = 25
EXISTING_BREEDS = 10
EXISTING_SHELTERS = 5
EXISTING_INTERACTION_TYPES = 8
EXISTING_TIERS = 4

NEW_CUSTOMERS = 230
NEW_CATS = 55
NEW_STAFF = 6

BASE_DAILY_VISITS_2022 = 8
BASE_DAILY_VISITS_2024 = 22
WEEKEND_MULTIPLIER = 1.40
EVENT_BOOST = 0.30
TEMP_OPTIMAL = 70
ORDER_PROBABILITY = 0.72
AVG_ITEMS_PER_ORDER = 1.8
DC_TAX_RATE = 0.06

WEATHER_EFFECT_STRENGTH = 0.15
ADOPTION_TEMPERAMENT_WEIGHT = 0.35
ADOPTION_AGE_WEIGHT = 0.25
ADOPTION_INTERACTION_WEIGHT = 0.25
SATISFACTION_MEMBERSHIP_BONUS = 0.8

# =============================================================================
# CONFIGURATION — CAUSAL INFERENCE SCENARIOS
# =============================================================================

# 1A: Email campaign (A/B test)
EMAIL_CAMPAIGN_DATE = date(2023, 8, 15)
EMAIL_CAMPAIGN_LAPSE_DAYS = 90
EMAIL_RETURN_EFFECT_PP = 0.12          # 12 pp increase in return rate
EMAIL_SPEND_EFFECT = 4.00              # $4 higher avg spend
EMAIL_SPEND_NOISE_SD = 3.00
EMAIL_DATA_CORRUPTION_RATE = 0.08      # 8% of treatment get NULL (MCAR-ish)

# 1B: Menu layout test (A/B)
MENU_TEST_START = date(2024, 1, 1)
CATNIP_LATTE_BOOST = 1.25             # 25% more catnip lattes on Version A
# Substitution: reduce other coffee weights so total ~constant

# 1C: Loyalty prompt (A/B)
LOYALTY_PROMPT_START = date(2024, 6, 1)
LOYALTY_UPGRADE_EFFECT_PP = 0.18       # 18 pp higher upgrade rate
LOYALTY_BASELINE_UPGRADE_RATE = 0.04   # 4% baseline upgrade without prompt

# 2A: Shelter socialization program (DiD)
SOCIALIZATION_START = date(2023, 9, 1)
SHELTER5_TEMP_MEAN = 4.0              # Lower temperament for shelter 5 cats
SHELTER5_TEMP_SD = 1.2
OTHER_SHELTER_TEMP_MEAN = 6.5
OTHER_SHELTER_TEMP_SD = 1.5
SOCIALIZATION_ADOPTION_BOOST_PP = 0.15  # 15 pp adoption rate boost
SHELTER5_HEALTH_MISSING_RATE = 0.25     # MNAR: 25% missing health records
OTHER_HEALTH_MISSING_RATE = 0.05

# 2B: Cover charge increase (DiD)
PRICE_INCREASE_DATE = date(2023, 8, 1)
NEW_COVER_CHARGE = 18.00
OLD_COVER_CHARGE = 15.00
WALKIN_FREQ_REDUCTION = 0.10           # 10% reduction in walk-in frequency

# 2C: Instagram campaign
INSTAGRAM_START = date(2023, 10, 1)
INSTAGRAM_NEW_CUSTOMER_BOOST = 0.30    # 30% more new customers
INSTAGRAM_REFERRAL_PRE_RATE = 0.02     # 2% from Instagram pre-campaign
INSTAGRAM_REFERRAL_POST_RATE = 0.25    # 25% from Instagram post-campaign

# 3A: Senior cat RDD
SENIOR_AGE_CUTOFF = 7.0               # Years
SENIOR_ADOPTION_BOOST_PP = 0.12        # 12 pp jump at cutoff

# 3B: Membership upgrade threshold (Fuzzy RDD)
UPGRADE_VISIT_THRESHOLD = 10
UPGRADE_OFFER_COMPLIANCE = 0.35        # 35% upgrade when offered
UPGRADE_BASELINE_RATE = 0.08           # 8% upgrade without offer
UPGRADE_VISIT_BOOST = 2.5             # +2.5 visits per 90 days for upgraders

# 3C: Yelp rating
YELP_CROSS_DATE = date(2024, 3, 15)
YELP_NEW_CUSTOMER_BOOST = 3           # +3 new customers/day after crossing 4.5

# 4A: Weather IV — spending propensity confounder
# High-spending customers more likely to visit on nice days
SPENDING_PROPENSITY_WEATHER_CORR = 0.15  # Correlation strength

# 4B: Distance IV — cat enthusiasm confounder
# Cat enthusiasm drives both visits and adoption
ENTHUSIASM_VISIT_WEIGHT = 0.3
ENTHUSIASM_ADOPTION_WEIGHT = 0.2
TRUE_VISIT_ADOPTION_EFFECT = 0.003     # True: 0.3 pp per visit

# Missingness — surveys (MAR)
SURVEY_MISSING_FOOD_BASE = 0.05       # 5% base missing rate
SURVEY_MISSING_FOOD_DISSATISFIED = 0.25  # 25% missing if satisfaction < 5

REFERRAL_SOURCES = ['walk_by', 'friend_referral', 'yelp', 'instagram', 'google', 'event']

DC_ZIPS = [
    '20007', '20008', '20009', '20010', '20036', '20037',
    '20001', '20002', '20003', '20005', '20011', '20012',
    '20015', '20016', '20017', '20018', '20019', '20020',
    '22201', '22202', '22203', '22204', '22207',
    '22301', '22302', '22304', '22314',
    '20814', '20815', '20816', '20817', '20852',
    '20910', '20912',
]

# Distance from cafe (Georgetown ~20007) by zip prefix
ZIP_DISTANCE_MILES = {
    '20007': 0.5, '20037': 0.8, '20036': 1.2, '20008': 1.5,
    '20009': 2.0, '20005': 1.8, '20001': 2.5, '20010': 2.8,
    '20002': 3.0, '20003': 3.2, '20011': 3.5, '20012': 4.0,
    '20015': 3.0, '20016': 2.5, '20017': 4.5, '20018': 5.0,
    '20019': 6.0, '20020': 6.5,
    '22201': 3.5, '22202': 4.0, '22203': 4.5, '22204': 5.0, '22207': 3.8,
    '22301': 5.5, '22302': 5.8, '22304': 6.0, '22314': 6.5,
    '20814': 7.0, '20815': 7.5, '20816': 6.5, '20817': 7.0, '20852': 10.0,
    '20910': 8.0, '20912': 8.5,
}

# =============================================================================
# HELPERS
# =============================================================================

def clamp(val, lo, hi):
    return max(lo, min(hi, val))

def random_time_between(start_hour, end_hour):
    h = random.randint(start_hour, end_hour - 1)
    m = random.choice([0, 15, 30, 45])
    return f"{h:02d}:{m:02d}"

def add_minutes(time_str, mins):
    h, m = map(int, time_str.split(':'))
    total = h * 60 + m + mins
    return f"{(total // 60) % 24:02d}:{total % 60:02d}"

def sql_str(val):
    if val is None:
        return 'NULL'
    return "'" + str(val).replace("'", "''") + "'"

def sql_val(val):
    if val is None:
        return 'NULL'
    if isinstance(val, bool):
        return 'TRUE' if val else 'FALSE'
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, date):
        return f"'{val.isoformat()}'"
    if isinstance(val, datetime):
        return f"'{val.strftime('%Y-%m-%d %H:%M:%S')}'"
    return sql_str(val)

def dc_temperature(d):
    day_of_year = d.timetuple().tm_yday
    avg_high = 65 + 23 * math.sin(2 * math.pi * (day_of_year - 100) / 365)
    avg_low = avg_high - random.gauss(18, 3)
    high = round(avg_high + random.gauss(0, 6), 1)
    low = round(clamp(avg_low + random.gauss(0, 4), 10, high - 5), 1)
    base_precip = 0.30 + 0.10 * math.sin(2 * math.pi * (day_of_year - 60) / 365)
    precip = random.random() < base_precip
    precip_inches = round(random.expovariate(3) * 0.8, 2) if precip else 0.0
    if precip and high < 35:
        condition = 'Snow'
    elif precip:
        condition = 'Rain'
    elif random.random() < 0.35:
        condition = 'Partly Cloudy'
    else:
        condition = 'Sunny'
    return high, low, precip_inches, condition

def weather_visit_effect(high_temp, condition):
    temp_effect = 1.0 - WEATHER_EFFECT_STRENGTH * ((high_temp - TEMP_OPTIMAL) / 30) ** 2
    temp_effect = clamp(temp_effect, 0.6, 1.15)
    if condition == 'Rain':
        temp_effect *= 0.80
    elif condition == 'Snow':
        temp_effect *= 0.65
    return temp_effect

def business_growth_factor(d):
    days_open = (d - START_DATE).days
    total_days = (END_DATE - START_DATE).days
    t = days_open / total_days
    return BASE_DAILY_VISITS_2022 + (BASE_DAILY_VISITS_2024 - BASE_DAILY_VISITS_2022) * (
        1 / (1 + math.exp(-8 * (t - 0.35)))
    )

def yelp_rating(d):
    """Generate slowly increasing Yelp underlying rating."""
    days = (d - START_DATE).days
    total = (END_DATE - START_DATE).days
    base = 4.20 + 0.45 * (days / total)  # 4.20 → 4.65
    noise = random.gauss(0, 0.01)
    return round(clamp(base + noise, 3.5, 5.0), 3)

def yelp_displayed(underlying):
    """Round to nearest 0.5 for display."""
    return round(underlying * 2) / 2

# =============================================================================
# NAME DATA
# =============================================================================

FIRST_NAMES = [
    'Aaliyah','Abigail','Adam','Adrian','Aisha','Alex','Alexis','Amara',
    'Amelia','Amir','Andrea','Andrew','Angela','Anna','Anthony','Aria',
    'Ariana','Austin','Ava','Benjamin','Blake','Brandon','Brianna','Caleb',
    'Cameron','Carlos','Carmen','Caroline','Carter','Catherine','Charles',
    'Chloe','Christian','Christina','Christopher','Claire','Colin','Connor',
    'Daniel','David','Derek','Diana','Diego','Dominic','Dylan','Elena',
    'Eli','Eliana','Elizabeth','Emily','Emma','Eric','Ethan','Eva',
    'Faith','Fatima','Felix','Fiona','Gabriel','Grace','Grant','Hannah',
    'Harper','Henry','Hope','Ian','Imani','Isaac','Isabella','Jack',
    'Jackson','Jacob','Jade','James','Jasmine','Jason','Jayden','Jennifer',
    'Jesse','Jessica','Jocelyn','Jordan','Joseph','Joshua','Julia','Julian',
    'Justin','Kai','Karen','Katherine','Kevin','Kira','Kyle','Laura',
    'Lauren','Leo','Liam','Logan','Lucas','Lucy','Luis','Luna',
    'Mackenzie','Madison','Maria','Mark','Mason','Matthew','Maya','Megan',
    'Michael','Michelle','Miguel','Mila','Naomi','Natalie','Nathan','Nicholas',
    'Nicole','Noah','Nora','Oliver','Olivia','Omar','Owen','Patrick',
    'Paul','Penelope','Peter','Rachel','Raymond','Rebecca','Riley','Robert',
    'Rosa','Ruby','Ryan','Samantha','Samuel','Sara','Sarah','Sebastian',
    'Sierra','Sofia','Sophia','Stella','Stephen','Sydney','Taylor','Thomas',
    'Tyler','Valentina','Victoria','Vincent','Vivian','Wesley','William',
    'Xavier','Yasmin','Zachary','Zoe','Zara'
]

LAST_NAMES = [
    'Adams','Ali','Allen','Anderson','Bailey','Baker','Barnes','Bell',
    'Bennett','Black','Boyd','Brooks','Brown','Bryant','Burke','Burns',
    'Butler','Campbell','Carter','Castillo','Chan','Chang','Chapman','Chen',
    'Clark','Cohen','Cole','Collins','Cook','Cooper','Cox','Cruz',
    'Cunningham','Davis','Diaz','Dixon','Douglas','Dunn','Edwards','Ellis',
    'Evans','Ferguson','Fernandez','Fisher','Flores','Ford','Foster','Fox',
    'Freeman','Garcia','Gonzalez','Gordon','Graham','Grant','Gray','Green',
    'Griffin','Gutierrez','Hall','Hamilton','Hansen','Harris','Harrison',
    'Hart','Hayes','Henderson','Hernandez','Hill','Holland','Holmes',
    'Howard','Huang','Hughes','Hunt','Hunter','Jackson','James','Jenkins',
    'Jensen','Jimenez','Johnson','Jones','Jordan','Kang','Kelly','Kennedy',
    'Khan','Kim','King','Knight','Kumar','Lane','Larson','Lawrence',
    'Lee','Lewis','Li','Lin','Liu','Long','Lopez','Martin','Martinez',
    'Mason','Matthews','McDonald','Meyer','Miller','Mitchell','Moore',
    'Morgan','Morris','Murphy','Murray','Myers','Nakamura','Nelson','Nguyen',
    'Oliver','Ortiz','Owens','Park','Parker','Patel','Patterson','Perez',
    'Perry','Peterson','Phillips','Powell','Price','Quinn','Ramirez',
    'Reed','Reeves','Reynolds','Richardson','Rivera','Roberts','Robinson',
    'Rodriguez','Rogers','Romero','Ross','Russell','Ryan','Sanchez','Sanders',
    'Santiago','Santos','Schmidt','Scott','Shah','Sharma','Shaw','Silva',
    'Simmons','Singh','Smith','Spencer','Stewart','Stone','Sullivan','Sun',
    'Suzuki','Taylor','Thomas','Thompson','Torres','Tran','Tucker','Turner',
    'Vargas','Vasquez','Wagner','Walker','Wallace','Wang','Ward','Warren',
    'Washington','Watson','Webb','Wells','West','White','Williams','Wilson',
    'Wong','Wood','Wright','Wu','Yang','Young','Zhang','Zimmerman'
]

CAT_NAMES = [
    'Alfie','Archie','Atlas','Bagel','Basil','Bean','Bear','Bella',
    'Birdie','Boots','Brownie','Bubbles','Butterscotch','Callie','Caramel',
    'Cedar','Charlie','Cheeto','Chess','Cinnamon','Clover','Cocoa','Cookie',
    'Cosmo','Daisy','Domino','Dottie','Echo','Ember','Felix','Fig',
    'Freya','Ginger','Goose','Gracie','Gus','Honey','Hugo','Indie',
    'Iris','Ivy','Jellybean','Juniper','Kit','Kiwi','Leo','Loki',
    'Lulu','Mango','Marble','Marley','Miso','Mocha','Moose','Nala',
    'Nimbus','Opal','Oreo','Oscar','Patches','Peach','Peanut','Penny',
    'Pickle','Pistachio','Poppy','Pretzel','Rosie','Roux','Sage','Salem',
    'Scout','Simba','Smokey','Snickers','Socks','Spice','Sprout',
    'Stella','Storm','Sunny','Tabitha','Taco','Tilly','Toast','Tofu',
    'Truffle','Tulip','Waffle','Wren','Ziggy','Zinnia'
]

CAT_COLORS = [
    'Orange tabby', 'Black', 'Gray and white', 'White', 'Seal point',
    'Brown tabby', 'Chocolate point', 'Blue (gray)', 'Ruddy', 'Brown spotted',
    'Seal mitted', 'Orange', 'Gray folded ears', 'Tortoiseshell',
    'Silver tabby', 'Blue bicolor', 'Golden', 'Black and white',
    'Calico', 'Cream', 'Red tabby', 'Lilac point', 'Cinnamon',
    'Tuxedo', 'Smoke gray', 'Fawn', 'Bi-color orange', 'Mackerel tabby',
]

PERSONALITY_NOTES = [
    'Friendly and outgoing. Loves meeting new people.',
    'Initially shy but warms up quickly. Prefers quiet visitors.',
    'Very playful and energetic. Great with interactive toys.',
    'Calm and gentle. Perfect lap cat for relaxed visits.',
    'Curious explorer. Always investigating new things.',
    'Vocal and social. Will follow visitors around the lounge.',
    'Independent but affectionate when ready. Respects boundaries.',
    'Sweet and docile. Gets along well with other cats.',
    'Active and athletic. Loves climbing and jumping.',
    'Patient and easygoing. Great with children and first-time visitors.',
    'Mischievous and clever. Enjoys puzzle toys and treat dispensers.',
    'Gentle giant. Big personality in a fluffy package.',
    'Laid-back and easygoing. Rarely gets stressed.',
    'Extremely affectionate. Seeks out human contact constantly.',
    'Playful but knows when to settle down. Good balance.',
    'Quiet observer. Watches everything from a cozy perch.',
    'Adventurous spirit. Loves new experiences and visitors.',
    'Snuggly and warm. Perfect companion for cold days.',
    'High energy kitten. Needs lots of play and stimulation.',
    'Dignified and graceful. Prefers gentle interactions.',
]

SURVEY_COMMENTS = [
    'Great experience!', 'Loved the cats!', 'Coffee was excellent.',
    'Will definitely come back.', 'The staff was so helpful.',
    'Wish there were more cats available.', 'A bit crowded today.',
    'Perfect rainy day activity.', 'My new favorite spot!',
    'Cat yoga was amazing!', 'The waffles were delicious.',
    'Would recommend to friends.', 'Relaxing atmosphere.',
    'Best cat cafe in DC!', None, None, None, None, None, None,
]


# =============================================================================
# MAIN GENERATOR
# =============================================================================

class DataGenerator:
    def __init__(self):
        self.sql = []
        self.weather_data = {}
        self.events = []
        self.event_dates = set()
        self.new_customers = []
        self.new_cats = []
        self.cat_temperament = {}
        self.cat_weight = {}
        self.cat_info = {}
        self.customer_info = {}  # cid → {tier, join_date, zip, enthusiasm, spending_propensity, referral}
        self.customer_visit_counts = defaultdict(int)  # For upgrade threshold RDD
        self.customer_visit_weights = defaultdict(float)
        self.daily_operations = {}  # date → {menu_layout, yelp_underlying, yelp_displayed}
        self.all_customer_ids = list(range(1, EXISTING_CUSTOMERS + 1))
        self.all_cat_ids = list(range(1, EXISTING_CATS + 1))
        self.all_staff_ids = list(range(1, EXISTING_STAFF + 1))
        self.active_staff_ids = [1, 2, 3, 4, 5, 6, 7]

        # Track totals
        self.total_visits = 0
        self.total_interactions = 0
        self.total_orders = 0
        self.total_order_items = 0

    # ─────────────────────────────────────────────────────────────────────────
    # DDL
    # ─────────────────────────────────────────────────────────────────────────
    def generate_ddl(self):
        self.sql.append("""
-- ==============================================================================
-- WHISKERS & WAFFLES CAT CAFE — DATABASE EXPANSION v2
-- Data Science + Causal Inference Ready Dataset
-- ==============================================================================
--
-- Course: PPOL 5206 — Massive Data Fundamentals
-- Institution: Georgetown University, McCourt School of Public Policy
--
-- PREREQUISITES: Run whiskers_waffles_database.sql FIRST.
--
-- THIS SCRIPT:
-- 1. Creates new tables (events, daily_weather, cat_health_records,
--    customer_surveys, menu_price_history, daily_operations)
-- 2. Adds columns to existing tables for causal inference scenarios
-- 3. Inserts ~16,000+ visits with planted relationships
-- 4. Plants causal inference scenarios: A/B tests, DiD, RDD, IV
-- 5. Plants deliberate missingness (MCAR, MAR, MNAR)
--
-- ==============================================================================


-- ============================================================================
-- SECTION 1: NEW TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS events (
    event_id            SERIAL PRIMARY KEY,
    event_name          VARCHAR(200) NOT NULL,
    event_type          VARCHAR(50) NOT NULL
        CHECK (event_type IN ('Cat Yoga', 'Trivia Night', 'Adoption Drive',
                              'Waffle Weekend', 'Holiday Special', 'Live Music',
                              'Book Club', 'Kids Day', 'Photo Day')),
    event_date          DATE NOT NULL,
    start_time          TIME,
    end_time            TIME,
    expected_attendance INTEGER,
    actual_attendance   INTEGER,
    marketing_spend     DECIMAL(8,2) DEFAULT 0.00,
    revenue_impact      DECIMAL(8,2),
    notes               TEXT
);
COMMENT ON TABLE events IS 'Cafe events and programming that may affect foot traffic and revenue';
CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_type ON events(event_type);


CREATE TABLE IF NOT EXISTS daily_weather (
    weather_id          SERIAL PRIMARY KEY,
    observation_date    DATE NOT NULL UNIQUE,
    high_temp_f         DECIMAL(5,1),
    low_temp_f          DECIMAL(5,1),
    precipitation_in    DECIMAL(4,2) DEFAULT 0.00,
    condition           VARCHAR(50)
        CHECK (condition IN ('Sunny', 'Partly Cloudy', 'Rain', 'Snow',
                             'Overcast', 'Fog', 'Thunderstorm')),
    humidity_pct        INTEGER,
    wind_mph            DECIMAL(4,1)
);
COMMENT ON TABLE daily_weather IS 'Daily weather observations for Washington DC';
CREATE INDEX IF NOT EXISTS idx_weather_date ON daily_weather(observation_date);


CREATE TABLE IF NOT EXISTS cat_health_records (
    record_id           SERIAL PRIMARY KEY,
    cat_id              INTEGER NOT NULL REFERENCES cats(cat_id),
    record_date         DATE NOT NULL,
    weight_lbs          DECIMAL(4,1),
    health_score        INTEGER CHECK (health_score BETWEEN 1 AND 10),
    vaccination_current BOOLEAN DEFAULT TRUE,
    vet_visit           BOOLEAN DEFAULT FALSE,
    notes               TEXT
);
COMMENT ON TABLE cat_health_records IS 'Periodic health assessments for cafe cats';
CREATE INDEX IF NOT EXISTS idx_health_cat ON cat_health_records(cat_id);
CREATE INDEX IF NOT EXISTS idx_health_date ON cat_health_records(record_date);


CREATE TABLE IF NOT EXISTS customer_surveys (
    survey_id           SERIAL PRIMARY KEY,
    customer_id         INTEGER NOT NULL REFERENCES customers(customer_id),
    visit_id            INTEGER REFERENCES visits(visit_id),
    survey_date         DATE NOT NULL,
    overall_satisfaction INTEGER CHECK (overall_satisfaction BETWEEN 1 AND 10),
    likelihood_recommend INTEGER CHECK (likelihood_recommend BETWEEN 1 AND 10),
    cleanliness_rating  INTEGER CHECK (cleanliness_rating BETWEEN 1 AND 10),
    staff_rating        INTEGER CHECK (staff_rating BETWEEN 1 AND 10),
    cat_experience      INTEGER CHECK (cat_experience BETWEEN 1 AND 10),
    food_quality        INTEGER CHECK (food_quality BETWEEN 1 AND 10),
    comments            TEXT
);
COMMENT ON TABLE customer_surveys IS 'Post-visit customer satisfaction surveys';
CREATE INDEX IF NOT EXISTS idx_survey_customer ON customer_surveys(customer_id);


CREATE TABLE IF NOT EXISTS menu_price_history (
    price_change_id     SERIAL PRIMARY KEY,
    item_id             INTEGER NOT NULL REFERENCES menu_items(item_id),
    effective_date      DATE NOT NULL,
    old_price           DECIMAL(6,2) NOT NULL,
    new_price           DECIMAL(6,2) NOT NULL,
    reason              VARCHAR(200)
);
COMMENT ON TABLE menu_price_history IS 'Historical record of menu price changes';
CREATE INDEX IF NOT EXISTS idx_price_item ON menu_price_history(item_id);


-- Daily operations: tracks menu layout test and Yelp metrics
CREATE TABLE IF NOT EXISTS daily_operations (
    operations_id       SERIAL PRIMARY KEY,
    operation_date      DATE NOT NULL UNIQUE,
    menu_layout_version VARCHAR(1) CHECK (menu_layout_version IN ('A', 'B')),
    yelp_underlying_rating DECIMAL(4,3),
    yelp_displayed_rating  DECIMAL(2,1),
    notes               TEXT
);
COMMENT ON TABLE daily_operations IS 'Daily operational data including menu test version and Yelp metrics';
CREATE INDEX IF NOT EXISTS idx_ops_date ON daily_operations(operation_date);


-- ============================================================================
-- SECTION 2: SCHEMA MODIFICATIONS TO EXISTING TABLES
-- ============================================================================

-- Cats: data science columns
ALTER TABLE cats ADD COLUMN IF NOT EXISTS temperament_score DECIMAL(3,1)
    CHECK (temperament_score >= 1.0 AND temperament_score <= 10.0);
ALTER TABLE cats ADD COLUMN IF NOT EXISTS weight_lbs DECIMAL(4,1);
-- Cats: causal inference columns
ALTER TABLE cats ADD COLUMN IF NOT EXISTS senior_designation BOOLEAN DEFAULT FALSE;
ALTER TABLE cats ADD COLUMN IF NOT EXISTS socialization_program BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN cats.temperament_score IS 'Staff-assessed friendliness score (1=very shy, 10=extremely social)';
COMMENT ON COLUMN cats.weight_lbs IS 'Current weight in pounds';
COMMENT ON COLUMN cats.senior_designation IS 'TRUE if cat was 7+ years at arrival (Senior Sweethearts program)';
COMMENT ON COLUMN cats.socialization_program IS 'TRUE if cat received structured socialization (shelter 5, post Sep 2023)';

-- Customers: data science columns
ALTER TABLE customers ADD COLUMN IF NOT EXISTS zip_code VARCHAR(10);
-- Customers: causal inference columns
ALTER TABLE customers ADD COLUMN IF NOT EXISTS referral_source VARCHAR(30);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS email_campaign_aug2023 VARCHAR(10);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS loyalty_prompt_2024 VARCHAR(15);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS upgrade_offer_sent BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN customers.zip_code IS 'Customer home zip code for geographic analysis';
COMMENT ON COLUMN customers.referral_source IS 'How the customer first heard about the cafe';
COMMENT ON COLUMN customers.email_campaign_aug2023 IS 'A/B test assignment: treatment, control, or NULL if not eligible';
COMMENT ON COLUMN customers.loyalty_prompt_2024 IS 'Loyalty prompt test: prompted, not_prompted, or NULL';
COMMENT ON COLUMN customers.upgrade_offer_sent IS 'TRUE if customer received auto upgrade offer at 10th visit';

""")

    # ─────────────────────────────────────────────────────────────────────────
    # WEATHER
    # ─────────────────────────────────────────────────────────────────────────
    def generate_weather(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 3: DAILY WEATHER DATA")
        self.sql.append("-- ============================================================================\n")
        self.sql.append("INSERT INTO daily_weather (observation_date, high_temp_f, low_temp_f, precipitation_in, condition, humidity_pct, wind_mph) VALUES")
        d = START_DATE
        rows = []
        while d <= END_DATE:
            high, low, precip, condition = dc_temperature(d)
            humidity = clamp(int(random.gauss(60, 15) + (10 if condition in ('Rain', 'Snow') else 0)), 20, 98)
            wind = round(clamp(random.expovariate(0.15), 1, 35), 1)
            self.weather_data[d] = (high, low, precip, condition)
            rows.append(f"    ({sql_val(d)}, {high}, {low}, {precip}, {sql_str(condition)}, {humidity}, {wind})")
            d += timedelta(days=1)
        self.sql.append(',\n'.join(rows) + ';\n')

    # ─────────────────────────────────────────────────────────────────────────
    # DAILY OPERATIONS (menu layout + Yelp)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_daily_operations(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 4: DAILY OPERATIONS (Menu Layout Test + Yelp Metrics)")
        self.sql.append("-- ============================================================================\n")
        self.sql.append("INSERT INTO daily_operations (operation_date, menu_layout_version, yelp_underlying_rating, yelp_displayed_rating, notes) VALUES")
        d = START_DATE
        rows = []
        while d <= END_DATE:
            # Menu layout: random A/B after Jan 2024, NULL before
            if d >= MENU_TEST_START:
                layout = random.choice(['A', 'B'])
            else:
                layout = None

            yr = yelp_rating(d)
            yd = yelp_displayed(yr)

            self.daily_operations[d] = {
                'menu_layout': layout,
                'yelp_underlying': yr,
                'yelp_displayed': yd,
            }

            rows.append(f"    ({sql_val(d)}, {sql_val(layout)}, {yr}, {yd}, NULL)")
            d += timedelta(days=1)
        self.sql.append(',\n'.join(rows) + ';\n')

    # ─────────────────────────────────────────────────────────────────────────
    # EVENTS
    # ─────────────────────────────────────────────────────────────────────────
    def generate_events(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 5: EVENTS DATA")
        self.sql.append("-- ============================================================================\n")
        events = []
        d = START_DATE
        while d <= END_DATE:
            dow = d.weekday()
            if dow == 5 and 8 <= d.day <= 14:
                events.append((d, 'Cat Yoga', 'Cat Yoga Session', '09:00', '10:30',
                               random.randint(12, 25), random.uniform(20, 80)))
            if dow == 3 and d.day <= 7:
                events.append((d, 'Trivia Night', 'Cat-Themed Trivia', '18:00', '20:00',
                               random.randint(15, 35), random.uniform(15, 50)))
            if dow == 5 and 15 <= d.day <= 21 and d.month in (3, 6, 9, 12):
                events.append((d, 'Adoption Drive', 'Quarterly Adoption Event', '10:00', '16:00',
                               random.randint(30, 60), random.uniform(100, 300)))
            if dow == 5 and d.day >= 25:
                events.append((d, 'Waffle Weekend', 'Special Waffle Menu', '08:00', '14:00',
                               random.randint(20, 40), random.uniform(30, 100)))
            if d.month == 2 and d.day == 14:
                events.append((d, 'Holiday Special', 'Valentine Paws & Lattes', '10:00', '18:00',
                               random.randint(25, 50), random.uniform(50, 150)))
            if d.month == 10 and d.day == 31:
                events.append((d, 'Holiday Special', 'Halloween Costume Cat Party', '14:00', '18:00',
                               random.randint(20, 45), random.uniform(40, 120)))
            if d.month == 12 and 20 <= d.day <= 23:
                events.append((d, 'Holiday Special', 'Holiday Cat-a-Palooza', '10:00', '17:00',
                               random.randint(25, 50), random.uniform(60, 200)))
            if dow == 6 and 8 <= d.day <= 14 and d.month in (1, 4, 7, 10):
                events.append((d, 'Kids Day', 'Family Cat Fun Day', '10:00', '14:00',
                               random.randint(15, 35), random.uniform(25, 75)))
            d += timedelta(days=1)

        self.events = events
        self.event_dates = set(e[0] for e in events)

        self.sql.append("INSERT INTO events (event_name, event_type, event_date, start_time, end_time, expected_attendance, actual_attendance, marketing_spend, notes) VALUES")
        rows = []
        for ev_date, ev_type, ev_name, st, et, expected, spend in events:
            actual = clamp(int(expected * random.gauss(1.0, 0.2)), max(5, expected - 15), expected + 20)
            rows.append(f"    ({sql_str(ev_name)}, {sql_str(ev_type)}, {sql_val(ev_date)}, "
                        f"'{st}', '{et}', {expected}, {actual}, {round(spend, 2)}, NULL)")
        self.sql.append(',\n'.join(rows) + ';\n')

    # ─────────────────────────────────────────────────────────────────────────
    # STAFF
    # ─────────────────────────────────────────────────────────────────────────
    def generate_staff(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 6: ADDITIONAL STAFF")
        self.sql.append("-- ============================================================================\n")
        staff_data = [
            ('Avery', 'Nguyen', 'avery.n@whiskerswaffles.com', '202-555-1010', 'Barista', '2023-04-01', None, 17.50, True),
            ('Reese', 'Thompson', 'reese.t@whiskerswaffles.com', '202-555-1011', 'Cat Care Specialist', '2023-07-15', None, 19.50, True),
            ('Quinn', 'Davis', 'quinn.d@whiskerswaffles.com', '202-555-1012', 'Part-Time', '2024-03-01', None, 16.50, True),
            ('Skyler', 'Park', 'skyler.p@whiskerswaffles.com', '202-555-1013', 'Barista', '2024-06-01', None, 17.00, True),
            ('Harper', 'Reeves', 'harper.r@whiskerswaffles.com', '202-555-1014', 'Adoption Coordinator', '2024-08-15', None, 21.00, True),
            ('Rowan', 'Singh', 'rowan.s@whiskerswaffles.com', '202-555-1015', 'Part-Time', '2023-01-15', '2023-12-31', 16.00, False),
        ]
        self.sql.append("INSERT INTO staff (first_name, last_name, email, phone, role, hire_date, termination_date, hourly_rate, is_active) VALUES")
        rows = []
        for i, (fn, ln, email, phone, role, hire, term, rate, active) in enumerate(staff_data):
            sid = EXISTING_STAFF + i + 1
            self.all_staff_ids.append(sid)
            if active:
                self.active_staff_ids.append(sid)
            rows.append(f"    ({sql_str(fn)}, {sql_str(ln)}, {sql_str(email)}, {sql_str(phone)}, "
                        f"{sql_str(role)}, '{hire}', {sql_str(term) if term else 'NULL'}, {rate}, {'TRUE' if active else 'FALSE'})")
        self.sql.append(',\n'.join(rows) + ';\n')

    # ─────────────────────────────────────────────────────────────────────────
    # CUSTOMERS (with causal columns)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_customers(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 7: ADDITIONAL CUSTOMERS")
        self.sql.append("-- ============================================================================\n")

        used_emails = set()
        self.sql.append("INSERT INTO customers (first_name, last_name, email, phone, tier_id, join_date, birth_date, newsletter_opt_in, zip_code, referral_source, notes) VALUES")
        rows = []

        for i in range(NEW_CUSTOMERS):
            cid = EXISTING_CUSTOMERS + i + 1
            fn = random.choice(FIRST_NAMES)
            ln = random.choice(LAST_NAMES)
            base_email = f"{fn.lower()}.{ln.lower()}"
            email = f"{base_email}@email.com"
            suffix = 1
            while email in used_emails:
                email = f"{base_email}{suffix}@email.com"
                suffix += 1
            used_emails.add(email)

            phone = f"202-555-{3000 + i:04d}"

            r = random.random()
            if r < 0.10:
                tier_id = None
            elif r < 0.50:
                tier_id = 1
            elif r < 0.75:
                tier_id = 2
            elif r < 0.95:
                tier_id = 3
            else:
                tier_id = 4

            days_range = (END_DATE - START_DATE).days
            join_offset = int(random.betavariate(2, 3) * days_range)
            join_date = START_DATE + timedelta(days=join_offset)

            # Instagram boost: more new customers post Oct 2023
            if join_date >= INSTAGRAM_START:
                # 30% chance to shift join date earlier → more density post-Oct 2023
                if random.random() < INSTAGRAM_NEW_CUSTOMER_BOOST * 0.5:
                    shift = random.randint(0, 60)
                    candidate = INSTAGRAM_START + timedelta(days=shift)
                    if candidate <= END_DATE:
                        join_date = candidate

            # Yelp boost: more new customers after rating crosses 4.5
            if join_date >= YELP_CROSS_DATE and random.random() < 0.1:
                join_date = YELP_CROSS_DATE + timedelta(days=random.randint(0, 30))

            age = random.randint(18, 65)
            birth_year = join_date.year - age
            birth_date = date(birth_year, random.randint(1, 12), random.randint(1, 28))

            newsletter = random.random() < 0.45
            zip_code = random.choice(DC_ZIPS)

            # Referral source (2C: Instagram)
            if join_date >= INSTAGRAM_START:
                ref_weights = [0.25, 0.20, 0.10, INSTAGRAM_REFERRAL_POST_RATE, 0.10, 0.10]
            else:
                ref_weights = [0.35, 0.25, 0.15, INSTAGRAM_REFERRAL_PRE_RATE, 0.13, 0.10]
            ref_total = sum(ref_weights)
            ref_probs = [w / ref_total for w in ref_weights]
            referral = random.choices(REFERRAL_SOURCES, weights=ref_probs, k=1)[0]

            # Latent variables for IV scenarios
            cat_enthusiasm = round(random.gauss(0, 1), 3)
            distance = ZIP_DISTANCE_MILES.get(zip_code, 5.0)
            spending_propensity = round(random.gauss(0, 1), 3)

            self.all_customer_ids.append(cid)
            self.customer_info[cid] = {
                'tier_id': tier_id, 'join_date': join_date, 'zip': zip_code,
                'enthusiasm': cat_enthusiasm, 'spending_propensity': spending_propensity,
                'distance': distance, 'referral': referral,
            }
            self.new_customers.append({'id': cid, 'tier_id': tier_id, 'join_date': join_date})

            rows.append(f"    ({sql_str(fn)}, {sql_str(ln)}, {sql_str(email)}, {sql_str(phone)}, "
                        f"{sql_val(tier_id)}, {sql_val(join_date)}, {sql_val(birth_date)}, "
                        f"{'TRUE' if newsletter else 'FALSE'}, {sql_str(zip_code)}, {sql_str(referral)}, NULL)")

        self.sql.append(',\n'.join(rows) + ';\n')

        # Update existing customers
        self.sql.append("-- Update existing customers with new columns")
        existing_referrals = ['walk_by', 'walk_by', 'friend_referral', 'friend_referral', 'yelp',
                              'friend_referral', 'walk_by', 'google', 'friend_referral', 'walk_by',
                              'walk_by', 'yelp', 'friend_referral', 'walk_by', 'walk_by',
                              'walk_by', 'friend_referral', 'friend_referral', 'instagram']
        existing_tiers = {1: 4, 2: 4, 3: 3, 4: 3, 5: 3, 6: 2, 7: 2, 8: 2,
                          9: 2, 10: 2, 11: 1, 12: 1, 13: 1, 14: 1, 15: 1,
                          16: None, 17: None, 18: None, 19: None}
        for cid in range(1, EXISTING_CUSTOMERS + 1):
            z = random.choice(DC_ZIPS[:15])
            ref = existing_referrals[cid - 1] if cid <= len(existing_referrals) else 'walk_by'
            self.sql.append(f"UPDATE customers SET zip_code = '{z}', referral_source = '{ref}' WHERE customer_id = {cid};")
            enth = round(random.gauss(0, 1), 3)
            sp = round(random.gauss(0, 1), 3)
            dist = ZIP_DISTANCE_MILES.get(z, 5.0)
            self.customer_info[cid] = {
                'tier_id': existing_tiers.get(cid, 1), 'join_date': START_DATE,
                'zip': z, 'enthusiasm': enth, 'spending_propensity': sp,
                'distance': dist, 'referral': ref,
            }
        self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # CATS (with causal columns: senior designation, socialization)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_cats(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 8: ADDITIONAL CATS (with causal columns)")
        self.sql.append("-- ============================================================================\n")

        available_names = [n for n in CAT_NAMES]
        random.shuffle(available_names)

        self.sql.append("INSERT INTO cats (name, breed_id, color, birth_date, arrival_date, adoption_date, status, shelter_id, personality_notes, is_featured, temperament_score, weight_lbs, senior_designation, socialization_program) VALUES")
        rows = []

        for i in range(NEW_CATS):
            cat_id = EXISTING_CATS + i + 1
            name = available_names[i] if i < len(available_names) else f"Cat{cat_id}"

            # DiD 2A: ~30% of new cats from shelter 5
            if random.random() < 0.30:
                shelter_id = 5
            else:
                shelter_id = random.randint(1, 4)

            breed_id = random.randint(1, EXISTING_BREEDS)
            color = random.choice(CAT_COLORS)

            days_range = (END_DATE - START_DATE).days
            arrival_offset = int(random.betavariate(2, 3) * days_range)
            arrival_date = START_DATE + timedelta(days=arrival_offset)

            # Age: generate with enough cats near 7-year cutoff for RDD
            if random.random() < 0.25:  # 25% chance of being near the cutoff
                age_years = 7.0 + random.gauss(0, 1.5)
                age_days = int(max(180, age_years * 365))
            else:
                age_days = random.randint(180, 2920)
            birth_date = arrival_date - timedelta(days=age_days)
            age_at_arrival = age_days / 365.0

            # RDD 3A: Senior designation at 7 years
            senior = age_at_arrival >= SENIOR_AGE_CUTOFF

            # Temperament: shelter 5 cats get lower scores (DiD 2A)
            if shelter_id == 5:
                temp_score = round(clamp(random.gauss(SHELTER5_TEMP_MEAN, SHELTER5_TEMP_SD), 1.0, 10.0), 1)
            else:
                temp_score = round(clamp(random.gauss(OTHER_SHELTER_TEMP_MEAN, OTHER_SHELTER_TEMP_SD), 1.0, 10.0), 1)

            # Socialization program (DiD 2A): shelter 5 cats arriving after Sep 2023
            socialization = shelter_id == 5 and arrival_date >= SOCIALIZATION_START

            breed_weights = {1: 15, 2: 10, 3: 9, 4: 11, 5: 16, 6: 14, 7: 15, 8: 9, 9: 12, 10: 10}
            base_weight = breed_weights.get(breed_id, 10)
            weight = round(clamp(base_weight + random.gauss(0, 2), 4, 22), 1)

            # ADOPTION PROBABILITY (core data science + causal effects layered)
            base_adoption = (
                ADOPTION_TEMPERAMENT_WEIGHT * (temp_score / 10) +
                ADOPTION_AGE_WEIGHT * max(0, 1 - age_at_arrival / 8) +
                0.15
            )

            # DiD 2A: socialization program boosts adoption for shelter 5 post-Sep 2023
            if socialization:
                base_adoption += SOCIALIZATION_ADOPTION_BOOST_PP

            # RDD 3A: senior designation boosts adoption at cutoff
            if senior:
                base_adoption += SENIOR_ADOPTION_BOOST_PP

            adoption_prob = clamp(base_adoption + random.gauss(0, 0.1), 0.1, 0.90)

            days_until_end = (END_DATE - arrival_date).days
            if random.random() < adoption_prob and days_until_end > 30:
                avg_days = int(120 - 8 * temp_score + random.gauss(0, 30))
                avg_days = clamp(avg_days, 14, min(300, days_until_end - 7))
                adoption_date = arrival_date + timedelta(days=avg_days)
                if adoption_date > END_DATE:
                    adoption_date = None
                    status = 'available'
                else:
                    status = 'adopted'
            else:
                adoption_date = None
                r = random.random()
                if r < 0.05: status = 'medical_hold'
                elif r < 0.08: status = 'permanent_resident'
                elif r < 0.12: status = 'foster'
                else: status = 'available'

            personality = random.choice(PERSONALITY_NOTES)
            featured = senior or random.random() < 0.12  # Seniors always featured

            self.all_cat_ids.append(cat_id)
            self.cat_temperament[cat_id] = temp_score
            self.cat_weight[cat_id] = weight
            self.cat_info[cat_id] = {
                'arrival_date': arrival_date, 'adoption_date': adoption_date,
                'status': status, 'birth_date': birth_date, 'breed_id': breed_id,
                'weight': weight, 'temp_score': temp_score,
                'shelter_id': shelter_id, 'socialization': socialization,
            }

            rows.append(f"    ({sql_str(name)}, {breed_id}, {sql_str(color)}, {sql_val(birth_date)}, "
                        f"{sql_val(arrival_date)}, {sql_val(adoption_date)}, {sql_str(status)}, "
                        f"{shelter_id}, {sql_str(personality)}, {'TRUE' if featured else 'FALSE'}, "
                        f"{temp_score}, {weight}, {'TRUE' if senior else 'FALSE'}, {'TRUE' if socialization else 'FALSE'})")

        self.sql.append(',\n'.join(rows) + ';\n')

        # Update existing cats
        self.sql.append("-- Update existing cats with new columns")
        existing_cats_data = [
            (1, '2022-06-15', None, 'permanent_resident', 1, '2020-04-15'),
            (2, '2022-07-01', '2022-11-15', 'adopted', 1, '2021-01-10'),
            (3, '2022-07-15', '2023-02-28', 'adopted', 1, '2019-08-20'),
            (4, '2022-08-01', '2023-01-20', 'adopted', 2, '2021-06-05'),
            (5, '2023-01-10', None, 'available', 2, '2020-11-20'),
            (6, '2023-02-15', '2023-09-10', 'adopted', 2, '2022-06-10'),
            (7, '2023-04-01', None, 'medical_hold', 3, '2019-03-15'),
            (8, '2023-05-20', None, 'available', 3, '2022-04-01'),
            (9, '2023-07-01', '2024-01-15', 'adopted', 1, '2021-09-15'),
            (10, '2023-08-15', None, 'available', 4, '2022-01-20'),
            (11, '2023-09-01', None, 'available', 4, '2023-01-05'),
            (12, '2024-01-20', '2024-07-20', 'adopted', 1, '2022-10-15'),
            (13, '2024-02-01', None, 'available', 3, '2023-03-10'),
            (14, '2024-04-15', None, 'available', 5, '2021-04-25'),
            (15, '2024-06-01', None, 'available', 5, '2023-08-01'),
            (16, '2024-08-01', None, 'available', 2, '2023-05-20'),
            (17, '2024-09-15', None, 'available', 4, '2024-01-10'),
            (18, '2025-01-05', None, 'available', 1, '2022-07-15'),
        ]
        for cid, arr_s, adopt_s, status, shelter_id, birth_s in existing_cats_data:
            arr = date.fromisoformat(arr_s)
            birth = date.fromisoformat(birth_s)
            age_at_arrival = (arr - birth).days / 365.0

            if shelter_id == 5:
                ts = round(clamp(random.gauss(SHELTER5_TEMP_MEAN, SHELTER5_TEMP_SD), 1.0, 10.0), 1)
            else:
                ts = round(clamp(random.gauss(OTHER_SHELTER_TEMP_MEAN, OTHER_SHELTER_TEMP_SD), 1.0, 10.0), 1)
            w = round(clamp(random.gauss(11, 3), 5, 20), 1)
            senior = age_at_arrival >= SENIOR_AGE_CUTOFF
            socialization = shelter_id == 5 and arr >= SOCIALIZATION_START

            self.cat_temperament[cid] = ts
            self.cat_weight[cid] = w
            self.cat_info[cid] = {
                'arrival_date': arr,
                'adoption_date': date.fromisoformat(adopt_s) if adopt_s else None,
                'status': status, 'shelter_id': shelter_id,
                'socialization': socialization,
            }
            self.sql.append(f"UPDATE cats SET temperament_score = {ts}, weight_lbs = {w}, "
                            f"senior_designation = {'TRUE' if senior else 'FALSE'}, "
                            f"socialization_program = {'TRUE' if socialization else 'FALSE'} "
                            f"WHERE cat_id = {cid};")
        self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # HELPERS for visit generation
    # ─────────────────────────────────────────────────────────────────────────
    def get_available_cats(self, d):
        available = []
        for cid, info in self.cat_info.items():
            arr = info['arrival_date']
            adopt = info.get('adoption_date')
            if arr <= d:
                if adopt is None or adopt > d:
                    if info.get('status') == 'medical_hold' and random.random() < 0.7:
                        continue
                    available.append(cid)
        return available

    def get_customer_pool(self, d):
        pool = []
        for cid in range(1, EXISTING_CUSTOMERS + 1):
            pool.append(cid)
        for c in self.new_customers:
            if c['join_date'] <= d:
                pool.append(c['id'])
        return pool

    def get_tier(self, cid):
        info = self.customer_info.get(cid)
        if info:
            return info['tier_id']
        return 1

    def get_discount(self, tier_id, cover_charge):
        discounts = {None: 0, 1: 0, 2: 0.10, 3: 0.25, 4: 0.40}
        return round(cover_charge * discounts.get(tier_id, 0), 2)

    def is_member(self, cid):
        tier = self.get_tier(cid)
        return tier is not None and tier >= 2

    # ─────────────────────────────────────────────────────────────────────────
    # TRANSACTIONS (visits, interactions, orders)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_transactions(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 9: VISITS, INTERACTIONS, ORDERS")
        self.sql.append("-- ============================================================================\n")

        visit_id = EXISTING_VISITS + 1
        interaction_id = EXISTING_INTERACTIONS + 1
        order_id = EXISTING_ORDERS + 1
        order_item_id = EXISTING_ORDER_ITEMS + 1

        visit_rows = []
        interaction_rows = []
        order_rows = []
        order_item_rows = []

        BATCH = 3000

        # Initialize visit weights
        for cid, info in self.customer_info.items():
            tier = info['tier_id']
            enthusiasm = info.get('enthusiasm', 0)
            distance = info.get('distance', 5)

            # Base weight from tier
            if tier == 4: base_w = random.uniform(3.0, 6.0)
            elif tier == 3: base_w = random.uniform(1.5, 3.5)
            elif tier == 2: base_w = random.uniform(0.8, 2.0)
            elif tier == 1: base_w = random.uniform(0.3, 1.0)
            else: base_w = random.uniform(0.05, 0.3)

            # IV 4B: enthusiasm increases visits
            base_w *= (1 + ENTHUSIASM_VISIT_WEIGHT * enthusiasm)
            # IV 4B: distance decreases visits
            base_w *= max(0.2, 1 - 0.05 * distance)

            self.customer_visit_weights[cid] = max(0.01, base_w)

        item_prices = {
            1: 5.50, 2: 5.00, 3: 4.50, 4: 5.50, 5: 6.00,
            6: 3.50, 7: 6.50, 8: 6.00, 9: 4.00, 10: 4.00,
            11: 5.50, 12: 4.00, 13: 3.50, 14: 3.00, 15: 4.50,
            16: 9.50, 17: 8.00, 18: 10.00, 19: 7.00, 20: 8.00,
            21: 25.00, 22: 8.00, 23: 15.00, 24: 18.00, 25: 20.00,
        }

        d = START_DATE
        while d <= END_DATE:
            # Closed days
            if (d.month == 12 and d.day == 25) or (d.month == 1 and d.day == 1):
                d += timedelta(days=1)
                continue

            dow = d.weekday()
            weather = self.weather_data.get(d, (70, 55, 0, 'Sunny'))
            high_temp, _, _, condition = weather
            ops = self.daily_operations.get(d, {})

            base = business_growth_factor(d)
            weekend_mult = WEEKEND_MULTIPLIER if dow >= 5 else 1.0
            weather_mult = weather_visit_effect(high_temp, condition)
            event_mult = 1.0 + EVENT_BOOST if d in self.event_dates else 1.0

            month_adj = {1: 0.85, 2: 0.88, 3: 0.95, 4: 1.05, 5: 1.08,
                         6: 1.02, 7: 0.95, 8: 0.92, 9: 1.00, 10: 1.06,
                         11: 0.98, 12: 1.10}
            seasonal = month_adj.get(d.month, 1.0)

            # 3C: Yelp boost after crossing 4.5
            yelp_mult = 1.0
            if d >= YELP_CROSS_DATE:
                yelp_disp = ops.get('yelp_displayed', 4.0)
                if yelp_disp >= 4.5:
                    yelp_mult = 1.0 + (YELP_NEW_CUSTOMER_BOOST / base) * 0.5

            expected = base * weekend_mult * weather_mult * event_mult * seasonal * yelp_mult
            actual_visits = max(1, int(random.gauss(expected, expected * 0.2)))

            customer_pool = self.get_customer_pool(d)
            available_cats = self.get_available_cats(d)
            if not customer_pool or not available_cats:
                d += timedelta(days=1)
                continue

            # IV 4A: high-spending-propensity customers more likely to visit on nice days
            pool_weights = []
            for cid in customer_pool:
                w = self.customer_visit_weights.get(cid, 0.5)
                info = self.customer_info.get(cid, {})
                sp = info.get('spending_propensity', 0)

                # DiD 2B: reduce walk-in frequency post price increase
                if d >= PRICE_INCREASE_DATE and not self.is_member(cid):
                    w *= (1 - WALKIN_FREQ_REDUCTION)

                # IV 4A: spending propensity correlates with nice weather visits
                if high_temp and 60 <= high_temp <= 80 and condition in ('Sunny', 'Partly Cloudy'):
                    w *= (1 + SPENDING_PROPENSITY_WEATHER_CORR * sp)

                pool_weights.append(max(0.01, w))

            total_w = sum(pool_weights)
            probs = [w / total_w for w in pool_weights]
            visit_customers = random.choices(customer_pool, weights=probs,
                                             k=min(actual_visits, len(customer_pool)))

            menu_layout = ops.get('menu_layout')

            for cust_id in visit_customers:
                check_in = random_time_between(9, 17)
                duration = random.randint(45, 150)
                check_out = add_minutes(check_in, duration)
                if check_out > "20:00":
                    check_out = "20:00"

                staff_id = random.choice(self.active_staff_ids)

                # DiD 2B: cover charge based on date and membership
                if d >= PRICE_INCREASE_DATE and not self.is_member(cust_id):
                    cover = NEW_COVER_CHARGE
                else:
                    cover = OLD_COVER_CHARGE

                tier = self.get_tier(cust_id)
                discount = self.get_discount(tier, OLD_COVER_CHARGE)  # Discount always on original base

                visit_rows.append(
                    f"    ({cust_id}, {sql_val(d)}, '{check_in}', '{check_out}', "
                    f"{staff_id}, {cover}, {discount}, NULL)"
                )
                current_visit_id = visit_id
                visit_id += 1

                # Track visit count for RDD 3B
                self.customer_visit_counts[cust_id] += 1

                # Interactions
                n_int = random.choices([1, 2, 3], weights=[0.45, 0.40, 0.15])[0]
                cats_for_int = random.sample(available_cats, k=min(n_int, len(available_cats)))
                for cat_id in cats_for_int:
                    type_id = random.randint(1, EXISTING_INTERACTION_TYPES)
                    temp = self.cat_temperament.get(cat_id, 5.0)
                    int_dur = int(clamp(random.gauss(15 + temp * 2.5, 8), 5, 90))
                    int_staff = random.choice(self.active_staff_ids)
                    int_time = add_minutes(check_in, random.randint(5, max(10, duration - 20)))
                    interaction_rows.append(
                        f"    ({current_visit_id}, {cat_id}, {type_id}, {int_dur}, "
                        f"{int_staff}, '{int_time}', NULL)"
                    )
                    interaction_id += 1

                # Orders
                if random.random() < ORDER_PROBABILITY:
                    n_items = max(1, min(5, int(random.expovariate(1 / AVG_ITEMS_PER_ORDER))))

                    # Current prices
                    cur_prices = dict(item_prices)
                    if d >= date(2023, 7, 1):
                        for k in (1, 2, 3, 4, 5, 8, 11):
                            cur_prices[k] = round(cur_prices[k] * 1.05, 2)
                    if d >= date(2024, 6, 1):
                        for k in (1, 2, 3, 4, 5, 8, 11, 12, 13, 16, 17, 18):
                            cur_prices[k] = round(cur_prices[k] * 1.05, 2)

                    # Item weights with seasonal + menu layout effects
                    iw = {}
                    for item_id in range(1, EXISTING_MENU_ITEMS + 1):
                        w = 1.0
                        if item_id == 4:  # Cold brew
                            w = 2.5 if d.month in (6, 7, 8) else 0.5
                        elif item_id in (1, 2, 3, 5, 6, 8, 9, 10, 11):  # Hot drinks
                            if d.month in (11, 12, 1, 2): w = 1.8
                            elif d.month in (6, 7, 8): w = 0.7
                        elif item_id == 20:  # Ice cream
                            w = 3.0 if d.month in (5, 6, 7, 8, 9) else 0.2
                        elif item_id >= 21:  # Merch
                            w = 0.15
                        elif item_id == 15:  # Cat paw cookie
                            w = 1.5
                        elif item_id == 7:  # Catnip latte
                            if d >= date(2023, 3, 1):
                                w = 1.8
                                # A/B 1B: menu layout boost
                                if menu_layout == 'A':
                                    w *= CATNIP_LATTE_BOOST
                            else:
                                w = 0.0
                        iw[item_id] = w

                    # A/B 1B: substitution effect — reduce other coffees on layout A
                    if menu_layout == 'A':
                        for k in (1, 2):
                            iw[k] *= 0.85

                    avail_items = [iid for iid, w in iw.items() if w > 0]
                    sel_items = random.choices(avail_items, weights=[iw[i] for i in avail_items], k=n_items)

                    subtotal = 0
                    cur_ois = []
                    for sel in sel_items:
                        qty = 1 if sel >= 21 else random.choices([1, 2], weights=[0.85, 0.15])[0]
                        price = cur_prices.get(sel, 5.00)
                        lt = round(price * qty, 2)
                        subtotal += lt
                        cur_ois.append((sel, qty, price, lt))

                    # IV 4A: spending propensity adds to order (TRUE effect = 0, but creates OLS bias)
                    info = self.customer_info.get(cust_id, {})
                    sp = info.get('spending_propensity', 0)
                    # High-propensity people order slightly more expensive items
                    # This is the CONFOUNDER, not a causal crowd effect
                    if sp > 0.5 and len(cur_ois) > 0:
                        bonus = round(sp * 1.5, 2)
                        subtotal += bonus
                        # Add as extra item quantity
                        sel, qty, price, lt = cur_ois[-1]
                        cur_ois[-1] = (sel, qty, price, round(lt + bonus, 2))

                    subtotal = round(subtotal, 2)
                    tax = round(subtotal * DC_TAX_RATE, 2)
                    total = round(subtotal + tax, 2)
                    payment = random.choice(['credit', 'credit', 'credit', 'debit', 'mobile', 'mobile'])

                    oh = int(check_in.split(':')[0])
                    om = int(check_in.split(':')[1]) + random.randint(10, 30)
                    odt = datetime(d.year, d.month, d.day, oh, min(59, om), 0)

                    order_rows.append(
                        f"    ({cust_id}, {current_visit_id}, {staff_id}, "
                        f"{sql_val(odt)}, {subtotal}, {tax}, {total}, {sql_str(payment)})"
                    )
                    for item_id, qty, price, lt in cur_ois:
                        order_item_rows.append(f"    ({order_id}, {item_id}, {qty}, {price}, {lt})")
                        order_item_id += 1
                    order_id += 1

            d += timedelta(days=1)

        # Write all batched
        self._batch_insert("visits",
            "(customer_id, visit_date, check_in_time, check_out_time, staff_id, cover_charge, discount_applied, notes)",
            visit_rows, BATCH)
        self.sql.append("")
        self._batch_insert("interactions",
            "(visit_id, cat_id, type_id, duration_mins, staff_id, start_time, notes)",
            interaction_rows, BATCH)
        self.sql.append("")
        self._batch_insert("orders",
            "(customer_id, visit_id, staff_id, order_datetime, subtotal, tax, total, payment_method)",
            order_rows, BATCH)
        self.sql.append("")
        self._batch_insert("order_items",
            "(order_id, item_id, quantity, unit_price, line_total)",
            order_item_rows, BATCH)

        self.total_visits = visit_id - 1
        self.total_interactions = interaction_id - 1
        self.total_orders = order_id - 1
        self.total_order_items = order_item_id - 1

    def _batch_insert(self, table, cols, rows, batch):
        for i in range(0, len(rows), batch):
            chunk = rows[i:i + batch]
            self.sql.append(f"INSERT INTO {table} {cols} VALUES")
            self.sql.append(',\n'.join(chunk) + ';')
            self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # EMAIL CAMPAIGN A/B (1A) — post-hoc assignment
    # ─────────────────────────────────────────────────────────────────────────
    def generate_email_campaign(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 10: EMAIL CAMPAIGN A/B TEST (Scenario 1A)")
        self.sql.append("-- ============================================================================\n")

        # Identify lapsed customers as of Aug 1, 2023
        # We approximate: customers who joined before May 2023 are candidates
        # Real lapsed = no visit in 90 days. We assign treatment/control.
        eligible = []
        for cid, info in self.customer_info.items():
            if info['join_date'] < date(2023, 5, 1):
                eligible.append(cid)

        random.shuffle(eligible)
        half = len(eligible) // 2
        treatment = set(eligible[:half])
        control = set(eligible[half:])

        for cid in treatment:
            # 8% data corruption: set to NULL instead of 'treatment'
            if random.random() < EMAIL_DATA_CORRUPTION_RATE:
                self.sql.append(f"UPDATE customers SET email_campaign_aug2023 = NULL WHERE customer_id = {cid};")
            else:
                self.sql.append(f"UPDATE customers SET email_campaign_aug2023 = 'treatment' WHERE customer_id = {cid};")

        for cid in control:
            self.sql.append(f"UPDATE customers SET email_campaign_aug2023 = 'control' WHERE customer_id = {cid};")

        # The visit-level effect is already partially planted via visit weights.
        # We add explicit return visits for treatment group in Aug 15 - Sep 15 window.
        self.sql.append("")
        self.sql.append("-- Email campaign return visits (treatment effect)")
        return_start = EMAIL_CAMPAIGN_DATE
        return_end = date(2023, 9, 15)
        inserted = 0
        vid = self.total_visits + 1
        oid = self.total_orders + 1

        visit_rows = []
        order_rows = []
        for cid in treatment:
            # Treatment effect: 12 pp higher return probability
            base_return = 0.15  # Base rate for lapsed customers
            if random.random() < base_return + EMAIL_RETURN_EFFECT_PP:
                vdate = return_start + timedelta(days=random.randint(1, 30))
                if vdate > return_end:
                    vdate = return_end
                check_in = random_time_between(10, 16)
                check_out = add_minutes(check_in, random.randint(45, 120))
                staff = random.choice(self.active_staff_ids)
                tier = self.get_tier(cid)
                cover = NEW_COVER_CHARGE if not self.is_member(cid) else OLD_COVER_CHARGE
                disc = self.get_discount(tier, OLD_COVER_CHARGE)
                visit_rows.append(f"    ({cid}, {sql_val(vdate)}, '{check_in}', '{check_out}', {staff}, {cover}, {disc}, 'Returned via email campaign')")

                # Spend boost
                spend_boost = max(0, EMAIL_SPEND_EFFECT + random.gauss(0, EMAIL_SPEND_NOISE_SD))
                subtotal = round(10 + spend_boost, 2)
                tax = round(subtotal * DC_TAX_RATE, 2)
                total = round(subtotal + tax, 2)
                odt = datetime(vdate.year, vdate.month, vdate.day, int(check_in.split(':')[0]), 30, 0)
                order_rows.append(f"    ({cid}, {vid}, {staff}, {sql_val(odt)}, {subtotal}, {tax}, {total}, 'credit')")
                vid += 1
                oid += 1
                inserted += 1

        # Also add some returns for control (at base rate only)
        for cid in control:
            if random.random() < base_return:  # No boost
                vdate = return_start + timedelta(days=random.randint(1, 30))
                if vdate > return_end:
                    vdate = return_end
                check_in = random_time_between(10, 16)
                check_out = add_minutes(check_in, random.randint(45, 120))
                staff = random.choice(self.active_staff_ids)
                tier = self.get_tier(cid)
                cover = NEW_COVER_CHARGE if not self.is_member(cid) else OLD_COVER_CHARGE
                disc = self.get_discount(tier, OLD_COVER_CHARGE)
                visit_rows.append(f"    ({cid}, {sql_val(vdate)}, '{check_in}', '{check_out}', {staff}, {cover}, {disc}, NULL)")

                subtotal = round(10 + random.gauss(0, 3), 2)
                tax = round(subtotal * DC_TAX_RATE, 2)
                total = round(subtotal + tax, 2)
                odt = datetime(vdate.year, vdate.month, vdate.day, int(check_in.split(':')[0]), 30, 0)
                order_rows.append(f"    ({cid}, {vid}, {staff}, {sql_val(odt)}, {subtotal}, {tax}, {total}, 'credit')")
                vid += 1
                oid += 1

        if visit_rows:
            self._batch_insert("visits",
                "(customer_id, visit_date, check_in_time, check_out_time, staff_id, cover_charge, discount_applied, notes)",
                visit_rows, 3000)
        if order_rows:
            self._batch_insert("orders",
                "(customer_id, visit_id, staff_id, order_datetime, subtotal, tax, total, payment_method)",
                order_rows, 3000)

        self.total_visits = vid - 1
        self.total_orders = oid - 1

    # ─────────────────────────────────────────────────────────────────────────
    # LOYALTY PROMPT (1C) + UPGRADE THRESHOLD RDD (3B)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_loyalty_and_upgrade(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 11: LOYALTY PROMPT (1C) + UPGRADE THRESHOLD (3B)")
        self.sql.append("-- ============================================================================\n")

        # 1C: Walk-in customers visiting post Jun 2024 get randomly prompted
        for cid, info in self.customer_info.items():
            tier = info['tier_id']
            if tier is None or tier <= 1:  # Walk-in or no membership
                if info['join_date'] <= LOYALTY_PROMPT_START:
                    if random.random() < 0.5:
                        assignment = 'prompted'
                        # 18 pp higher upgrade rate
                        if random.random() < LOYALTY_BASELINE_UPGRADE_RATE + LOYALTY_UPGRADE_EFFECT_PP:
                            self.sql.append(f"UPDATE customers SET loyalty_prompt_2024 = 'prompted', tier_id = 2 WHERE customer_id = {cid};")
                        else:
                            self.sql.append(f"UPDATE customers SET loyalty_prompt_2024 = 'prompted' WHERE customer_id = {cid};")
                    else:
                        if random.random() < LOYALTY_BASELINE_UPGRADE_RATE:
                            self.sql.append(f"UPDATE customers SET loyalty_prompt_2024 = 'not_prompted', tier_id = 2 WHERE customer_id = {cid};")
                        else:
                            self.sql.append(f"UPDATE customers SET loyalty_prompt_2024 = 'not_prompted' WHERE customer_id = {cid};")

        # 3B: Customers who reached 10 visits get upgrade offer
        self.sql.append("\n-- Upgrade offer at 10th visit (Fuzzy RDD)")
        for cid, count in self.customer_visit_counts.items():
            if count >= UPGRADE_VISIT_THRESHOLD:
                self.sql.append(f"UPDATE customers SET upgrade_offer_sent = TRUE WHERE customer_id = {cid};")
                # Compliance: 35% upgrade
                if random.random() < UPGRADE_OFFER_COMPLIANCE:
                    current_tier = self.get_tier(cid)
                    if current_tier and current_tier < 4:
                        new_tier = current_tier + 1
                        self.sql.append(f"UPDATE customers SET tier_id = {new_tier} WHERE customer_id = {cid};")
            elif count >= 8:  # Near threshold: baseline upgrade
                if random.random() < UPGRADE_BASELINE_RATE:
                    current_tier = self.get_tier(cid)
                    if current_tier and current_tier < 4:
                        new_tier = current_tier + 1
                        self.sql.append(f"UPDATE customers SET tier_id = {new_tier} WHERE customer_id = {cid};")
        self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # HEALTH RECORDS (with MNAR for shelter 5)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_health_records(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 12: CAT HEALTH RECORDS (MNAR for shelter 5)")
        self.sql.append("-- ============================================================================\n")

        rows = []
        for cat_id, info in self.cat_info.items():
            arrival = info['arrival_date']
            end = info.get('adoption_date') or END_DATE
            if isinstance(end, str):
                end = date.fromisoformat(end)

            base_weight = self.cat_weight.get(cat_id, 10.0)
            base_health = clamp(int(self.cat_temperament.get(cat_id, 5) * 0.7 + random.gauss(3, 1)), 3, 10)
            is_shelter5 = info.get('shelter_id') == 5

            check_date = arrival + timedelta(days=7)
            while check_date <= end and check_date <= END_DATE:
                # MNAR: shelter 5 cats more likely to have missing records
                missing_rate = SHELTER5_HEALTH_MISSING_RATE if is_shelter5 else OTHER_HEALTH_MISSING_RATE
                if random.random() < missing_rate:
                    check_date += timedelta(days=random.randint(25, 35))
                    continue  # Skip this record entirely (MNAR)

                weight = round(clamp(base_weight + random.gauss(0, 0.5), 4, 22), 1)
                health = clamp(base_health + random.randint(-1, 1), 1, 10)
                vacc = random.random() < 0.95
                vet = random.random() < 0.08
                rows.append(f"    ({cat_id}, {sql_val(check_date)}, {weight}, {health}, "
                            f"{'TRUE' if vacc else 'FALSE'}, {'TRUE' if vet else 'FALSE'}, NULL)")
                check_date += timedelta(days=random.randint(25, 35))

        self._batch_insert("cat_health_records",
            "(cat_id, record_date, weight_lbs, health_score, vaccination_current, vet_visit, notes)",
            rows, 3000)

    # ─────────────────────────────────────────────────────────────────────────
    # SURVEYS (with MAR missingness)
    # ─────────────────────────────────────────────────────────────────────────
    def generate_surveys(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 13: CUSTOMER SURVEYS (MAR missingness)")
        self.sql.append("-- ============================================================================\n")

        rows = []
        survey_count = int((self.total_visits - EXISTING_VISITS) * 0.15)
        sampled = random.sample(
            range(EXISTING_VISITS + 1, self.total_visits + 1),
            k=min(survey_count, self.total_visits - EXISTING_VISITS)
        )

        for vid in sorted(sampled):
            cid = random.choice(self.all_customer_ids[:EXISTING_CUSTOMERS + len(self.new_customers)])
            tier = self.get_tier(cid)
            tier_bonus = {None: 0, 1: 0, 2: 0.3, 3: 0.6, 4: 1.0}.get(tier, 0)
            base_sat = clamp(random.gauss(7.0 + tier_bonus * SATISFACTION_MEMBERSHIP_BONUS, 1.5), 1, 10)

            overall = clamp(int(base_sat + random.gauss(0, 0.5)), 1, 10)
            recommend = clamp(int(base_sat + random.gauss(0, 0.8)), 1, 10)
            clean = clamp(int(random.gauss(8.0, 1.0)), 1, 10)
            staff_r = clamp(int(random.gauss(8.2, 0.8)), 1, 10)
            cat_exp = clamp(int(base_sat + random.gauss(0.5, 1.0)), 1, 10)

            # MAR: food_quality missing more often when satisfaction is low
            if overall < 5:
                food_missing = random.random() < SURVEY_MISSING_FOOD_DISSATISFIED
            else:
                food_missing = random.random() < SURVEY_MISSING_FOOD_BASE
            food_q = 'NULL' if food_missing else str(clamp(int(random.gauss(7.5, 1.2)), 1, 10))

            approx_date = START_DATE + timedelta(
                days=int((vid - EXISTING_VISITS) / max(1, self.total_visits - EXISTING_VISITS) *
                         (END_DATE - START_DATE).days)
            )
            comment = random.choice(SURVEY_COMMENTS)

            rows.append(
                f"    ({cid}, {vid}, {sql_val(approx_date)}, "
                f"{overall}, {recommend}, {clean}, {staff_r}, {cat_exp}, {food_q}, "
                f"{sql_val(comment)})"
            )

        self._batch_insert("customer_surveys",
            "(customer_id, visit_id, survey_date, overall_satisfaction, likelihood_recommend, "
            "cleanliness_rating, staff_rating, cat_experience, food_quality, comments)",
            rows, 3000)

    # ─────────────────────────────────────────────────────────────────────────
    # PRICE HISTORY
    # ─────────────────────────────────────────────────────────────────────────
    def generate_price_history(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 14: MENU PRICE HISTORY")
        self.sql.append("-- ============================================================================\n")
        original = {
            1: 5.50, 2: 5.00, 3: 4.50, 4: 5.50, 5: 6.00,
            6: 3.50, 7: 6.50, 8: 6.00, 9: 4.00, 10: 4.00,
            11: 5.50, 12: 4.00, 13: 3.50, 14: 3.00, 15: 4.50,
            16: 9.50, 17: 8.00, 18: 10.00, 19: 7.00, 20: 8.00,
            21: 25.00, 22: 8.00, 23: 15.00, 24: 18.00, 25: 20.00,
        }
        rows = []
        for item_id in [1, 2, 3, 4, 5, 8, 11]:
            old = original[item_id]
            new = round(old * 1.05, 2)
            rows.append(f"    ({item_id}, '2023-07-01', {old}, {new}, {sql_str('Annual cost adjustment')})")

        r1 = dict(original)
        for k in [1, 2, 3, 4, 5, 8, 11]:
            r1[k] = round(r1[k] * 1.05, 2)
        for item_id in [1, 2, 3, 4, 5, 8, 11, 12, 13, 16, 17, 18]:
            old = r1[item_id]
            new = round(old * 1.05, 2)
            rows.append(f"    ({item_id}, '2024-06-01', {old}, {new}, {sql_str('Inflation adjustment')})")

        self.sql.append("INSERT INTO menu_price_history (item_id, effective_date, old_price, new_price, reason) VALUES")
        self.sql.append(',\n'.join(rows) + ';\n')

    # ─────────────────────────────────────────────────────────────────────────
    # DATA QUALITY ISSUES (MCAR weather)
    # ─────────────────────────────────────────────────────────────────────────
    def add_data_quality_issues(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 15: INTENTIONAL DATA QUALITY ISSUES (MCAR)")
        self.sql.append("-- ============================================================================\n")
        self.sql.append("-- Weather sensor outages (MCAR)")
        self.sql.append("UPDATE daily_weather SET high_temp_f = NULL, low_temp_f = NULL WHERE observation_date IN ('2023-04-12', '2023-04-13', '2023-08-22', '2024-02-15', '2024-09-03');")
        self.sql.append("")
        self.sql.append("-- Incomplete survey comments")
        self.sql.append("UPDATE customer_surveys SET comments = NULL WHERE survey_id IN (SELECT survey_id FROM customer_surveys WHERE comments IS NOT NULL ORDER BY RANDOM() LIMIT 100);")
        self.sql.append("")
        self.sql.append("-- Some customers missing zip codes")
        self.sql.append("UPDATE customers SET zip_code = NULL WHERE customer_id IN (SELECT customer_id FROM customers WHERE zip_code IS NOT NULL ORDER BY RANDOM() LIMIT 15);")
        self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # SEQUENCE RESETS
    # ─────────────────────────────────────────────────────────────────────────
    def reset_sequences(self):
        self.sql.append("-- ============================================================================")
        self.sql.append("-- SECTION 16: RESET SEQUENCES")
        self.sql.append("-- ============================================================================\n")
        for tbl, pk in [
            ('customers', 'customer_id'), ('cats', 'cat_id'), ('staff', 'staff_id'),
            ('visits', 'visit_id'), ('interactions', 'interaction_id'),
            ('orders', 'order_id'), ('order_items', 'order_item_id'),
            ('events', 'event_id'), ('daily_weather', 'weather_id'),
            ('cat_health_records', 'record_id'), ('customer_surveys', 'survey_id'),
            ('menu_price_history', 'price_change_id'), ('daily_operations', 'operations_id'),
        ]:
            self.sql.append(f"SELECT setval(pg_get_serial_sequence('{tbl}', '{pk}'), (SELECT MAX({pk}) FROM {tbl}));")
        self.sql.append("")

    # ─────────────────────────────────────────────────────────────────────────
    # SUMMARY
    # ─────────────────────────────────────────────────────────────────────────
    def add_summary(self):
        self.sql.append(f"""
-- ==============================================================================
-- EXPANSION COMPLETE — DATA SUMMARY v2
-- ==============================================================================
--
-- TABLES: 17 original + 2 new (daily_operations) = 18 total
--
-- APPROXIMATE RECORD COUNTS:
--   visits:            ~{self.total_visits:,}
--   interactions:      ~{self.total_interactions:,}
--   orders:            ~{self.total_orders:,}
--   order_items:       ~{self.total_order_items:,}
--   customers:         ~{EXISTING_CUSTOMERS + NEW_CUSTOMERS}
--   cats:              ~{EXISTING_CATS + NEW_CATS}
--   events:            ~{len(self.events)}
--   daily_weather:     ~{len(self.weather_data)}
--   daily_operations:  ~{len(self.daily_operations)}
--
-- PLANTED CAUSAL SCENARIOS:
--   1A. Email campaign A/B test (Aug 2023): +12pp return, +$4 spend
--   1B. Menu layout A/B test (Jan 2024): +25% catnip latte, substitution
--   1C. Loyalty prompt A/B (Jun 2024): +18pp upgrade, no behavior change
--   2A. Shelter socialization DiD (Sep 2023): +15pp adoption for shelter 5
--   2B. Cover charge increase DiD (Aug 2023): -10% walk-in frequency
--   2C. Instagram campaign (Oct 2023): +30% new customers
--   3A. Senior cat RDD (7-year cutoff): +12pp adoption at cutoff
--   3B. Upgrade threshold fuzzy RDD (10 visits): +35pp compliance
--   3C. Yelp rating threshold (Mar 2024): +3 new customers/day
--   4A. Weather IV: spending propensity confounds crowd-spending OLS
--   4B. Distance IV: cat enthusiasm confounds visit-adoption OLS
--
-- MISSINGNESS:
--   MCAR: 5 days missing weather (sensor outage)
--   MAR:  food_quality NULL more often when satisfaction < 5
--   MNAR: shelter 5 cat health records 25% missing (hard to examine)
--
-- ==============================================================================
""")

    # ─────────────────────────────────────────────────────────────────────────
    # MAIN
    # ─────────────────────────────────────────────────────────────────────────
    def generate(self):
        print("Generating expansion data v2 (with causal scenarios)...")
        self.generate_ddl()
        print("  [1/13] DDL and schema modifications")
        self.generate_weather()
        print(f"  [2/13] Weather: {len(self.weather_data)} days")
        self.generate_daily_operations()
        print(f"  [3/13] Daily operations (menu layout + Yelp)")
        self.generate_events()
        print(f"  [4/13] Events: {len(self.events)}")
        self.generate_staff()
        print(f"  [5/13] Staff: {NEW_STAFF} new")
        self.generate_customers()
        print(f"  [6/13] Customers: {NEW_CUSTOMERS} new (with referral_source, zip)")
        self.generate_cats()
        print(f"  [7/13] Cats: {NEW_CATS} new (with senior_designation, socialization)")
        self.generate_transactions()
        print(f"  [8/13] Transactions: ~{self.total_visits:,} visits, ~{self.total_orders:,} orders")
        self.generate_email_campaign()
        print(f"  [9/13] Email campaign A/B test")
        self.generate_loyalty_and_upgrade()
        print(f"  [10/13] Loyalty prompt + upgrade threshold RDD")
        self.generate_health_records()
        print(f"  [11/13] Cat health records (MNAR for shelter 5)")
        self.generate_surveys()
        print(f"  [12/13] Customer surveys (MAR food_quality)")
        self.generate_price_history()
        print(f"  [13/13] Price history")
        self.add_data_quality_issues()
        self.reset_sequences()
        self.add_summary()
        return '\n'.join(self.sql)


if __name__ == '__main__':
    gen = DataGenerator()
    sql = gen.generate()
    out = '/home/claude/whiskers_waffles_expansion.sql'
    with open(out, 'w') as f:
        f.write(sql)
    print(f"\nOutput: {out}")
    print(f"Size: {len(sql):,} chars, {sql.count(chr(10)):,} lines")

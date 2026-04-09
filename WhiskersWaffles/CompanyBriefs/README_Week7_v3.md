# PPOL 5206 Week 7 Lab — File Manifest (v3, Cat Cafe Integration)

## What Changed in v3

Exercise 1 now uses the **Whiskers & Waffles cat cafe database** (from Weeks 3–5)
instead of the flat `grant_applications` table. Students reconnect with a familiar
normalized schema in a completely new context — a managed cloud database.

Exercises 2–5 are unchanged and still use the Week 6 S3/Glue/Athena grant data.

## For the Instructor

| File | Purpose | When to Use |
|------|---------|-------------|
| `whiskers_waffles_database.sql` | 12-table cat cafe database (DDL + DML) | Load into RDS before class |
| `01_setup_rds_catcafe.sql` | Setup instructions, verification, and Exercise 1 queries | Reference during RDS pre-provisioning |
| `02_analytical_queries.sql` | All SQL for Exercises 2–4 (unchanged) | Reference during class |
| `03_lake_formation_setup.sh` | IAM roles + LF permissions (unchanged) | Run section-by-section before class |
| `iam_student_inline_policy.json` | Inline policy for student role (unchanged) | Apply in IAM console |
| `iam_restricted_role_trust_policy.json` | Trust policy for restricted analyst role (unchanged) | Apply when creating role |

## For Students

| File | Purpose |
|------|---------|
| `04_boto3_starter.py` | Starter code for Exercise 5 (unchanged) |
| `05_quick_reference.docx` | One-page cheat sheet (unchanged) |

## Pre-Class Checklist

- [ ] Upload `whiskers_waffles_database.sql` to S3 bucket root (not inside raw/)
- [ ] Connect to RDS via CloudShell and run `\i whiskers_waffles_database.sql`
- [ ] Run verification queries from `01_setup_rds_catcafe.sql` — confirm 12 tables, correct row counts
- [ ] Verify Week 6 S3/Glue data is still accessible in Athena (needed for Exercises 2–5)
- [ ] Run `03_lake_formation_setup.sh` sections 1–5 — verify Athena still works afterward
- [ ] Test sts:AssumeRole from a fresh IAM user to confirm trust policy is correct
- [ ] Create Redshift external schema and confirm `SELECT COUNT(*) FROM glue_data.grants` returns rows
- [ ] Run one warm-up query in Redshift Serverless to avoid cold-start surprise in class
- [ ] Confirm Snowflake environment from Week 5 is still accessible

## Architecture Overview

```
Exercise 1 (RDS):        Whiskers & Waffles → PostgreSQL on RDS
                          (Transactional / OLTP / normalized)

Exercises 2–5 (S3/Glue): Grant Applications → S3 → Glue → Athena / Redshift / Snowflake
                          (Analytical / OLAP / serverless pipeline from Week 6)
```

The split is intentional: Exercise 1 demonstrates what a *transactional* database
looks and feels like (constraints, instant read-after-write, ACID). Exercises 2–5
demonstrate analytical engines querying the same S3 data through different lenses.

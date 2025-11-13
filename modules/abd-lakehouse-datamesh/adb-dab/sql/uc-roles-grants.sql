-- ====================================================================================================
-- Unity Catalog Setup for Domain-Specific Data Mesh
-- ====================================================================================================
-- This script creates a Unity Catalog structure for a specific business domain following the lakehouse
-- architecture with RBAC best practices.
--
-- TEMPLATE CONFIGURATION:
--   This is a TEMPLATE file. To use it for a different domain:
--   
--   Option 1: Use the PowerShell generator script
--     .\Generate-DomainSQL.ps1 -Domain finance
--   
--   Option 2: Use the Python generator script
--     python generate_domain_sql.py --domain finance --output finance-uc-setup.sql
--   
--   Option 3: Manual find & replace
--     Replace 'amrnet' with your domain name throughout this file
--
-- Current Configuration:
--   Domain: amrnet
--   Groups: amrnet_data_engineers, amrnet_data_scientists, amrnet_bi_readers
-- ====================================================================================================

-- ====================================================================================================
-- 1. Create the domain catalog
-- ====================================================================================================
CREATE CATALOG IF NOT EXISTS amrnet_catalog 
  COMMENT 'Unity Catalog for the AMRNet domain';

-- M365 Security Groups used or Custom Security Groups (using prefix pattern: <domain>_<role>):
-- `amrnet_data_engineers`    : Data Engineers group for AMRNet domain
-- `amrnet_data_scientists`   : Data Scientists group for AMRNet domain (ML workloads)
-- `amrnet_bi_readers`        : BI Readers group for AMRNet domain
-- Assign catalog ownership to the amrnet_data_engineers group (owner) 
ALTER CATALOG amrnet_catalog 
  OWNER TO `amrnet_data_engineers`;

-- (Optional) Delegate catalog admin rights to platform admins
GRANT ALL PRIVILEGES ON CATALOG amrnet_catalog TO `data_platform_admins`;
GRANT MANAGE ON CATALOG amrnet_catalog TO `data_platform_admins`;  -- allows them to manage grants/ownership

-- Grant catalog usage to appropriate groups
GRANT USE CATALOG ON CATALOG amrnet_catalog TO `amrnet_data_engineers`;
GRANT CREATE SCHEMA ON CATALOG amrnet_catalog TO `amrnet_data_engineers`;
GRANT USE CATALOG ON CATALOG amrnet_catalog TO `amrnet_bi_readers`;   -- allows BI readers to see authorized schemas
GRANT USE CATALOG ON CATALOG amrnet_catalog TO `amrnet_data_scientists`;  -- allows data scientists to access catalog

-- (Optional) Make the catalog browsable (metadata viewable) by all
GRANT BROWSE ON CATALOG amrnet_catalog TO `users`;  -- 'users' = special All Users group

-- 2. Create schemas by layer in the AMRNet catalog
CREATE SCHEMA IF NOT EXISTS amrnet_catalog.raw;
ALTER SCHEMA amrnet_catalog.raw OWNER TO `amrnet_data_engineers`;
-- No reader rights on raw (only owner has access)
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.raw TO `amrnet_data_engineers`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA amrnet_catalog.raw TO `amrnet_data_engineers`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.curated;
ALTER SCHEMA amrnet_catalog.curated OWNER TO `amrnet_data_engineers`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.curated TO `amrnet_data_engineers`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.curated TO `amrnet_data_engineers`;

-- Data scientists: read access to curated data for feature engineering
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.curated TO `amrnet_data_scientists`;
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.curated TO `amrnet_data_scientists`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.curated TO `amrnet_data_scientists`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.gold;
ALTER SCHEMA amrnet_catalog.gold OWNER TO `amrnet_data_engineers`;

GRANT USE SCHEMA ON SCHEMA amrnet_catalog.gold TO `amrnet_data_engineers`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.gold TO `amrnet_data_engineers`;

-- BI readers: read access to tables in the gold schema
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.gold TO `amrnet_bi_readers`;

-- Grant SELECT on all current and future tables in the gold schema to BI readers
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.gold TO `amrnet_bi_readers`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.gold TO `amrnet_bi_readers`;  -- auto-grant for tables created later

-- Data scientists: read access to gold data for analysis and model training
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.gold TO `amrnet_data_scientists`;
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.gold TO `amrnet_data_scientists`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.gold TO `amrnet_data_scientists`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.reference;
ALTER SCHEMA amrnet_catalog.reference OWNER TO `amrnet_data_engineers`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.reference TO `amrnet_data_engineers`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.reference TO `amrnet_data_engineers`;

-- BI readers on reference (same logic as gold)
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.reference TO `amrnet_bi_readers`;
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.reference TO `amrnet_bi_readers`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.reference TO `amrnet_bi_readers`;

-- Data scientists: read access to reference data
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.reference TO `amrnet_data_scientists`;
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.reference TO `amrnet_data_scientists`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.reference TO `amrnet_data_scientists`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.ml;
ALTER SCHEMA amrnet_catalog.ml OWNER TO `amrnet_data_engineers`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.ml TO `amrnet_data_engineers`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA amrnet_catalog.ml TO `amrnet_data_engineers`;
-- No read grant to BI on ml
GRANT USAGE ON SCHEMA amrnet_catalog.ml TO `amrnet_data_engineers`;

-- Data scientists: full access to ML schema for feature engineering and model development
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.ml TO `amrnet_data_scientists`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA amrnet_catalog.ml TO `amrnet_data_scientists`;
GRANT SELECT, MODIFY ON ALL TABLES IN SCHEMA amrnet_catalog.ml TO `amrnet_data_scientists`;
GRANT SELECT, MODIFY ON FUTURE TABLES IN SCHEMA amrnet_catalog.ml TO `amrnet_data_scientists`;

-- 3. Create Unity Catalog volumes for files (landing zone and ML models)
-- We assume that the necessary External Locations and credentials are already configured for these Azure Data Lake paths.
CREATE EXTERNAL VOLUME amrnet_catalog.raw.landing
  COMMENT "Landing zone for raw files in the AMRNet domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/amrnet/raw-landing/";
ALTER VOLUME amrnet_catalog.raw.landing OWNER TO `amrnet_data_engineers`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME amrnet_catalog.raw.landing TO `amrnet_data_engineers`;
GRANT READ VOLUME ON VOLUME amrnet_catalog.raw.landing TO `bi_ingestion_service`;  -- e.g., an ingestion service if needed
GRANT ALL PRIVILEGES ON VOLUME amrnet_catalog.raw.landing TO `data_platform_admins`;

CREATE EXTERNAL VOLUME amrnet_catalog.ml.models
  COMMENT "Storage for ML artifacts and models in the AMRNet domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/amrnet/ml-models/";
ALTER VOLUME amrnet_catalog.ml.models OWNER TO `amrnet_data_engineers`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME amrnet_catalog.ml.models TO `amrnet_data_engineers`;
GRANT ALL PRIVILEGES ON VOLUME amrnet_catalog.ml.models TO `data_platform_admins`;
-- (No grant to BI readers on ML volumes by default)

-- Data scientists: full access to ML volumes for model artifacts
GRANT READ VOLUME, WRITE VOLUME ON VOLUME amrnet_catalog.ml.models TO `amrnet_data_scientists`;

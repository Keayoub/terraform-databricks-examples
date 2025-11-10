-- 1. Create the Sales domain catalog
-- 1. Create the AMRNet domain catalog
CREATE CATALOG IF NOT EXISTS amrnet_catalog 
  COMMENT "Unity Catalog for the AMRNet domain";

-- M365 Security Groups used or Custom Security Groups:
-- `data_engineers_amrnet`    : Data Engineers group for AMRNet domain
-- Assign catalog ownership to the data_engineers_amrnet group (owner) 
ALTER CATALOG amrnet_catalog 
  OWNER TO `data_engineers_amrnet`;

TODO: add Data scientists group for ml schema

-- (Optional) Delegate catalog admin rights to platform admins
GRANT ALL PRIVILEGES ON CATALOG amrnet_catalog TO `data_platform_admins`;
GRANT MANAGE ON CATALOG amrnet_catalog TO `data_platform_admins`;  -- allows them to manage grants/ownership

-- Grant catalog usage to appropriate groups
GRANT USE CATALOG ON CATALOG amrnet_catalog TO `data_engineers_amrnet`;
GRANT CREATE SCHEMA ON CATALOG amrnet_catalog TO `data_engineers_amrnet`;
GRANT USE CATALOG ON CATALOG amrnet_catalog TO `bi_readers_amrnet`;   -- allows BI readers to see authorized schemas

-- (Optional) Make the catalog browsable (metadata viewable) by all
GRANT BROWSE ON CATALOG amrnet_catalog TO `users`;  -- 'users' = special All Users group

-- 2. Create schemas by layer in the AMRNet catalog
CREATE SCHEMA IF NOT EXISTS amrnet_catalog.raw;
ALTER SCHEMA amrnet_catalog.raw OWNER TO `data_engineers_amrnet`;
-- No reader rights on raw (only owner has access)
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.raw TO `data_engineers_amrnet`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA amrnet_catalog.raw TO `data_engineers_amrnet`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.curated;
ALTER SCHEMA amrnet_catalog.curated OWNER TO `data_engineers_amrnet`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.curated TO `data_engineers_amrnet`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.curated TO `data_engineers_amrnet`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.gold;
ALTER SCHEMA amrnet_catalog.gold OWNER TO `data_engineers_amrnet`;

GRANT USE SCHEMA ON SCHEMA amrnet_catalog.gold TO `data_engineers_amrnet`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.gold TO `data_engineers_amrnet`;

-- BI readers: read access to tables in the gold schema
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.gold TO `bi_readers_amrnet`;

-- Grant SELECT on all current and future tables in the gold schema to BI readers
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.gold TO `bi_readers_amrnet`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.gold TO `bi_readers_amrnet`;  -- auto-grant for tables created later

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.reference;
ALTER SCHEMA amrnet_catalog.reference OWNER TO `data_engineers_amrnet`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.reference TO `data_engineers_amrnet`;
GRANT CREATE TABLE ON SCHEMA amrnet_catalog.reference TO `data_engineers_amrnet`;

-- BI readers on reference (same logic as gold)
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.reference TO `bi_readers_amrnet`;
GRANT SELECT ON ALL TABLES IN SCHEMA amrnet_catalog.reference TO `bi_readers_amrnet`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA amrnet_catalog.reference TO `bi_readers_amrnet`;

CREATE SCHEMA IF NOT EXISTS amrnet_catalog.ml;
ALTER SCHEMA amrnet_catalog.ml OWNER TO `data_engineers_amrnet`;
GRANT USE SCHEMA ON SCHEMA amrnet_catalog.ml TO `data_engineers_amrnet`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA amrnet_catalog.ml TO `data_engineers_amrnet`;
-- No read grant to BI on ml
GRANT USAGE ON SCHEMA amrnet_catalog.ml TO `data_engineers_amrnet`;

-- 3. Create Unity Catalog volumes for files (landing zone and ML models)
-- We assume that the necessary External Locations and credentials are already configured for these Azure Data Lake paths.
CREATE EXTERNAL VOLUME amrnet_catalog.raw.landing
  COMMENT "Landing zone for raw files in the AMRNet domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/amrnet/raw-landing/";
ALTER VOLUME amrnet_catalog.raw.landing OWNER TO `data_engineers_amrnet`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME amrnet_catalog.raw.landing TO `data_engineers_amrnet`;
GRANT READ VOLUME ON VOLUME amrnet_catalog.raw.landing TO `bi_ingestion_service`;  -- e.g., an ingestion service if needed
GRANT ALL PRIVILEGES ON VOLUME amrnet_catalog.raw.landing TO `data_platform_admins`;

CREATE EXTERNAL VOLUME amrnet_catalog.ml.models
  COMMENT "Storage for ML artifacts and models in the AMRNet domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/amrnet/ml-models/";
ALTER VOLUME amrnet_catalog.ml.models OWNER TO `data_engineers_amrnet`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME amrnet_catalog.ml.models TO `data_engineers_amrnet`;
GRANT ALL PRIVILEGES ON VOLUME amrnet_catalog.ml.models TO `data_platform_admins`;
-- (No grant to BI readers on ML volumes by default)

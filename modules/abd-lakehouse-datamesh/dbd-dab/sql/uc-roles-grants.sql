-- 1. Create the Sales domain catalog
CREATE CATALOG IF NOT EXISTS sales_catalog 
  COMMENT "Unity Catalog for the Sales domain";

-- Assign catalog ownership to the data_engineers_sales group (owner)
ALTER CATALOG sales_catalog 
  OWNER TO `data_engineers_sales`;

-- (Optional) Delegate catalog admin rights to platform admins
GRANT ALL PRIVILEGES ON CATALOG sales_catalog TO `data_platform_admins`;
GRANT MANAGE ON CATALOG sales_catalog TO `data_platform_admins`;  -- allows them to manage grants/ownership

-- Grant catalog usage to appropriate groups
GRANT USE CATALOG ON CATALOG sales_catalog TO `data_engineers_sales`;
GRANT CREATE SCHEMA ON CATALOG sales_catalog TO `data_engineers_sales`;
GRANT USE CATALOG ON CATALOG sales_catalog TO `bi_readers_sales`;   -- allows BI readers to see authorized schemas

-- (Optional) Make the catalog browsable (metadata viewable) by all
GRANT BROWSE ON CATALOG sales_catalog TO `users`;  -- 'users' = special All Users group

-- 2. Create schemas by layer in the Sales catalog
CREATE SCHEMA IF NOT EXISTS sales_catalog.raw;
ALTER SCHEMA sales_catalog.raw OWNER TO `data_engineers_sales`;
-- No reader rights on raw (only owner has access)
-- data_engineers_sales implicitly has all rights via ownership, otherwise we could make it explicit:
GRANT USE SCHEMA ON SCHEMA sales_catalog.raw TO `data_engineers_sales`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA sales_catalog.raw TO `data_engineers_sales`;

CREATE SCHEMA IF NOT EXISTS sales_catalog.curated;
ALTER SCHEMA sales_catalog.curated OWNER TO `data_engineers_sales`;
GRANT USE SCHEMA ON SCHEMA sales_catalog.curated TO `data_engineers_sales`;
GRANT CREATE TABLE ON SCHEMA sales_catalog.curated TO `data_engineers_sales`;


-- No grant to bi_readers_sales on curated by default
CREATE SCHEMA IF NOT EXISTS sales_catalog.gold;
ALTER SCHEMA sales_catalog.gold OWNER TO `data_engineers_sales`;

GRANT USE SCHEMA ON SCHEMA sales_catalog.gold TO `data_engineers_sales`;
GRANT CREATE TABLE ON SCHEMA sales_catalog.gold TO `data_engineers_sales`;

-- BI readers: read access to tables in the gold schema
GRANT USE SCHEMA ON SCHEMA sales_catalog.gold TO `bi_readers_sales`;

-- Grant SELECT on all current and future tables in the gold schema to BI readers
GRANT SELECT ON ALL TABLES IN SCHEMA sales_catalog.gold TO `bi_readers_sales`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA sales_catalog.gold TO `bi_readers_sales`;  -- auto-grant for tables created later

CREATE SCHEMA IF NOT EXISTS sales_catalog.reference;
ALTER SCHEMA sales_catalog.reference OWNER TO `data_engineers_sales`;
GRANT USE SCHEMA ON SCHEMA sales_catalog.reference TO `data_engineers_sales`;
GRANT CREATE TABLE ON SCHEMA sales_catalog.reference TO `data_engineers_sales`;

-- BI readers on reference (same logic as gold)
GRANT USE SCHEMA ON SCHEMA sales_catalog.reference TO `bi_readers_sales`;
GRANT SELECT ON ALL TABLES IN SCHEMA sales_catalog.reference TO `bi_readers_sales`;
GRANT SELECT ON FUTURE TABLES IN SCHEMA sales_catalog.reference TO `bi_readers_sales`;

CREATE SCHEMA IF NOT EXISTS sales_catalog.ml;
ALTER SCHEMA sales_catalog.ml OWNER TO `data_engineers_sales`;
GRANT USE SCHEMA ON SCHEMA sales_catalog.ml TO `data_engineers_sales`;
GRANT CREATE TABLE, CREATE VOLUME ON SCHEMA sales_catalog.ml TO `data_engineers_sales`;
-- No read grant to BI on ml
GRANT USAGE ON SCHEMA sales_catalog.ml TO `data_engineers_sales`;

-- 3. Create Unity Catalog volumes for files (landing zone and ML models)
-- We assume that the necessary External Locations and credentials are already configured for these Azure Data Lake paths.
CREATE EXTERNAL VOLUME sales_catalog.raw.landing
  COMMENT "Landing zone for raw files in the Sales domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/sales/raw-landing/";
ALTER VOLUME sales_catalog.raw.landing OWNER TO `data_engineers_sales`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME sales_catalog.raw.landing TO `data_engineers_sales`;
GRANT READ VOLUME ON VOLUME sales_catalog.raw.landing TO `bi_ingestion_service`;  -- e.g., an ingestion service if needed
GRANT ALL PRIVILEGES ON VOLUME sales_catalog.raw.landing TO `data_platform_admins`;


CREATE EXTERNAL VOLUME sales_catalog.ml.models
  COMMENT "Storage for ML artifacts and models in the Sales domain"
  LOCATION "abfss://<container-name>@<storage-account>.dfs.core.windows.net/sales/ml-models/";
ALTER VOLUME sales_catalog.ml.models OWNER TO `data_engineers_sales`;
GRANT READ VOLUME, WRITE VOLUME ON VOLUME sales_catalog.ml.models TO `data_engineers_sales`;
GRANT ALL PRIVILEGES ON VOLUME sales_catalog.ml.models TO `data_platform_admins`;
-- (No grant to BI readers on ML volumes by default)

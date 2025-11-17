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

-- ====================================================================================================
-- 4. Compute Resources & Cluster Access Control
-- ====================================================================================================
-- Note: Cluster permissions are typically managed via Databricks workspace API or Terraform.
-- This section documents the recommended cluster access patterns for each role.
--
-- CLUSTER POLICIES:
-- Create domain-specific cluster policies to enforce cost controls and governance.
-- Policies should be created via Databricks UI, API, or Terraform.
--
-- Recommended Cluster Policy: amrnet_standard_policy
--   - Max DBU per hour limit
--   - Fixed node types for cost control
--   - Required tags: Domain=amrnet, Team=<team_name>
--   - Autotermination: 30 minutes
--   - Unity Catalog enabled: true
--   - Data Security Mode: USER_ISOLATION
--
-- CLUSTER ACCESS PATTERNS:
--
-- Data Engineers (amrnet_data_engineers):
--   - CAN_ATTACH_TO: Shared interactive clusters
--   - CAN_RESTART: Shared interactive clusters
--   - CAN_MANAGE: Personal clusters created by team members
--   - Cluster Policy Access: CAN_USE (amrnet_standard_policy)
--   - Recommended: Use jobs clusters for production workloads
--
-- Data Scientists (amrnet_data_scientists):
--   - CAN_ATTACH_TO: Shared ML clusters
--   - CAN_RESTART: Shared ML clusters
--   - Cluster Policy Access: CAN_USE (amrnet_ml_policy)
--   - Recommended: Use single-user clusters with ML runtime
--
-- BI Readers (amrnet_bi_readers):
--   - No direct cluster access (use SQL Warehouses only)
--   - CAN_USE: Domain SQL Warehouse (amrnet_sql_warehouse)
--
-- INSTANCE POOLS (Optional):
-- Create instance pools for faster cluster startup times:
--   - amrnet_engineer_pool: For data engineering workloads
--   - amrnet_ml_pool: For ML workloads with GPU support (if needed)
--
-- SQL WAREHOUSES:
-- Recommended SQL Warehouse Configuration: amrnet_sql_warehouse
--   - Type: PRO (for Serverless) or CLASSIC
--   - Size: Small to Medium (based on concurrency needs)
--   - Auto-stop: 10 minutes
--   - Max Clusters: 3 (for auto-scaling)
--   - Tags: Domain=amrnet
--
-- SQL Warehouse Permissions:
--   - data_platform_admins: CAN_MANAGE
--   - amrnet_data_engineers: CAN_USE
--   - amrnet_data_scientists: CAN_USE
--   - amrnet_bi_readers: CAN_USE
--
-- ====================================================================================================
-- IMPLEMENTATION NOTES:
-- ====================================================================================================
-- The compute resources (clusters, policies, pools, warehouses) should be created using:
--   1. Databricks Terraform Provider (recommended)
--   2. Databricks REST API
--   3. Databricks CLI
--   4. Databricks UI (for manual setup)
--
-- Example Terraform configuration is available in:
--   - modules/databricks-department-clusters/
--
-- After creating compute resources, assign permissions using the Databricks Permissions API
-- or through Terraform resource blocks.
-- ====================================================================================================

-- ====================================================================================================
-- 5. Workspace Libraries & Package Management
-- ====================================================================================================
-- Note: Library installations are managed via Databricks Libraries API, UI, or Terraform.
-- This section documents the recommended library management patterns for each role.
--
-- LIBRARY TYPES SUPPORTED:
--   - PyPI packages (Python)
--   - Maven/JAR packages (Scala/Java)
--   - CRAN packages (R)
--   - Wheel files (.whl)
--   - Egg files (.egg)
--   - JAR files
--
-- LIBRARY MANAGEMENT APPROACHES:
--
-- 1. CLUSTER LIBRARIES (Attached to specific clusters):
--    - Installed on cluster startup
--    - Available to all notebooks on that cluster
--    - Requires cluster restart to update
--
-- 2. NOTEBOOK-SCOPED LIBRARIES (Installed via %pip or %conda):
--    - Installed at notebook runtime
--    - Only available in that notebook session
--    - No cluster restart required
--    - Recommended for experimentation
--
-- 3. WORKSPACE LIBRARIES (Global library repository):
--    - Centrally managed libraries
--    - Can be attached to multiple clusters
--    - Version controlled and auditable
--
-- ====================================================================================================
-- DOMAIN-SPECIFIC LIBRARY RECOMMENDATIONS:
-- ====================================================================================================
--
-- DATA ENGINEERING LIBRARIES (amrnet_data_engineers):
--   Common PyPI packages:
--     - pandas>=2.0.0
--     - pyarrow>=10.0.0
--     - pyspark>=3.4.0
--     - delta-spark>=2.4.0
--     - great-expectations>=0.17.0  (data quality)
--     - dbt-databricks>=1.6.0       (for dbt transformations)
--     - azure-storage-blob>=12.0.0  (Azure integration)
--     - azure-identity>=1.12.0
--
--   Maven packages:
--     - io.delta:delta-core_2.12:2.4.0
--     - org.apache.hadoop:hadoop-azure:3.3.4
--
-- DATA SCIENCE / ML LIBRARIES (amrnet_data_scientists):
--   Common PyPI packages:
--     - scikit-learn>=1.3.0
--     - xgboost>=2.0.0
--     - lightgbm>=4.0.0
--     - tensorflow>=2.13.0
--     - torch>=2.0.0
--     - mlflow>=2.8.0
--     - hyperopt>=0.2.7
--     - shap>=0.42.0                (model interpretability)
--     - plotly>=5.17.0              (visualizations)
--     - seaborn>=0.12.0
--
--   Bio/Scientific Computing:
--     - biopython>=1.81             (biological computation)
--     - numpy>=1.24.0
--     - scipy>=1.11.0
--     - statsmodels>=0.14.0
--     - networkx>=3.1               (graph analysis)
--     - opencv-python>=4.8.0        (computer vision)
--
--   Deep Learning Frameworks:
--     - transformers>=4.30.0        (Hugging Face)
--     - sentence-transformers>=2.2.0
--     - accelerate>=0.20.0
--
-- BI / ANALYTICS LIBRARIES (amrnet_bi_readers):
--   Limited library access (SQL Warehouse based):
--     - Standard SQL functions only
--     - No custom library installations
--     - Use built-in Databricks SQL functions
--
-- ====================================================================================================
-- LIBRARY INSTALLATION PATTERNS:
-- ====================================================================================================
--
-- Pattern 1: Cluster Init Scripts (for system-level dependencies)
--   Create init scripts in DBFS or Unity Catalog volumes:
--   Location: /Volumes/amrnet_catalog/ml/scripts/init-bio-libs.sh
--
-- Pattern 2: Cluster Libraries (via Terraform)
--   See compute-resources.tf for examples
--
-- Pattern 3: Notebook-scoped installation (for experimentation)
--   In notebooks, use:
--     %pip install biopython==1.81
--     %pip install --upgrade scikit-learn
--
-- Pattern 4: Requirements file (for reproducibility)
--   Store requirements.txt in Unity Catalog volumes:
--   /Volumes/amrnet_catalog/ml/configs/requirements.txt
--   Install via: %pip install -r /Volumes/amrnet_catalog/ml/configs/requirements.txt
--
-- ====================================================================================================
-- LIBRARY GOVERNANCE & BEST PRACTICES:
-- ====================================================================================================
--
-- 1. VERSION PINNING:
--    - Always specify versions for production clusters
--    - Use requirements.txt for reproducibility
--    - Document library versions in cluster tags
--
-- 2. SECURITY SCANNING:
--    - Use approved package repositories only
--    - Scan libraries for vulnerabilities (e.g., using safety, bandit)
--    - Maintain allow-list of approved packages
--
-- 3. COST CONTROL:
--    - Minimize library installations on auto-scaling clusters
--    - Use cluster policies to restrict expensive libraries
--    - Consider using Docker containers for heavy dependencies
--
-- 4. PERFORMANCE:
--    - Pre-install common libraries via init scripts
--    - Use cluster pools with pre-warmed libraries
--    - Consider creating custom runtime images
--
-- 5. ISOLATION:
--    - Use virtual environments in notebooks (%pip install)
--    - Separate production and development libraries
--    - Document library dependencies in project README
--
-- ====================================================================================================
-- IMPLEMENTATION EXAMPLE (Terraform):
-- ====================================================================================================
-- See the compute-resources.tf file for examples of:
--   - Installing cluster libraries via Terraform
--   - Creating init scripts in Unity Catalog volumes
--   - Managing library permissions per role
-- ====================================================================================================



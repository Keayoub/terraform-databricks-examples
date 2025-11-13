-- Use UC catalog
USE CATALOG ${bundle.var.catalog_name};

CREATE SCHEMA IF NOT EXISTS ${bundle.var.schema_curated};
CREATE SCHEMA IF NOT EXISTS ${bundle.var.schema_gold};

-- Silver (typage + règles simples)
CREATE OR REPLACE TABLE ${bundle.var.catalog_name}.${bundle.var.schema_curated}.orders_silver AS
SELECT
  CAST(order_id AS STRING)      AS order_id,
  CAST(customer_id AS STRING)   AS customer_id,
  CAST(amount AS DECIMAL(18,2)) AS amount,
  TO_DATE(order_date)           AS order_date,
  _ingest_ts,
  _source_file
FROM ${bundle.var.catalog_name}.${bundle.var.schema_raw}.orders_bronze
WHERE order_id IS NOT NULL;

-- Gold (vue agrégée)
CREATE OR REPLACE VIEW ${bundle.var.catalog_name}.${bundle.var.schema_gold}.v_orders_monthly AS
SELECT
  DATE_TRUNC('month', order_date) AS month,
  SUM(amount) AS total_amount,
  COUNT(DISTINCT order_id) AS orders
FROM ${bundle.var.catalog_name}.${bundle.var.schema_curated}.orders_silver
GROUP BY 1;

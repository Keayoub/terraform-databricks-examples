# Databricks notebook source
from pyspark.sql.functions import input_file_name, current_timestamp

# Variables (UC)
catalog = spark.conf.get("bundle.var.catalog_name", "sales_catalog")
schema_raw = spark.conf.get("bundle.var.schema_raw", "raw")

spark.sql(f"USE CATALOG {catalog}")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {schema_raw}")

bronze_tbl = f"{catalog}.{schema_raw}.orders_bronze"
landing_path = f"/Volumes/{catalog}/landing/sales/"  # si landing séparée
# OU si landing intégré au schema raw:
# landing_path = f"/Volumes/{catalog}/{schema_raw}/sales_landing/"

df = (spark.readStream.format("cloudFiles")
      .option("cloudFiles.format", "json")      # csv/json/parquet…
      .option("cloudFiles.inferColumnTypes", "true")
      .option("cloudFiles.schemaLocation", f"/mnt/checkpoints/{bronze_tbl}")
      .load(landing_path)
      .withColumn("_source_file", input_file_name())
      .withColumn("_ingest_ts", current_timestamp())
     )

(df.writeStream
   .format("delta")
   .option("checkpointLocation", f"/mnt/checkpoints/{bronze_tbl}_dw")
   .outputMode("append")
   .toTable(bronze_tbl))

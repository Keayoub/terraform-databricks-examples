# Generating Markdown file summarizing Data & AI courses by category

import os

# Ensure output directory exists
output_dir = "./"
os.makedirs(output_dir, exist_ok=True)

# Markdown content
md_content = """# 📚 Data & AI Courses Summary

This document provides a categorized summary of Data & AI courses available from the Learning Download Center.

---

## 🧠 AI Development Courses

| Course Code | Title                                                             | Last Updated     |
|------------|--------------------------------------------------------------------|------------------|
| AI-102T00   | Develop AI solutions in Azure                                     | Oct 16, 2025     |
| AI-3002     | Develop AI information extraction solutions in Azure              | Jun 23, 2025     |
| AI-3003     | Develop natural language solutions in Azure                       | Jun 12, 2025     |
| AI-3004     | Develop computer vision solutions in Azure                        | Jun 12, 2025     |
| AI-3016     | Develop generative AI apps in Azure                               | Aug 28, 2025     |
| AI-3026     | Develop AI agents on Azure                                        | Oct 16, 2025     |

---

## 🧩 AI Strategy & Business Integration

| Course Code | Title                                                             | Last Updated     |
|------------|--------------------------------------------------------------------|------------------|
| AI-3017     | AI for business leaders                                           | Aug 07, 2025     |
| AI-3024     | Design a dream destination with AI                                | Dec 06, 2024     |
| AI-3025     | Work smarter with AI                                              | Jan 17, 2025     |

---

## 🔍 AI Search & Data Integration

| Course Code | Title                                                             | Last Updated     |
|------------|--------------------------------------------------------------------|------------------|
| AI-3019     | Build AI Apps with Azure Database for PostgreSQL                 | Sep 06, 2024     |
| AI-3022     | Implement knowledge mining with Azure AI Search                  | Dec 13, 2024     |

---

## 📊 Data Engineering & Analytics

| Course Code | Title                                                             | Last Updated     |
|------------|--------------------------------------------------------------------|------------------|
| DP-080T00   | Query and modify data with Transact-SQL                           | Aug 28, 2025     |
| DP-100T01   | Designing and implementing a data science solution on Azure       | Jan 24, 2025     |
| DP-203T00   | Data Engineering on Microsoft Azure                               | Feb 09, 2024     |
| DP-3001     | Migrate SQL Server workload to Azure SQL                          | Oct 09, 2025     |
| DP-300T00   | Implement scalable database solutions using Azure SQL             | Aug 28, 2025     |
| DP-3011     | Implement a Data Analytics Solution with Azure Databricks         | Oct 02, 2025     |
| DP-3014     | Build machine learning solutions using Azure Databricks           | Aug 28, 2025     |
| DP-3015     | Getting Started with Cosmos DB NoSQL Development                  | Jan 26, 2024     |
| DP-3020     | Develop data-driven applications with Azure SQL Database          | Dec 13, 2024     |
| DP-3021     | Configure and migrate to Azure Database for PostgreSQL            | Sep 27, 2024     |
| DP-3028     | Implement Generative AI engineering with Azure Databricks         | Jul 17, 2025     |

---

## 🧵 Microsoft Fabric & Power BI

| Course Code | Title                                                             | Last Updated     |
|------------|--------------------------------------------------------------------|------------------|
| DP-3029     | Work smarter with Copilot in Microsoft Fabric                     | Aug 28, 2025     |
| DP-420T00   | Designing and Implementing Cloud-Native Apps with Cosmos DB       | Nov 15, 2024     |
| DP-600T00   | Microsoft Fabric Analytics Engineer                               | Nov 22, 2024     |
| DP-601T00   | Implement a Lakehouse with Microsoft Fabric                       | Feb 07, 2025     |
| DP-602T00   | Implement a Data Warehouse with Microsoft Fabric                  | Jan 31, 2025     |
| DP-603T00   | Implement Real-Time Intelligence with Microsoft Fabric            | Jan 31, 2025     |
| DP-604T00   | Implement ML solutions for AI with Microsoft Fabric               | Jan 31, 2025     |
| DP-605T00   | Prepare and visualize data with Microsoft Power BI                | Oct 02, 2025     |
| DP-700T00   | Microsoft Fabric Data Engineer                                    | May 29, 2025     |
| DP-900T00   | Introduction to Microsoft Azure Data                              | Aug 13, 2025     |
"""

# Save to Markdown file
md_file_path = os.path.join(output_dir, "data_ai_courses_summary.md")
with open(md_file_path, "w", encoding="utf-8") as f:
    f.write(md_content)

md_file_path

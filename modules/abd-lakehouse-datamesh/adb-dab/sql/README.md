# Unity Catalog Domain Setup Scripts

This directory contains SQL scripts and utilities for setting up Unity Catalog structures for different business domains in a data mesh architecture.

## Files

- **`uc-roles-grants.sql`** - Template SQL script for Unity Catalog setup with RBAC
- **`generate_domain_sql.py`** - Python utility to generate domain-specific SQL from the template

## Quick Start

### Option 1: Manual Find & Replace

1. Copy `uc-roles-grants.sql` to a new file (e.g., `finance-uc-setup.sql`)
2. Replace all instances of `amrnet` with your domain name:
   - `amrnet` → your domain name (lowercase)
   - `AMRNet` → your domain name (uppercase)
3. Update storage account paths in the EXTERNAL VOLUME sections
4. Execute in Databricks SQL

### Option 2: Using the Python Generator

Generate a domain-specific SQL script automatically:

```powershell
# Generate for finance domain and save to file
python generate_domain_sql.py --domain finance --output finance-uc-setup.sql

# Generate for sales domain and save to file
python generate_domain_sql.py --domain sales --output sales-uc-setup.sql

# Generate for hr domain (print to console)
python generate_domain_sql.py --domain hr
```

### Option 3: Using PowerShell

Quick find & replace using PowerShell:

```powershell
# Set your domain name
$domain = "finance"

# Read template and replace domain name
$content = Get-Content uc-roles-grants.sql -Raw
$content = $content -replace 'amrnet', $domain.ToLower()
$content = $content -replace 'AMRNet', $domain.ToUpper()
$content = $content -replace 'Amrnet', (Get-Culture).TextInfo.ToTitleCase($domain)

# Save to new file
$content | Set-Content "${domain}-uc-setup.sql"

Write-Host "✅ Generated ${domain}-uc-setup.sql"
```

## What Gets Created

The script creates a complete Unity Catalog structure for your domain:

### Catalog
- `{domain}_catalog` - Main catalog for the domain

### Schemas (Medallion Architecture)
- `{domain}_catalog.raw` - Raw/bronze layer
- `{domain}_catalog.curated` - Curated/silver layer
- `{domain}_catalog.gold` - Gold layer
- `{domain}_catalog.reference` - Reference data
- `{domain}_catalog.ml` - Machine learning artifacts

### Security Groups (Expected to exist in Azure AD/Entra ID)
- `{domain}_data_engineers` - Full access to all layers
- `{domain}_data_scientists` - Read access to curated/gold/reference, full access to ML
- `{domain}_bi_readers` - Read access to gold and reference
- `data_platform_admins` - Platform-level administrators (domain-agnostic)

### Volumes
- `{domain}_catalog.raw.landing` - Landing zone for raw files
- `{domain}_catalog.ml.models` - ML model artifacts storage

### Compute Resources (Documented, created via Terraform)
- Cluster policies for data engineering and data science workloads
- SQL Warehouse for BI analytics
- Shared interactive clusters with proper access controls
- Instance pools for faster cluster startup (optional)

See `compute-resources.tf` for Terraform implementation.

### Library Management
- Python packages (PyPI): pandas, scikit-learn, biopython, etc.
- BioPython and scientific computing libraries for data scientists
- Maven/JAR packages for Scala/Java dependencies
- Init scripts for system-level dependencies
- Requirements files stored in Unity Catalog volumes

See `libraries/README.md` for detailed library management guide.

## RBAC Matrix

| Role | Raw | Curated | Gold | Reference | ML | Compute |
|------|-----|---------|------|-----------|-----|---------|
| **Data Engineers** | Full | Full | Full | Full | Full | Shared clusters, CAN_USE policy |
| **Data Scientists** | None | Read | Read | Read | Full | ML clusters (single-user), CAN_USE ML policy |
| **BI Readers** | None | None | Read | Read | None | SQL Warehouse only |
| **Platform Admins** | Admin | Admin | Admin | Admin | Admin | CAN_MANAGE all compute |

## Prerequisites

Before running the SQL script:

1. **Azure AD/Entra ID Groups**: Create the required security groups:
   - `{domain}_data_engineers`
   - `{domain}_data_scientists`
   - `{domain}_bi_readers`
   - `data_platform_admins` (shared across domains)

2. **External Locations**: Configure Azure Data Lake storage credentials and external locations in Unity Catalog

3. **Storage Paths**: Update the `LOCATION` paths in the EXTERNAL VOLUME sections to match your Azure Data Lake setup

## Customization

### Adding Custom Schemas

To add a new schema for your domain:

```sql
CREATE SCHEMA IF NOT EXISTS {domain}_catalog.custom_schema;
ALTER SCHEMA {domain}_catalog.custom_schema OWNER TO `{domain}_data_engineers`;
GRANT USE SCHEMA ON SCHEMA {domain}_catalog.custom_schema TO `{domain}_data_engineers`;
```

### Adding Custom Roles

To add a new role group:

```sql
-- Grant catalog access
GRANT USE CATALOG ON CATALOG {domain}_catalog TO `{domain}_custom_role`;

-- Grant schema access
GRANT USE SCHEMA ON SCHEMA {domain}_catalog.gold TO `{domain}_custom_role`;
GRANT SELECT ON ALL TABLES IN SCHEMA {domain}_catalog.gold TO `{domain}_custom_role`;
```

## Best Practices

1. **Principle of Least Privilege**: Grant only the minimum permissions needed
2. **Future Grants**: Use `GRANT ... ON FUTURE TABLES` to automatically grant permissions to new tables
3. **Separation of Duties**: Keep different roles (engineers, scientists, analysts) with distinct access patterns
4. **Audit**: Use Unity Catalog audit logs to monitor access and changes
5. **Domain Isolation**: Each domain should have its own catalog and security groups
6. **Documentation**: Keep track of which groups have access to which resources

## Example: Setting up Finance Domain

```powershell
# Generate SQL script
python generate_domain_sql.py --domain finance --output finance-uc-setup.sql

# Review and update storage paths
code finance-uc-setup.sql

# Execute in Databricks SQL
# Option 1: Via Databricks SQL Editor
# Option 2: Via Databricks CLI
databricks sql execute -f finance-uc-setup.sql
```

## Troubleshooting

### Issue: "Catalog already exists"
- Use `DROP CATALOG IF EXISTS {domain}_catalog CASCADE;` before re-running (⚠️ This deletes all data!)

### Issue: "Group not found"
- Ensure Azure AD/Entra ID groups are created and synced to Databricks
- Check group names match exactly (case-sensitive)

### Issue: "External location not found"
- Create external locations first via Unity Catalog UI or API
- Ensure service principal has proper Azure RBAC on storage account

## References

- [Unity Catalog Documentation](https://docs.databricks.com/data-governance/unity-catalog/index.html)
- [Unity Catalog Best Practices](https://docs.databricks.com/data-governance/unity-catalog/best-practices.html)
- [Data Mesh on Azure Databricks](https://www.databricks.com/blog/2022/10/19/building-data-mesh-based-databricks-lakehouse-part-1.html)

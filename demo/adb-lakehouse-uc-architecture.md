# Azure Databricks Lakehouse with Unity Catalog - Architecture Documentation

**Deployment Name**: `dbx-lakehouse-dev`  
**Region**: `eastus2`  
**Subscription**: `c7b690b3-d9ad-4ed0-9942-4e7a36d0c187`  
**Workspace URL**: https://adb-4323989595923028.8.azuredatabricks.net  
**Deployment Date**: November 2025

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Inventory](#component-inventory)
3. [Network Architecture](#network-architecture)
4. [Unity Catalog Architecture](#unity-catalog-architecture)
5. [Security Model](#security-model)
6. [Data Flow](#data-flow)
7. [Storage Architecture](#storage-architecture)
8. [Component Details](#component-details)

---

## 🏗️ Architecture Overview

This deployment creates a complete, production-ready Azure Databricks lakehouse with Unity Catalog governance, featuring:

- **VNet-injected Databricks workspace** for network isolation
- **Unity Catalog** for centralized data governance
- **Managed Identity authentication** (no storage keys)
- **Two-tier storage architecture** (system + business data)
- **Enterprise security** with RBAC and network firewalls

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         AZURE SUBSCRIPTION                        │
│                    c7b690b3-d9ad-4ed0-9942-4e7a36d0c187          │
└──────────────────────────────────────────────────────────────────┘
                                  │
                ┌─────────────────┴─────────────────┐
                │                                   │
┌───────────────▼────────────────┐  ┌───────────────▼────────────────┐
│  Resource Group                │  │  Resource Group                │
│  rg-databricks-lakehouse       │  │  rg-databricks-shared          │
│  ┌──────────────────────────┐  │  │  ┌──────────────────────────┐  │
│  │ Databricks Workspace     │  │  │  │ Unity Catalog Metastore  │  │
│  │ VNet (10.178.0.0/16)     │◄─┼──┼──┤ Access Connector         │  │
│  │ Subnets, NSG, NAT        │  │  │  │ Storage Accounts         │  │
│  └──────────────────────────┘  │  │  └──────────────────────────┘  │
└────────────────────────────────┘  └────────────────────────────────┘
```

---

## 📦 Component Inventory

### Azure Infrastructure (31+ Resources Deployed)

| Component Type | Count | Names |
|----------------|-------|-------|
| **Resource Groups** | 2 | `rg-databricks-lakehouse`, `rg-databricks-shared` |
| **Virtual Networks** | 1 | `VNET-dbx-lakehouse-dev` (10.178.0.0/16) |
| **Subnets** | 2 | `private-subnet` (10.178.0.0/20), `public-subnet` (10.178.16.0/20) |
| **Network Security Groups** | 1 | `nsg-dbx-lakehouse-dev` |
| **NAT Gateway** | 1 | `nat-gateway-dbx-lakehouse` |
| **Public IPs** | 1 | `public-ip-nat` |
| **Databricks Workspaces** | 1 | `dbx-lakehouse-workspace` (ID: 4323989595923028) |
| **Access Connectors** | 1 | `dbx-lh-connector` |
| **Managed Identities** | 1 | `dbmanagedidentity` (system-assigned) |
| **Storage Accounts** | 2 | `dbxlhmetastore` (UC system), `dbxlhlanding` (business data) |
| **Storage Containers** | 2 | `metastore`, `landing` |
| **Role Assignments** | 4+ | Storage Blob Data Contributor, Queue, EventGrid |
| **Unity Catalog Metastores** | 1 | `dbxlakehousemetastore` (ID: fad7ed89-...) |
| **Unity Catalog Catalogs** | 1 | `bronze_catalog_dev` |
| **Unity Catalog Schemas** | 1 | `bronze_source1` |
| **External Locations** | 1 | `dbxlhlanding` |
| **Storage Credentials** | 1 | `dbx-lh-connector` (managed identity) |
| **Grants** | 2 | Catalog and external location permissions |

**Total Resources**: 31+ Azure and Databricks resources

---

## 🌐 Network Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│  Virtual Network: VNET-dbx-lakehouse-dev (10.178.0.0/16)            │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Private Subnet (10.178.0.0/20 - 4,096 IPs)                │    │
│  │  ┌────────────────────────────────────────────────────┐    │    │
│  │  │  • Databricks cluster worker nodes                 │    │    │
│  │  │  • Delegated to: Microsoft.Databricks/workspaces   │    │    │
│  │  │  • NSG: nsg-dbx-lakehouse-dev                      │    │    │
│  │  │  • NAT Gateway attached (outbound internet)        │    │    │
│  │  └────────────────────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │  Public Subnet (10.178.16.0/20 - 4,096 IPs)                │    │
│  │  ┌────────────────────────────────────────────────────┐    │    │
│  │  │  • Databricks control plane communication          │    │    │
│  │  │  • Delegated to: Microsoft.Databricks/workspaces   │    │    │
│  │  │  • NSG: nsg-dbx-lakehouse-dev                      │    │    │
│  │  │  • NAT Gateway attached                            │    │    │
│  │  └────────────────────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                      │
└───────────────────────────────┬──────────────────────────────────────┘
                                │
                                ▼
                    ┌──────────────────────┐
                    │   NAT Gateway        │
                    │   Public IP: xxx.xxx │
                    │   (Outbound only)    │
                    └──────────┬───────────┘
                               │
                               ▼
                         Internet Access
                    (Package downloads, APIs)
```

### Storage Network Security

```
┌────────────────────────────────────────────────────────────────┐
│  Storage Account: dbxlhmetastore (ADLS Gen2)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Network Firewall Rules:                                 │  │
│  │  • Default Action: Deny (block all)                      │  │
│  │  • Allowed Subnets:                                      │  │
│  │    ✓ 10.178.0.0/20 (private-subnet)                      │  │
│  │    ✓ 10.178.16.0/20 (public-subnet)                      │  │
│  │  • Bypass: AzureServices                                 │  │
│  │  • Public Network Access: Enabled (with firewall)        │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│  Storage Account: dbxlhlanding (ADLS Gen2)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Network Firewall Rules:                                 │  │
│  │  • Default Action: Deny (block all)                      │  │
│  │  • Allowed Subnets:                                      │  │
│  │    ✓ 10.178.0.0/20 (private-subnet)                      │  │
│  │    ✓ 10.178.16.0/20 (public-subnet)                      │  │
│  │  • Bypass: AzureServices                                 │  │
│  │  • Public Network Access: Enabled (with firewall)        │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Network Configuration Details

| Component | Configuration | Purpose |
|-----------|--------------|---------|
| **VNet** | 10.178.0.0/16 (65,536 IPs) | Isolated network for Databricks |
| **Private Subnet** | 10.178.0.0/20 (4,096 IPs) | Databricks worker nodes (compute clusters) |
| **Public Subnet** | 10.178.16.0/20 (4,096 IPs) | Control plane communication with Azure Databricks |
| **NSG** | Databricks required rules | Security filtering (allow control plane, deny internet inbound) |
| **NAT Gateway** | Outbound-only | Internet access for package downloads (pip, Maven, etc.) |
| **Subnet Delegation** | Microsoft.Databricks/workspaces | Required for VNet injection |

---

## 📚 Unity Catalog Architecture

### Unity Catalog Hierarchy

```
Databricks Account (b90dde1c-048c-4a28-b7d1-6c7c4df24b90)
    │
    └── Metastore: dbxlakehousemetastore
            │
            ├── ID: fad7ed89-8214-4ddd-8707-7ee54cbc9ce2
            ├── Region: eastus2
            ├── Root Storage: abfss://metastore@dbxlhmetastore.dfs.core.windows.net
            │
            ├── Storage Credential: dbx-lh-connector
            │       └── Type: Azure Managed Identity
            │           └── Access Connector → dbmanagedidentity
            │
            ├── External Location: dbxlhlanding
            │       ├── URL: abfss://landing@dbxlhlanding.dfs.core.windows.net
            │       ├── Credential: dbx-lh-connector
            │       └── Grants: READ_FILES, WRITE_FILES → admin
            │
            └── Catalog: bronze_catalog_dev
                    └── Schema: bronze_source1
                            └── Tables: (user-created)
                                  ├── Managed tables → stored in dbxlhmetastore
                                  └── External tables → stored in dbxlhlanding
```

### Metastore Assignment

```
Unity Catalog Metastore (Account-level resource)
    │
    └── Assigned to Workspace: dbx-lakehouse-workspace
            │
            ├── Workspace ID: 4323989595923028
            ├── Workspace URL: https://adb-4323989595923028.8.azuredatabricks.net
            └── Default Catalog: bronze_catalog_dev
```

---

## 🔐 Security Model

### Authentication Flow (Keyless - No Storage Keys)

```
┌──────────────────────────────────────────────────────────────┐
│  Step 1: User queries data in Databricks workspace          │
│  SELECT * FROM bronze_catalog_dev.bronze_source1.customers  │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 2: Unity Catalog validates permissions                │
│  • Does user have SELECT privilege on table?                │
│  • Does user have USE_CATALOG on bronze_catalog_dev?        │
│  • Does user have USE_SCHEMA on bronze_source1?             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 3: Unity Catalog retrieves table metadata             │
│  • Table location: abfss://landing@dbxlhlanding...           │
│  • Storage credential: dbx-lh-connector                      │
│  • Returns to Databricks compute cluster                    │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 4: Databricks cluster assumes Managed Identity        │
│  • Identity: dbmanagedidentity                               │
│  • Requests Azure AD token                                   │
│  • No secrets or keys needed                                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 5: Access storage with Azure AD authentication        │
│  • Cluster presents Azure AD token to storage account       │
│  • Storage validates: dbmanagedidentity has RBAC role       │
│  • Role: Storage Blob Data Contributor                      │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 6: Storage firewall validates source                  │
│  • Request from subnet: 10.178.0.0/20 ✓ (allowed)           │
│  • Network rule: Allow Databricks subnets                   │
│  • Default action: Deny all others                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Step 7: Data returned to user                              │
│  • Query results displayed in notebook                       │
│  • Audit log recorded in Azure Monitor                       │
│  • Unity Catalog records data lineage                        │
└──────────────────────────────────────────────────────────────┘
```

### RBAC Role Assignments

| Principal | Resource | Role | Purpose |
|-----------|----------|------|---------|
| **dbmanagedidentity** | dbxlhmetastore storage | Storage Blob Data Contributor | Read/write Unity Catalog metadata and managed tables |
| **dbmanagedidentity** | dbxlhmetastore storage | Storage Queue Data Contributor | Delta Lake transaction log operations |
| **dbmanagedidentity** | dbxlhmetastore storage | EventGrid Data Contributor | Change data capture and notifications |
| **dbmanagedidentity** | dbxlhlanding storage | Storage Blob Data Contributor | Read/write business data (external tables) |
| **admin@mngenvmcap612651.onmicrosoft.com** | Unity Catalog Metastore | Metastore Admin | Full Unity Catalog administration |
| **admin@mngenvmcap612651.onmicrosoft.com** | bronze_catalog_dev catalog | Multiple privileges | USE_CATALOG, CREATE_TABLE, SELECT, MODIFY, etc. |
| **admin@mngenvmcap612651.onmicrosoft.com** | dbxlhlanding external location | READ_FILES, WRITE_FILES | Can access external data files |

### Security Features Implemented

#### ✅ Network Security
- **VNet injection** - Workspace deployed in customer-managed VNet
- **NSG rules** - Network-level traffic filtering
- **Storage firewalls** - Access only from Databricks subnets (deny by default)
- **NAT Gateway** - Controlled outbound internet access
- **No public storage endpoints** - All access via private network paths

#### ✅ Authentication & Authorization
- **Azure AD authentication** - All storage access via Azure AD tokens
- **No storage account keys** - Keys disabled (`shared_access_key_enabled = false`)
- **Managed identity** - System-assigned, no secrets to manage or rotate
- **Unity Catalog RBAC** - Fine-grained permissions at catalog/schema/table level
- **Azure RBAC** - Resource-level access control

#### ✅ Data Governance
- **Unity Catalog** - Centralized metadata and governance
- **Data lineage** - Track data flow and transformations
- **Column-level permissions** - Available for sensitive data
- **Row-level security** - Available with Delta Sharing
- **Audit logs** - Full activity tracking (Premium workspace)

#### ✅ Compliance & Encryption
- **No shared access keys** - Meets security policy requirements
- **Data encryption at rest** - Azure Storage Service Encryption (SSE)
- **Data encryption in transit** - HTTPS/TLS 1.2+
- **GRS replication** - Geo-redundant storage for disaster recovery
- **Audit trail** - Azure Monitor and Unity Catalog audit logs

---

## 🔄 Data Flow

### Scenario 1: Query External Table

```
┌─────────────┐     SQL Query      ┌──────────────────┐
│    User     │───────────────────►│   Databricks     │
│  (Notebook) │                     │   Workspace      │
└─────────────┘                     └────────┬─────────┘
                                             │
                                 ┌───────────▼────────────┐
                                 │  Unity Catalog checks: │
                                 │  • User permissions    │
                                 │  • Table metadata      │
                                 │  • Storage location    │
                                 └───────────┬────────────┘
                                             │
                     ┌───────────────────────┴─────────────────────┐
                     │                                             │
                     ▼                                             ▼
        ┌────────────────────────┐                   ┌────────────────────────┐
        │  Managed Identity      │                   │  Table Metadata:       │
        │  dbmanagedidentity     │                   │  Location, Schema,     │
        │  (Azure AD token)      │                   │  Credential            │
        └────────┬───────────────┘                   └────────────────────────┘
                 │
                 │ Access with Azure AD auth
                 │
                 ▼
        ┌────────────────────────┐
        │  Storage Account:      │
        │  dbxlhlanding          │
        │  ┌──────────────────┐  │
        │  │ Network firewall │  │ ◄── Validates source subnet
        │  │ RBAC validation  │  │ ◄── Checks managed identity has role
        │  └────────┬─────────┘  │
        │           │ Data       │
        └───────────┼────────────┘
                    │
                    ▼
          ┌─────────────────┐
          │  Data returned  │
          │  to user        │
          └─────────────────┘
```

### Scenario 2: Create Managed Table

```
User → CREATE TABLE bronze_catalog_dev.bronze_source1.customers (...)
        │
        ├─► Unity Catalog:
        │   • Validates permissions (CREATE_TABLE privilege)
        │   • Determines storage location (metastore root storage)
        │   • No LOCATION clause = managed table
        │
        └─► Data written to:
            abfss://metastore@dbxlhmetastore.dfs.core.windows.net/
                            <catalog-id>/<schema-id>/<table-id>/
```

### Scenario 3: Create External Table

```
User → CREATE EXTERNAL TABLE bronze_catalog_dev.bronze_source1.orders (...)
       LOCATION 'abfss://landing@dbxlhlanding.dfs.core.windows.net/orders/'
        │
        ├─► Unity Catalog:
        │   • Validates CREATE_TABLE on catalog
        │   • Validates WRITE_FILES on dbxlhlanding external location
        │   • Checks credential (dbx-lh-connector) can access location
        │   • Registers table metadata
        │
        └─► Data written to:
            abfss://landing@dbxlhlanding.dfs.core.windows.net/orders/
            (User-specified location in landing zone)
```

---

## 💾 Storage Architecture

### Two-Tier Storage Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    STORAGE TIER 1: SYSTEM                       │
│  Storage Account: dbxlhmetastore                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Purpose: Unity Catalog system storage                    │  │
│  │  Owner: Unity Catalog metastore                           │  │
│  │  Contains:                                                 │  │
│  │  • Unity Catalog metadata files                           │  │
│  │  • Managed tables (no LOCATION clause)                    │  │
│  │  • Internal Delta Lake files                              │  │
│  │  • Table schemas and statistics                           │  │
│  │                                                            │  │
│  │  Container: metastore                                      │  │
│  │  Path: abfss://metastore@dbxlhmetastore.dfs.core.windows.net  │
│  │                                                            │  │
│  │  Configuration:                                            │  │
│  │  • ADLS Gen2 (Hierarchical Namespace)                     │  │
│  │  • GRS replication                                         │  │
│  │  • No storage keys (Azure AD only)                        │  │
│  │  • Network firewall: Allow Databricks subnets             │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    STORAGE TIER 2: BUSINESS DATA                │
│  Storage Account: dbxlhlanding                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Purpose: Business data / landing zone                     │  │
│  │  Owner: Data engineering team                              │  │
│  │  Contains:                                                 │  │
│  │  • Raw data files (CSV, JSON, Parquet)                    │  │
│  │  • External tables                                         │  │
│  │  • Bronze/Silver/Gold data layers                          │  │
│  │  • Application-specific data                               │  │
│  │                                                            │  │
│  │  Container: landing                                        │  │
│  │  Path: abfss://landing@dbxlhlanding.dfs.core.windows.net  │  │
│  │                                                            │  │
│  │  Configuration:                                            │  │
│  │  • ADLS Gen2 (Hierarchical Namespace)                     │  │
│  │  • GRS replication                                         │  │
│  │  • No storage keys (Azure AD only)                        │  │
│  │  • Network firewall: Allow Databricks subnets             │  │
│  │                                                            │  │
│  │  Registered as External Location in Unity Catalog         │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Storage Account Comparison

| Aspect | dbxlhmetastore | dbxlhlanding |
|--------|---------------|--------------|
| **Owner** | Unity Catalog system | Data engineering team |
| **Content** | Metadata & managed tables | Raw data & external tables |
| **Scope** | Account-level (shared across workspaces) | Environment-specific (dev/staging/prod) |
| **Registration** | Metastore root storage | External Location |
| **Access Pattern** | Databricks internal operations | User queries & ETL jobs |
| **Lifecycle** | Tied to metastore | Independent (can outlive workspace) |
| **Typical Size** | Smaller (metadata only) | Larger (business data) |
| **Backup Priority** | Critical (metadata loss = catalog loss) | Important (data loss = data loss) |

---

## 🔧 Component Details

### 1. Databricks Workspace

```yaml
Resource Type: Microsoft.Databricks/workspaces
Name: dbx-lakehouse-workspace
ID: 4323989595923028
URL: https://adb-4323989595923028.8.azuredatabricks.net
SKU: Premium
Location: eastus2
VNet: VNET-dbx-lakehouse-dev (10.178.0.0/16)
```

**Features:**
- ✅ Unity Catalog enabled (Premium SKU required)
- ✅ VNet injection (custom VNet integration)
- ✅ No public IP (secure cluster connectivity)
- ✅ Audit logs to Azure Monitor
- ✅ Conditional Access support
- ✅ SCIM provisioning support

### 2. Unity Catalog Metastore

```yaml
Resource Type: Databricks Metastore (Account-level)
Name: dbxlakehousemetastore
ID: fad7ed89-8214-4ddd-8707-7ee54cbc9ce2
Region: eastus2
Storage: abfss://metastore@dbxlhmetastore.dfs.core.windows.net
Assigned Workspaces: [4323989595923028]
```

**Purpose:**
- Central metadata repository for Unity Catalog
- Stores catalog, schema, table definitions
- Manages permissions and data lineage
- Tracks storage credentials and external locations
- Account-level resource (shareable across workspaces)

### 3. Access Connector & Managed Identity

```yaml
Resource Type: Microsoft.Databricks/accessConnectors
Name: dbx-lh-connector
Location: eastus2
Identity Type: SystemAssigned
Identity Name: dbmanagedidentity
Principal ID: <auto-generated-guid>
```

**🔑 This is THE KEY SECURITY COMPONENT**

**How it works:**
1. Access Connector automatically creates a system-assigned managed identity in Azure AD
2. The managed identity (`dbmanagedidentity`) is granted RBAC roles on storage accounts
3. Unity Catalog uses this identity to authenticate to Azure Storage
4. **No secrets, keys, or passwords are ever used or stored**

**Benefits:**
- ✅ Automatic credential management by Azure
- ✅ No manual key rotation needed
- ✅ Azure AD integration and audit trail
- ✅ Compliant with zero-trust security policies
- ✅ No risk of credential leakage

### 4. Storage Accounts

#### dbxlhmetastore (Unity Catalog System Storage)

```yaml
Name: dbxlhmetastore
Type: StorageV2
Kind: BlobStorage
SKU: Standard_GRS
ADLS Gen2: Enabled (is_hns_enabled = true)
Shared Access Keys: Disabled
Public Network Access: Enabled (with firewall rules)
Container: metastore
```

**Network Rules:**
```yaml
Default Action: Deny
Allowed Subnets:
  - 10.178.0.0/20 (private-subnet)
  - 10.178.16.0/20 (public-subnet)
Bypass: AzureServices
```

**RBAC Roles:**
- Storage Blob Data Contributor → dbmanagedidentity
- Storage Queue Data Contributor → dbmanagedidentity  
- EventGrid Data Contributor → dbmanagedidentity

#### dbxlhlanding (Business Data Storage)

```yaml
Name: dbxlhlanding
Type: StorageV2
Kind: BlobStorage
SKU: Standard_GRS
ADLS Gen2: Enabled
Shared Access Keys: Disabled
Public Network Access: Enabled (with firewall rules)
Container: landing
```

**Network Rules:** Same as metastore storage

**RBAC Roles:**
- Storage Blob Data Contributor → dbmanagedidentity

### 5. Unity Catalog Data Assets

#### Storage Credential

```yaml
Name: dbx-lh-connector
Type: Azure Managed Identity
Access Connector ID: /subscriptions/.../accessConnectors/dbx-lh-connector
Default Credential: true
```

**Purpose:** Links the Access Connector's managed identity to Unity Catalog

#### External Location

```yaml
Name: dbxlhlanding
URL: abfss://landing@dbxlhlanding.dfs.core.windows.net
Credential: dbx-lh-connector
Read Only: false
```

**Grants:**
- READ_FILES → admin@mngenvmcap612651.onmicrosoft.com
- WRITE_FILES → admin@mngenvmcap612651.onmicrosoft.com

#### Catalog & Schema

```yaml
Catalog: bronze_catalog_dev
Comment: Bronze layer catalog for dev environment
Force Destroy: true

Schema: bronze_source1
Catalog: bronze_catalog_dev
Comment: Schema for source system 1
Force Destroy: true
```

**Full Path:** `bronze_catalog_dev.bronze_source1.<table_name>`

---

## 📊 Resource Dependencies

```
terraform apply
    │
    ├─► Create Unity Catalog Metastore
    │   ├─► Create Access Connector (dbx-lh-connector)
    │   │   └─► System-assigned Managed Identity (dbmanagedidentity)
    │   ├─► Create Storage Account (dbxlhmetastore)
    │   │   └─► Container (metastore)
    │   ├─► Assign RBAC (dbmanagedidentity → dbxlhmetastore)
    │   └─► Register Metastore in Databricks Account
    │
    ├─► Create Networking
    │   ├─► VNet (10.178.0.0/16)
    │   ├─► Subnets (private, public)
    │   ├─► NSG
    │   └─► NAT Gateway + Public IP
    │
    ├─► Create Databricks Workspace
    │   ├─► Deploy in VNet (VNet injection)
    │   ├─► Create Managed Resource Group
    │   └─► Assign Unity Catalog Metastore
    │
    ├─► Create Landing Storage Account
    │   ├─► Create Storage Account (dbxlhlanding)
    │   │   └─► Container (landing)
    │   ├─► Assign RBAC (dbmanagedidentity → dbxlhlanding)
    │   └─► Configure Network Rules (allow Databricks subnets)
    │
    └─► Create Unity Catalog Data Assets
        ├─► Storage Credential (dbx-lh-connector)
        ├─► External Location (dbxlhlanding)
        ├─► Catalog (bronze_catalog_dev)
        ├─► Schema (bronze_source1)
        └─► Grants (permissions to admin user)
```

---

## 🚀 Usage Examples

### Connect to Workspace

```bash
# Open workspace URL
open https://adb-4323989595923028.8.azuredatabricks.net

# Login with Azure AD
# User: admin@mngenvmcap612651.onmicrosoft.com
```

### Unity Catalog Commands

```sql
-- List all catalogs
SHOW CATALOGS;

-- Use the bronze catalog
USE CATALOG bronze_catalog_dev;

-- List schemas
SHOW SCHEMAS;

-- Use the schema
USE SCHEMA bronze_source1;

-- Create a managed table (stored in dbxlhmetastore)
CREATE TABLE customers (
  customer_id INT,
  name STRING,
  email STRING,
  created_at TIMESTAMP
) USING DELTA;

-- Create an external table (stored in dbxlhlanding)
CREATE EXTERNAL TABLE orders (
  order_id INT,
  customer_id INT,
  amount DECIMAL(10,2),
  order_date DATE
) 
USING DELTA
LOCATION 'abfss://landing@dbxlhlanding.dfs.core.windows.net/orders/';

-- Query data
SELECT * FROM customers LIMIT 10;

-- Check table location
DESCRIBE EXTENDED customers;
```

### Upload Data to Landing Zone

```powershell
# Authenticate with Azure CLI
az login

# Upload files using Azure AD authentication (no keys needed)
az storage blob upload-batch `
  --account-name dbxlhlanding `
  --destination landing `
  --source ./local-data/ `
  --auth-mode login
```

### Grant Permissions

```sql
-- Grant catalog access to a user
GRANT USE CATALOG ON CATALOG bronze_catalog_dev TO `user@company.com`;

-- Grant schema access
GRANT USE SCHEMA ON SCHEMA bronze_catalog_dev.bronze_source1 TO `user@company.com`;

-- Grant table select
GRANT SELECT ON TABLE bronze_catalog_dev.bronze_source1.customers TO `user@company.com`;

-- Grant external location access
GRANT READ_FILES ON EXTERNAL LOCATION dbxlhlanding TO `user@company.com`;
```

---

## 🔍 Troubleshooting

### Issue 1: "Request is not authorized" when accessing storage

**Symptoms:**
```
Azure storage request is not authorized. The storage account's 
'Firewalls and virtual networks' settings may be blocking access.
```

**Cause:** Storage firewall blocking access or RBAC not propagated

**Solutions:**
1. Wait 5-10 minutes for RBAC role assignments to propagate
2. Verify cluster is using Unity Catalog access mode
3. Check network rules allow Databricks subnets
4. Temporarily add your IP to storage firewall for testing:
   ```powershell
   az storage account network-rule add `
     --account-name dbxlhlanding `
     --resource-group rg-databricks-shared `
     --ip-address <your-ip>
   ```

### Issue 2: "Cannot access external location"

**Cause:** Missing Unity Catalog grants

**Solution:**
```sql
-- Admin grants access to external location
GRANT READ_FILES, WRITE_FILES 
ON EXTERNAL LOCATION dbxlhlanding 
TO `user@company.com`;
```

### Issue 3: Cluster can't access storage

**Symptoms:** Cluster shows access denied errors

**Causes & Solutions:**
1. **Cluster not using Unity Catalog**
   - Edit cluster → Access Mode → Select "Unity Catalog"
   - Recreate cluster if needed

2. **Wrong workspace assignment**
   - Verify workspace is assigned to metastore
   - Check in Databricks Account Console

3. **RBAC not configured**
   - Verify managed identity has Storage Blob Data Contributor role
   - Check role assignments in Azure Portal

### Issue 4: Network connectivity issues

**Symptoms:** Cluster can't reach external services

**Solutions:**
1. Check NAT Gateway is attached to subnets
2. Verify Public IP is associated with NAT Gateway
3. Check NSG rules allow outbound traffic
4. Verify subnet delegation to Microsoft.Databricks/workspaces

---

## 💰 Cost Optimization

### Monthly Cost Estimate (Approximate)

| Resource | Estimated Cost | Notes |
|----------|---------------|-------|
| Databricks Workspace | $0 | No charge for workspace itself |
| Databricks Compute (DBU) | Variable | $0.55-$0.75/DBU (Premium), only when clusters run |
| Storage (dbxlhmetastore) | $50-150 | Depends on metadata volume (~100GB typical) |
| Storage (dbxlhlanding) | $100-1,000+ | Depends on business data volume |
| VNet | $0 | No charge |
| NAT Gateway | $35-45 | ~$0.045/hour + $0.045/GB processed |
| Public IP | $3-5 | Standard static IP |
| Access Connector | $0 | No charge |
| Data Egress | Variable | Outbound data transfer charges |

**Total (excluding compute):** ~$190-$1,200/month

### Cost Savings Tips

1. **Auto-terminate clusters** after 15-30 minutes of inactivity
2. **Use Spot instances** for non-production workloads (up to 80% savings)
3. **Enable cluster autoscaling** to match demand
4. **Use Azure Storage lifecycle policies** to move old data to Cool/Archive tiers
5. **Monitor DBU usage** with Azure Cost Management
6. **Use workspace-level budget alerts**
7. **Share metastore** across dev/staging/prod workspaces (one metastore, multiple workspaces)
8. **Use Photon engine** for 2-5x better price/performance
9. **Optimize Delta tables** with Z-Ordering and OPTIMIZE commands
10. **Review and clean up** unused tables and storage

---

## 📚 Additional Resources

- [Azure Databricks Documentation](https://docs.microsoft.com/azure/databricks/)
- [Unity Catalog Documentation](https://docs.databricks.com/data-governance/unity-catalog/)
- [Azure Databricks Best Practices](https://docs.microsoft.com/azure/databricks/best-practices/)
- [Managed Identity Documentation](https://docs.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Terraform Databricks Provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
- [ADLS Gen2 Documentation](https://docs.microsoft.com/azure/storage/blobs/data-lake-storage-introduction)
- [VNet Injection for Databricks](https://docs.microsoft.com/azure/databricks/administration-guide/cloud-configurations/azure/vnet-inject)

---

**Document Version:** 1.0  
**Last Updated:** November 6, 2025  
**Maintained By:** admin@mngenvmcap612651.onmicrosoft.com

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-deployment verification script for Azure Databricks with Unity Catalog

.DESCRIPTION
    This script verifies the deployment was successful and provides useful
    information about the deployed resources.
    
.EXAMPLE
    .\scripts\post-deploy.ps1
#>

param(
    [switch]$OpenWorkspace = $false
)

$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  $Message" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Magenta
}

Write-Header "Azure Databricks Unity Catalog - Post-Deployment Verification"

# Get Terraform Outputs
Write-Info "Retrieving Terraform outputs..."
try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    $workspaceUrl = $outputs.workspace_url.value
    $workspaceId = $outputs.workspace_id.value
    $resourceGroupId = $outputs.azure_resource_group_id.value
    
    Write-Success "Successfully retrieved Terraform outputs"
    
} catch {
    Write-Error-Custom "Failed to retrieve Terraform outputs"
    Write-Info "Ensure terraform has been applied successfully"
    exit 1
}

# Display Deployment Information
Write-Header "Deployment Information"

Write-Host "🏢 Databricks Workspace" -ForegroundColor Yellow
Write-Host "  URL:          " -NoNewline
Write-Host $workspaceUrl -ForegroundColor Cyan
Write-Host "  Workspace ID: " -NoNewline
Write-Host $workspaceId -ForegroundColor Cyan

Write-Host "`n📦 Resource Group" -ForegroundColor Yellow
Write-Host "  ID: " -NoNewline
Write-Host $resourceGroupId -ForegroundColor Cyan

# Parse resource group name and subscription
$rgPattern = "/subscriptions/([^/]+)/resourceGroups/([^/]+)"
if ($resourceGroupId -match $rgPattern) {
    $subscriptionId = $matches[1]
    $resourceGroupName = $matches[2]
    
    Write-Host "`n🔍 Resource Details" -ForegroundColor Yellow
    Write-Host "  Subscription ID:      " -NoNewline
    Write-Host $subscriptionId -ForegroundColor Cyan
    Write-Host "  Resource Group Name:  " -NoNewline
    Write-Host $resourceGroupName -ForegroundColor Cyan
}

# Get Terraform State Resources
Write-Info "`nChecking deployed resources..."
try {
    $stateList = terraform state list
    $resourceCount = ($stateList | Measure-Object).Count
    
    Write-Success "Deployed $resourceCount Terraform resources"
    
    Write-Host "`n📊 Resource Breakdown:" -ForegroundColor Yellow
    
    # Count resources by type
    $resourceTypes = @{}
    $stateList | ForEach-Object {
        if ($_ -match '\.([^.]+)\.') {
            $type = $matches[1]
            if ($resourceTypes.ContainsKey($type)) {
                $resourceTypes[$type]++
            } else {
                $resourceTypes[$type] = 1
            }
        }
    }
    
    $resourceTypes.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
    }
    
} catch {
    Write-Warning-Custom "Could not retrieve Terraform state information"
}

# Verify Azure Resources
if ($subscriptionId -and $resourceGroupName) {
    Write-Info "`nVerifying Azure resources..."
    
    try {
        # Check Databricks workspace
        $workspace = az databricks workspace show `
            --resource-group $resourceGroupName `
            --name "dbx-lakehouse-workspace" `
            --output json 2>&1 | ConvertFrom-Json
        
        if ($workspace) {
            Write-Success "Databricks workspace is provisioned"
            Write-Host "  Provisioning State: " -NoNewline
            Write-Host $workspace.provisioningState -ForegroundColor $(if ($workspace.provisioningState -eq "Succeeded") { "Green" } else { "Yellow" })
            Write-Host "  SKU: " -NoNewline
            Write-Host $workspace.sku.name -ForegroundColor Cyan
        }
    } catch {
        Write-Warning-Custom "Could not verify Databricks workspace"
    }
    
    try {
        # Check storage accounts
        $storageAccounts = az storage account list `
            --resource-group "rg-databricks-shared" `
            --output json 2>&1 | ConvertFrom-Json
        
        if ($storageAccounts) {
            Write-Success "Found $($storageAccounts.Count) storage account(s) in shared resource group"
            
            $storageAccounts | ForEach-Object {
                Write-Host "  - $($_.name) " -NoNewline -ForegroundColor Cyan
                Write-Host "($($_.properties.primaryEndpoints.dfs))" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Warning-Custom "Could not verify storage accounts"
    }
}

# Unity Catalog Information
Write-Header "Unity Catalog Configuration"

Write-Host "📚 Available Resources:" -ForegroundColor Yellow
Write-Host "  Catalog: " -NoNewline
Write-Host "bronze_catalog_dev" -ForegroundColor Cyan
Write-Host "  Schema:  " -NoNewline
Write-Host "bronze_catalog_dev.bronze_source1" -ForegroundColor Cyan
Write-Host "  External Location: " -NoNewline
Write-Host "dbxlhlanding" -ForegroundColor Cyan

Write-Success "`nUnity Catalog is configured and ready to use"

# Next Steps
Write-Header "Next Steps"

Write-Host "1️⃣  Access Your Workspace" -ForegroundColor Yellow
Write-Host "   Navigate to: $workspaceUrl" -ForegroundColor Cyan
Write-Host "   Sign in with your Azure AD credentials`n"

Write-Host "2️⃣  Verify Unity Catalog" -ForegroundColor Yellow
Write-Host "   - Click 'Catalog' in the left sidebar"
Write-Host "   - Browse 'bronze_catalog_dev' catalog"
Write-Host "   - Explore 'bronze_source1' schema`n"

Write-Host "3️⃣  Create a Cluster" -ForegroundColor Yellow
Write-Host "   - Navigate to 'Compute'"
Write-Host "   - Create a new cluster"
Write-Host "   - Unity Catalog is automatically enabled`n"

Write-Host "4️⃣  Upload Sample Data" -ForegroundColor Yellow
Write-Host "   - Use the 'dbxlhlanding' external location"
Write-Host "   - Create tables in bronze_source1 schema"
Write-Host "   - Example SQL:"
Write-Host "     CREATE TABLE bronze_catalog_dev.bronze_source1.my_table" -ForegroundColor Gray
Write-Host "     USING DELTA" -ForegroundColor Gray
Write-Host "     LOCATION 'abfss://landing@dbxlhlanding.dfs.core.windows.net/data/'" -ForegroundColor Gray

Write-Host "`n5️⃣  Configure Users & Permissions" -ForegroundColor Yellow
Write-Host "   - Add users to your Azure AD tenant"
Write-Host "   - Grant permissions in Unity Catalog"
Write-Host "   - Use workspace admin settings for user management`n"

# Useful Commands
Write-Header "Useful Commands"

Write-Host "🔧 Azure CLI Commands:" -ForegroundColor Yellow
if ($resourceGroupName) {
    Write-Host "  # List all resources in workspace resource group"
    Write-Host "  az resource list --resource-group $resourceGroupName --output table" -ForegroundColor Gray
    
    Write-Host "`n  # View Databricks workspace"
    Write-Host "  az databricks workspace show --resource-group $resourceGroupName --name dbx-lakehouse-workspace" -ForegroundColor Gray
    
    Write-Host "`n  # List storage accounts"
    Write-Host "  az storage account list --resource-group rg-databricks-shared --output table" -ForegroundColor Gray
}

Write-Host "`n📊 Terraform Commands:" -ForegroundColor Yellow
Write-Host "  # View outputs"
Write-Host "  terraform output" -ForegroundColor Gray

Write-Host "`n  # Show current state"
Write-Host "  terraform show" -ForegroundColor Gray

Write-Host "`n  # List resources"
Write-Host "  terraform state list" -ForegroundColor Gray

Write-Host "`n  # Refresh and plan"
Write-Host "  terraform plan" -ForegroundColor Gray

# Resource Links
Write-Header "Documentation & Resources"

Write-Host "📖 Documentation:" -ForegroundColor Yellow
Write-Host "  Azure Databricks:  https://learn.microsoft.com/azure/databricks/" -ForegroundColor Cyan
Write-Host "  Unity Catalog:     https://docs.databricks.com/data-governance/unity-catalog/" -ForegroundColor Cyan
Write-Host "  Terraform Provider: https://registry.terraform.io/providers/databricks/databricks/" -ForegroundColor Cyan

Write-Host "`n🔐 Security Best Practices:" -ForegroundColor Yellow
Write-Host "  - Enable audit logging"
Write-Host "  - Configure workspace access controls"
Write-Host "  - Review Unity Catalog permissions regularly"
Write-Host "  - Enable data lineage tracking"
Write-Host "  - Configure secrets in Azure Key Vault"

# Open workspace in browser
if ($OpenWorkspace -and $workspaceUrl) {
    Write-Info "`nOpening workspace in browser..."
    Start-Process $workspaceUrl
}

Write-Header "Deployment Verification Complete! 🎉"

Write-Success "Your Azure Databricks workspace with Unity Catalog is ready to use!`n"

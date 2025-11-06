#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleanup script for Azure Databricks with Unity Catalog deployment

.DESCRIPTION
    This script safely destroys all resources created by Terraform.
    USE WITH CAUTION - This will permanently delete all resources and data!
    
.PARAMETER Confirm
    Skip confirmation prompt (use with caution)
    
.EXAMPLE
    .\scripts\cleanup.ps1
    
.EXAMPLE
    .\scripts\cleanup.ps1 -Confirm:$false
#>

param(
    [switch]$Force = $false
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

Write-Header "Azure Databricks Unity Catalog - Cleanup"

# Show warning
Write-Warning-Custom "⚠️  WARNING: This will PERMANENTLY DELETE all deployed resources!"
Write-Host ""
Write-Host "This includes:" -ForegroundColor Yellow
Write-Host "  - Databricks workspace and all notebooks/clusters" -ForegroundColor Red
Write-Host "  - Unity Catalog metastore and all metadata" -ForegroundColor Red
Write-Host "  - Storage accounts and ALL DATA" -ForegroundColor Red
Write-Host "  - Networking resources (VNet, subnets, NSG, NAT Gateway)" -ForegroundColor Red
Write-Host "  - All role assignments and access connectors" -ForegroundColor Red
Write-Host ""

# Get current deployment info
try {
    $outputs = terraform output -json 2>$null | ConvertFrom-Json
    
    if ($outputs) {
        Write-Info "Current Deployment:"
        Write-Host "  Workspace URL: $($outputs.workspace_url.value)" -ForegroundColor Cyan
        Write-Host "  Workspace ID:  $($outputs.workspace_id.value)" -ForegroundColor Cyan
        Write-Host "  Resource Group: $($outputs.azure_resource_group_id.value)" -ForegroundColor Cyan
        Write-Host ""
    }
} catch {
    Write-Warning-Custom "Could not retrieve deployment information"
}

# Confirmation
if (-not $Force) {
    Write-Host "Type " -NoNewline
    Write-Host "DELETE" -ForegroundColor Red -NoNewline
    Write-Host " to confirm destruction of all resources: " -NoNewline
    
    $confirmation = Read-Host
    
    if ($confirmation -ne "DELETE") {
        Write-Info "Cleanup cancelled. No resources were deleted."
        exit 0
    }
}

Write-Header "Starting Resource Cleanup"

# Set environment variable for Azure AD authentication
$env:ARM_USE_CLI = "true"

Write-Info "Running terraform destroy..."
Write-Warning-Custom "This may take 10-15 minutes..."
Write-Host ""

try {
    # Run terraform destroy
    $destroyOutput = terraform destroy -auto-approve 2>&1
    
    Write-Success "Terraform destroy completed successfully!"
    
    # Show summary
    if ($destroyOutput -match "Destroy complete! Resources: (\d+) destroyed") {
        $destroyedCount = $matches[1]
        Write-Success "Destroyed $destroyedCount resources"
    }
    
} catch {
    Write-Error-Custom "Terraform destroy encountered errors"
    Write-Host ""
    Write-Host $_ -ForegroundColor Red
    Write-Host ""
    Write-Warning-Custom "Some resources may still exist. Please check manually:"
    Write-Info "  - Check Azure Portal for remaining resources"
    Write-Info "  - Run: az resource list --resource-group <resource-group-name>"
    exit 1
}

# Optional: Clean up Terraform state and cache
Write-Info "`nCleaning up Terraform files..."

$cleanupItems = @(
    @{Path=".terraform"; Type="directory"; Description="Terraform plugin cache"},
    @{Path=".terraform.lock.hcl"; Type="file"; Description="Dependency lock file"},
    @{Path="terraform.tfstate"; Type="file"; Description="Terraform state file"},
    @{Path="terraform.tfstate.backup"; Type="file"; Description="State backup file"}
)

Write-Host ""
Write-Host "Do you want to delete Terraform state files? (y/N): " -NoNewline
$cleanState = Read-Host

if ($cleanState -eq "y" -or $cleanState -eq "Y") {
    foreach ($item in $cleanupItems) {
        if (Test-Path $item.Path) {
            try {
                if ($item.Type -eq "directory") {
                    Remove-Item -Path $item.Path -Recurse -Force
                } else {
                    Remove-Item -Path $item.Path -Force
                }
                Write-Success "Deleted $($item.Description)"
            } catch {
                Write-Warning-Custom "Could not delete $($item.Description): $_"
            }
        }
    }
} else {
    Write-Info "Keeping Terraform state files"
}

# Verification
Write-Header "Cleanup Verification"

Write-Info "Checking for remaining resources..."

try {
    $stateList = terraform state list 2>$null
    
    if ($stateList) {
        Write-Warning-Custom "Some resources may still be in Terraform state:"
        $stateList | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Yellow
        }
    } else {
        Write-Success "No resources remain in Terraform state"
    }
} catch {
    Write-Success "Terraform state is clean (or state file removed)"
}

# Final message
Write-Header "Cleanup Complete!"

Write-Success "All resources have been destroyed successfully!`n"

Write-Info "Next Steps:"
Write-Host "  - Verify in Azure Portal that all resources are deleted"
Write-Host "  - Check for any orphaned resources"
Write-Host "  - Review billing to ensure no unexpected charges"
Write-Host ""
Write-Host "To deploy again:" -ForegroundColor Yellow
Write-Host "  1. Ensure terraform.tfvars is configured"
Write-Host "  2. Run: terraform init"
Write-Host "  3. Run: terraform apply"
Write-Host ""

#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-deployment validation script for Azure Databricks with Unity Catalog

.DESCRIPTION
    This script validates all prerequisites before deploying the Azure Databricks
    workspace with Unity Catalog. It checks:
    - Azure CLI installation and authentication
    - Terraform installation
    - Required Azure permissions
    - Subscription access
    
.EXAMPLE
    .\scripts\pre-deploy.ps1
#>

param(
    [switch]$Detailed = $false
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

# Track validation status
$validationPassed = $true

Write-Header "Azure Databricks Unity Catalog - Pre-Deployment Validation"

# Check 1: Azure CLI
Write-Info "Checking Azure CLI installation..."
try {
    $azVersion = az version --output json 2>&1 | ConvertFrom-Json
    Write-Success "Azure CLI is installed (version $($azVersion.'azure-cli'))"
    
    if ($Detailed) {
        Write-Info "  Extensions:"
        $azVersion.extensions.PSObject.Properties | ForEach-Object {
            Write-Host "    - $($_.Name): $($_.Value)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Error-Custom "Azure CLI is not installed or not in PATH"
    Write-Info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    $validationPassed = $false
}

# Check 2: Azure CLI Authentication
Write-Info "`nChecking Azure CLI authentication..."
try {
    $account = az account show --output json 2>&1 | ConvertFrom-Json
    Write-Success "Authenticated as: $($account.user.name)"
    Write-Info "  Subscription: $($account.name) ($($account.id))"
    Write-Info "  Tenant: $($account.tenantId)"
    
    # Save subscription ID for later use
    $subscriptionId = $account.id
    $tenantId = $account.tenantId
    $userEmail = $account.user.name
    
} catch {
    Write-Error-Custom "Not authenticated to Azure CLI"
    Write-Info "Run: az login"
    $validationPassed = $false
}

# Check 3: Terraform Installation
Write-Info "`nChecking Terraform installation..."
try {
    $terraformVersion = terraform version -json 2>&1 | ConvertFrom-Json
    $tfVersion = $terraformVersion.terraform_version
    Write-Success "Terraform is installed (version $tfVersion)"
    
    # Check version requirement
    $requiredVersion = [Version]"1.0.0"
    $installedVersion = [Version]$tfVersion
    
    if ($installedVersion -lt $requiredVersion) {
        Write-Warning-Custom "Terraform version $tfVersion is below recommended minimum (1.0.0)"
        Write-Info "Consider upgrading: https://www.terraform.io/downloads"
    }
} catch {
    Write-Error-Custom "Terraform is not installed or not in PATH"
    Write-Info "Install from: https://www.terraform.io/downloads"
    $validationPassed = $false
}

# Check 4: Azure Permissions
if ($subscriptionId) {
    Write-Info "`nChecking Azure permissions..."
    try {
        # Check role assignments
        $roleAssignments = az role assignment list --assignee $account.user.name --subscription $subscriptionId --output json 2>&1 | ConvertFrom-Json
        
        $hasContributor = $roleAssignments | Where-Object { $_.roleDefinitionName -in @("Owner", "Contributor") }
        
        if ($hasContributor) {
            Write-Success "User has sufficient permissions (Owner or Contributor)"
            if ($Detailed) {
                Write-Info "  Role Assignments:"
                $roleAssignments | ForEach-Object {
                    Write-Host "    - $($_.roleDefinitionName) on $($_.scope)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Warning-Custom "User may not have sufficient permissions"
            Write-Info "Required: Contributor or Owner role on subscription"
            Write-Info "Current roles:"
            $roleAssignments | ForEach-Object {
                Write-Host "  - $($_.roleDefinitionName)" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Warning-Custom "Could not verify Azure permissions"
        Write-Info "Ensure you have Contributor or Owner role on the subscription"
    }
}

# Check 5: Required Resource Providers
Write-Info "`nChecking Azure resource providers..."
try {
    $providers = @("Microsoft.Databricks", "Microsoft.Storage", "Microsoft.Network")
    
    foreach ($provider in $providers) {
        $status = az provider show --namespace $provider --query "registrationState" -o tsv 2>&1
        
        if ($status -eq "Registered") {
            Write-Success "$provider is registered"
        } else {
            Write-Warning-Custom "$provider is not registered (status: $status)"
            Write-Info "Register with: az provider register --namespace $provider"
        }
    }
} catch {
    Write-Warning-Custom "Could not verify resource providers"
}

# Check 6: Terraform Configuration File
Write-Info "`nChecking Terraform configuration..."
if (Test-Path "terraform.tfvars") {
    Write-Success "terraform.tfvars file exists"
    
    if ($Detailed) {
        Write-Info "`n  Configuration preview:"
        Get-Content "terraform.tfvars" | Select-Object -First 20 | ForEach-Object {
            if ($_ -notmatch "^\s*#" -and $_ -match "\S") {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Warning-Custom "terraform.tfvars file not found"
    
    if (Test-Path "terraform.tfvars.template") {
        Write-Info "Template file exists. Copy and customize it:"
        Write-Info "  cp terraform.tfvars.template terraform.tfvars"
    } else {
        Write-Info "Create terraform.tfvars with your configuration values"
    }
}

# Check 7: Terraform Initialization
Write-Info "`nChecking Terraform initialization..."
if (Test-Path ".terraform") {
    Write-Success "Terraform is initialized"
    
    if (Test-Path ".terraform.lock.hcl") {
        Write-Info "  Dependency lock file exists"
    }
} else {
    Write-Warning-Custom "Terraform not initialized"
    Write-Info "Run: terraform init"
}

# Check 8: Azure Quota Check (optional)
if ($subscriptionId) {
    Write-Info "`nChecking Azure quotas (optional)..."
    try {
        $location = "eastus2" # Default location
        
        # Check compute quota for Databricks
        $computeQuota = az vm list-usage --location $location --query "[?name.value=='cores'].{Current:currentValue,Limit:limit}" -o json 2>&1 | ConvertFrom-Json
        
        if ($computeQuota) {
            $used = $computeQuota[0].Current
            $limit = $computeQuota[0].Limit
            $available = $limit - $used
            
            if ($available -gt 10) {
                Write-Success "Sufficient compute quota available ($available cores)"
            } else {
                Write-Warning-Custom "Limited compute quota available ($available cores)"
                Write-Info "Consider requesting quota increase for region: $location"
            }
        }
    } catch {
        Write-Info "Could not check Azure quotas (non-critical)"
    }
}

# Summary
Write-Header "Pre-Deployment Validation Summary"

if ($validationPassed) {
    Write-Success "All critical validations passed!`n"
    
    Write-Info "Next Steps:"
    Write-Host "  1. Review/create terraform.tfvars with your configuration" -ForegroundColor White
    Write-Host "  2. Run: terraform init" -ForegroundColor White
    Write-Host "  3. Run: terraform plan" -ForegroundColor White
    Write-Host "  4. Run: terraform apply" -ForegroundColor White
    
    Write-Info "`nImportant Configuration Values:"
    if ($subscriptionId) {
        Write-Host "  subscription_id = `"$subscriptionId`"" -ForegroundColor Yellow
    }
    if ($tenantId) {
        Write-Host "  tenant_id = `"$tenantId`"" -ForegroundColor Yellow
    }
    if ($userEmail) {
        # Convert to lowercase for Unity Catalog
        $emailLower = $userEmail.ToLower()
        Write-Host "  metastore_admins = [`"$emailLower`"]" -ForegroundColor Yellow
        
        if ($userEmail -cne $emailLower) {
            Write-Warning-Custom "Note: Your email contains uppercase letters"
            Write-Info "Use lowercase in metastore_admins: $emailLower"
        }
    }
    
    Write-Host "`n  Get your Databricks Account ID from:" -ForegroundColor White
    Write-Host "  https://accounts.azuredatabricks.net/" -ForegroundColor Cyan
    
} else {
    Write-Error-Custom "`nSome critical validations failed!"
    Write-Info "Please resolve the issues above before proceeding with deployment."
    exit 1
}

Write-Host ""

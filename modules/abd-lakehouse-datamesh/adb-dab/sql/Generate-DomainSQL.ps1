#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate domain-specific Unity Catalog SQL scripts.

.DESCRIPTION
    This script reads the template SQL file (uc-roles-grants.sql) and replaces
    the domain name, allowing you to quickly create catalog setup scripts for
    different business domains.

.PARAMETER Domain
    The domain name (e.g., 'finance', 'sales', 'hr')

.PARAMETER Template
    Path to the template SQL file (default: uc-roles-grants.sql)

.PARAMETER Output
    Output file path (default: {domain}-uc-setup.sql)

.EXAMPLE
    .\Generate-DomainSQL.ps1 -Domain finance
    Generates finance-uc-setup.sql

.EXAMPLE
    .\Generate-DomainSQL.ps1 -Domain sales -Output custom-sales.sql
    Generates custom-sales.sql for sales domain
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Domain name (e.g., finance, sales, hr)")]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string]$Template = "uc-roles-grants.sql",
    
    [Parameter(Mandatory=$false)]
    [string]$Output = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Determine output file name if not specified
if ([string]::IsNullOrEmpty($Output)) {
    $Output = "$($Domain.ToLower())-uc-setup.sql"
}

try {
    # Check if template file exists
    if (-not (Test-Path $Template)) {
        throw "❌ Template file not found: $Template"
    }
    
    Write-Host "🔄 Generating SQL script for domain: $Domain" -ForegroundColor Cyan
    
    # Read template content
    $content = Get-Content $Template -Raw
    
    # Replace domain names (case-sensitive)
    $domainLower = $Domain.ToLower()
    $domainUpper = $Domain.ToUpper()
    $domainTitle = (Get-Culture).TextInfo.ToTitleCase($Domain.ToLower())
    
    $content = $content -replace '\bamrnet\b', $domainLower
    $content = $content -replace '\bAMRNet\b', $domainUpper
    $content = $content -replace '\bAmrnet\b', $domainTitle
    
    # Update configuration comment
    $content = $content -replace '--   Domain: amrnet', "--   Domain: $domainLower"
    
    # Save to output file
    $content | Set-Content $Output -Encoding UTF8
    
    Write-Host "✅ Successfully generated SQL script: $Output" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Review the generated SQL file: $Output"
    Write-Host "  2. Update storage account paths in EXTERNAL VOLUME sections"
    Write-Host "  3. Ensure Azure AD groups exist:"
    Write-Host "     - $($domainLower)_data_engineers"
    Write-Host "     - $($domainLower)_data_scientists"
    Write-Host "     - $($domainLower)_bi_readers"
    Write-Host "  4. Execute the script in Databricks SQL"
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

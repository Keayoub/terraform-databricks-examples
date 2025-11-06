#!/bin/bash
###############################################################################
# Pre-deployment validation script for Azure Databricks with Unity Catalog
#
# This script validates all prerequisites before deploying the Azure Databricks
# workspace with Unity Catalog.
###############################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Output functions
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

header() {
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}\n"
}

# Track validation status
VALIDATION_PASSED=true

header "Azure Databricks Unity Catalog - Pre-Deployment Validation"

# Check 1: Azure CLI
info "Checking Azure CLI installation..."
if command -v az &> /dev/null; then
    AZ_VERSION=$(az version --output json | jq -r '."azure-cli"')
    success "Azure CLI is installed (version $AZ_VERSION)"
else
    error "Azure CLI is not installed or not in PATH"
    info "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    VALIDATION_PASSED=false
fi

# Check 2: Azure CLI Authentication
info "\nChecking Azure CLI authentication..."
if az account show &> /dev/null; then
    ACCOUNT_INFO=$(az account show --output json)
    USER_NAME=$(echo $ACCOUNT_INFO | jq -r '.user.name')
    SUBSCRIPTION_NAME=$(echo $ACCOUNT_INFO | jq -r '.name')
    SUBSCRIPTION_ID=$(echo $ACCOUNT_INFO | jq -r '.id')
    TENANT_ID=$(echo $ACCOUNT_INFO | jq -r '.tenantId')
    
    success "Authenticated as: $USER_NAME"
    info "  Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
    info "  Tenant: $TENANT_ID"
else
    error "Not authenticated to Azure CLI"
    info "Run: az login"
    VALIDATION_PASSED=false
fi

# Check 3: Terraform Installation
info "\nChecking Terraform installation..."
if command -v terraform &> /dev/null; then
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
    success "Terraform is installed (version $TF_VERSION)"
    
    # Check version requirement
    REQUIRED_VERSION="1.0.0"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TF_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        success "Terraform version meets requirements (>= 1.0.0)"
    else
        warning "Terraform version $TF_VERSION is below recommended minimum (1.0.0)"
        info "Consider upgrading: https://www.terraform.io/downloads"
    fi
else
    error "Terraform is not installed or not in PATH"
    info "Install from: https://www.terraform.io/downloads"
    VALIDATION_PASSED=false
fi

# Check 4: jq Installation (for JSON parsing)
info "\nChecking jq installation..."
if command -v jq &> /dev/null; then
    success "jq is installed"
else
    warning "jq is not installed (optional but recommended)"
    info "Install: sudo apt-get install jq (Ubuntu) or brew install jq (Mac)"
fi

# Check 5: Azure Permissions
if [ ! -z "$SUBSCRIPTION_ID" ]; then
    info "\nChecking Azure permissions..."
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee $USER_NAME --subscription $SUBSCRIPTION_ID --output json 2>/dev/null || echo "[]")
    
    if echo $ROLE_ASSIGNMENTS | jq -e '.[] | select(.roleDefinitionName == "Owner" or .roleDefinitionName == "Contributor")' &> /dev/null; then
        success "User has sufficient permissions (Owner or Contributor)"
    else
        warning "User may not have sufficient permissions"
        info "Required: Contributor or Owner role on subscription"
    fi
fi

# Check 6: Required Resource Providers
info "\nChecking Azure resource providers..."
PROVIDERS=("Microsoft.Databricks" "Microsoft.Storage" "Microsoft.Network")

for PROVIDER in "${PROVIDERS[@]}"; do
    STATUS=$(az provider show --namespace $PROVIDER --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    
    if [ "$STATUS" = "Registered" ]; then
        success "$PROVIDER is registered"
    else
        warning "$PROVIDER is not registered (status: $STATUS)"
        info "Register with: az provider register --namespace $PROVIDER"
    fi
done

# Check 7: Terraform Configuration File
info "\nChecking Terraform configuration..."
if [ -f "terraform.tfvars" ]; then
    success "terraform.tfvars file exists"
else
    warning "terraform.tfvars file not found"
    
    if [ -f "terraform.tfvars.template" ]; then
        info "Template file exists. Copy and customize it:"
        info "  cp terraform.tfvars.template terraform.tfvars"
    else
        info "Create terraform.tfvars with your configuration values"
    fi
fi

# Check 8: Terraform Initialization
info "\nChecking Terraform initialization..."
if [ -d ".terraform" ]; then
    success "Terraform is initialized"
    
    if [ -f ".terraform.lock.hcl" ]; then
        info "  Dependency lock file exists"
    fi
else
    warning "Terraform not initialized"
    info "Run: terraform init"
fi

# Summary
header "Pre-Deployment Validation Summary"

if [ "$VALIDATION_PASSED" = true ]; then
    success "All critical validations passed!\n"
    
    info "Next Steps:"
    echo "  1. Review/create terraform.tfvars with your configuration"
    echo "  2. Run: terraform init"
    echo "  3. Run: terraform plan"
    echo "  4. Run: terraform apply"
    
    info "\nImportant Configuration Values:"
    if [ ! -z "$SUBSCRIPTION_ID" ]; then
        echo -e "  ${YELLOW}subscription_id = \"$SUBSCRIPTION_ID\"${NC}"
    fi
    if [ ! -z "$TENANT_ID" ]; then
        echo -e "  ${YELLOW}tenant_id = \"$TENANT_ID\"${NC}"
    fi
    if [ ! -z "$USER_NAME" ]; then
        # Convert to lowercase for Unity Catalog
        EMAIL_LOWER=$(echo "$USER_NAME" | tr '[:upper:]' '[:lower:]')
        echo -e "  ${YELLOW}metastore_admins = [\"$EMAIL_LOWER\"]${NC}"
        
        if [ "$USER_NAME" != "$EMAIL_LOWER" ]; then
            warning "Note: Your email contains uppercase letters"
            info "Use lowercase in metastore_admins: $EMAIL_LOWER"
        fi
    fi
    
    echo ""
    echo "  Get your Databricks Account ID from:"
    echo -e "  ${CYAN}https://accounts.azuredatabricks.net/${NC}"
    
else
    error "\nSome critical validations failed!"
    info "Please resolve the issues above before proceeding with deployment."
    exit 1
fi

echo ""

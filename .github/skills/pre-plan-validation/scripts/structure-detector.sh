#!/usr/bin/env bash
# structure-detector.sh: Analyze Terraform repository layout and conventions
# Usage: ./structure-detector.sh [path]
# Example: ./structure-detector.sh . or ./structure-detector.sh modules/rds

set -euo pipefail

TARGET_PATH="${1:-.}"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Terraform Repository Structure Analyzer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "Analyzing: $TARGET_PATH"
echo ""

# Check if path exists
if [[ ! -d "$TARGET_PATH" ]]; then
  echo -e "${RED}Error: Path does not exist: $TARGET_PATH${NC}"
  exit 1
fi

# Navigate to path
cd "$TARGET_PATH" || exit 1

# ============================================================================
# Detect Project Root and Structure
# ============================================================================

echo -e "${BLUE}📂 Repository Structure${NC}"
echo ""

# Find project root (look up for .git or terraform root markers)
PROJECT_ROOT="."
for i in {0..5}; do
  if [[ -f "$PROJECT_ROOT/.git/config" ]] || [[ -f "$PROJECT_ROOT/Makefile" ]]; then
    break
  fi
  PROJECT_ROOT="../$PROJECT_ROOT"
done

# Check for standard Terraform directories
HAS_MODULES=false
HAS_ENVS=false
HAS_SHARED=false
HAS_MAKEFILE=false

if [[ -d "$PROJECT_ROOT/modules" ]]; then
  HAS_MODULES=true
fi

if [[ -d "$PROJECT_ROOT/envs" ]]; then
  HAS_ENVS=true
fi

if [[ -d "$PROJECT_ROOT/shared" ]]; then
  HAS_SHARED=true
fi

if [[ -f "$PROJECT_ROOT/Makefile" ]]; then
  HAS_MAKEFILE=true
fi

# Display directory tree
echo "Directory structure:"
if command -v tree &> /dev/null; then
  tree -L 2 -I 'terraform*|.terraform' "$PROJECT_ROOT" 2>/dev/null | head -30
else
  find "$PROJECT_ROOT" -maxdepth 2 -type d -not -path '*/\.*' -not -path '*/.terraform*' | sort | sed 's|[^/]*/| |g'
fi

echo ""
echo -e "${BLUE}✓ Detected Directories:${NC}"
[[ "$HAS_MODULES" == true ]] && echo -e "  ${GREEN}✓${NC} modules/ (reusable infrastructure)" || echo -e "  ${RED}✗${NC} modules/ (missing)"
[[ "$HAS_ENVS" == true ]] && echo -e "  ${GREEN}✓${NC} envs/ (environment-specific)" || echo -e "  ${RED}✗${NC} envs/ (missing)"
[[ "$HAS_SHARED" == true ]] && echo -e "  ${GREEN}✓${NC} shared/ (cross-environment)" || echo -e "  ${YELLOW}~${NC} shared/ (optional)"
[[ "$HAS_MAKEFILE" == true ]] && echo -e "  ${GREEN}✓${NC} Makefile (build orchestration)" || echo -e "  ${YELLOW}~${NC} Makefile (optional)"

echo ""

# ============================================================================
# Identify Current Location and Recommend Placement
# ============================================================================

echo -e "${BLUE}📍 Current Location Analysis${NC}"
echo ""

RELATIVE_PATH=$(pwd | sed "s|.*$PROJECT_ROOT||" | sed 's|^/||')
if [[ -z "$RELATIVE_PATH" ]]; then
  RELATIVE_PATH="."
fi

echo "Current directory: $RELATIVE_PATH"

# Determine if we're in modules, envs, or root
if [[ "$RELATIVE_PATH" =~ ^modules/ ]]; then
  echo -e "  ${GREEN}✓ Location: Inside modules/ (reusable component)${NC}"
  MODULE_NAME=$(echo "$RELATIVE_PATH" | cut -d'/' -f2)
  echo "  Module name: $MODULE_NAME"
  echo "  Scope: Reusable across all environments"
  
elif [[ "$RELATIVE_PATH" =~ ^envs/ ]]; then
  echo -e "  ${GREEN}✓ Location: Inside envs/ (environment-specific)${NC}"
  ENV_NAME=$(echo "$RELATIVE_PATH" | cut -d'/' -f2)
  echo "  Environment: $ENV_NAME"
  echo "  Scope: This environment only"
  
elif [[ "$RELATIVE_PATH" =~ ^shared/ ]]; then
  echo -e "  ${GREEN}✓ Location: Inside shared/ (cross-environment)${NC}"
  echo "  Scope: Shared across environments"
  
elif [[ "$RELATIVE_PATH" == "." ]]; then
  echo -e "  ${YELLOW}~ Location: Project root${NC}"
  echo "  Scope: Provider configuration and top-level resources (rare)"
  
else
  echo -e "  ${YELLOW}⚠ Location: Non-standard ($(basename "$RELATIVE_PATH"))${NC}"
  if [[ "$HAS_MODULES" == true ]] && [[ "$HAS_ENVS" == true ]]; then
    echo "  Recommendation: Move to modules/ or envs/ for consistency"
  fi
fi

echo ""

# ============================================================================
# Check for Terraform Files
# ============================================================================

echo -e "${BLUE}🔍 Terraform Files${NC}"
echo ""

TF_FILES=$(find . -maxdepth 1 -name "*.tf" -type f | wc -l)
echo "Terraform files in current directory: $TF_FILES"

if [[ -f "terraform.tf" ]]; then
  echo -e "  ${GREEN}✓ terraform.tf${NC} (provider configuration)"
else
  echo -e "  ${RED}✗ terraform.tf${NC} (should include required_version and required_providers)"
fi

if [[ -f "main.tf" ]]; then
  echo -e "  ${GREEN}✓ main.tf${NC} (resource definitions)"
fi

if [[ -f "variables.tf" ]]; then
  echo -e "  ${GREEN}✓ variables.tf${NC} (input variables)"
fi

if [[ -f "outputs.tf" ]]; then
  echo -e "  ${GREEN}✓ outputs.tf${NC} (output values)"
fi

if [[ -f "locals.tf" ]]; then
  echo -e "  ${GREEN}✓ locals.tf${NC} (local values)"
fi

if [[ -f ".terraform.lock.hcl" ]]; then
  echo -e "  ${GREEN}✓ .terraform.lock.hcl${NC} (version lock file)"
else
  echo -e "  ${YELLOW}~ .terraform.lock.hcl${NC} (generate with terraform init)"
fi

echo ""

# ============================================================================
# Check Version Constraints
# ============================================================================

echo -e "${BLUE}⚙️  Version Constraints${NC}"
echo ""

if grep -q "required_version" *.tf 2>/dev/null; then
  VERSION_CONSTRAINT=$(grep "required_version" *.tf 2>/dev/null | grep -oP '=\s*"\K[^"]+')
  echo -e "  ${GREEN}✓ Terraform version${NC}: $VERSION_CONSTRAINT"
else
  echo -e "  ${RED}✗ Missing: required_version in terraform.tf${NC}"
fi

if grep -q "required_providers" *.tf 2>/dev/null; then
  echo -e "  ${GREEN}✓ Required providers specified${NC}"
  if grep -q '"hashicorp/aws"' *.tf 2>/dev/null; then
    AWS_VERSION=$(grep -A 2 '"hashicorp/aws"' *.tf 2>/dev/null | grep "version" | grep -oP '"[^"]+"' | tail -1)
    echo -e "    AWS provider ${AWS_VERSION}"
  fi
else
  echo -e "  ${RED}✗ Missing: required_providers in terraform.tf${NC}"
fi

echo ""

# ============================================================================
# Naming Convention Analysis
# ============================================================================

echo -e "${BLUE}📝 Naming Conventions${NC}"
echo ""

# Check variable naming style
VARS=$(grep "^variable \"" variables.tf 2>/dev/null | grep -oP '"[^"]+' | tr -d '"' | head -5)
if [[ -n "$VARS" ]]; then
  echo "Sample variables:"
  echo "$VARS" | while read -r var; do
    if [[ "$var" =~ ^[a-z_]+$ ]]; then
      echo -e "  ${GREEN}✓${NC} $var (snake_case)"
    else
      echo -e "  ${YELLOW}~${NC} $var (check naming)"
    fi
  done
else
  echo "  No variables defined yet"
fi

echo ""

# ============================================================================
# Module Dependencies
# ============================================================================

echo -e "${BLUE}🔗 Module Dependencies${NC}"
echo ""

if grep -q "source = " *.tf 2>/dev/null; then
  echo "This module depends on:"
  grep -h "source = " *.tf 2>/dev/null | grep -v "^#" | cut -d'"' -f2 | while read -r source; do
    echo "  → $source"
  done
else
  echo "  No module dependencies (standalone)"
fi

echo ""

# ============================================================================
# Recommendations
# ============================================================================

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 Recommendations${NC}"
echo ""

RECOMMENDATIONS=0

if ! grep -q "required_version" *.tf 2>/dev/null; then
  echo "1. Add required_version to terraform.tf:"
  echo '   required_version = ">= 1.5, < 2.0"'
  RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if ! grep -q "required_providers" *.tf 2>/dev/null; then
  echo "$((RECOMMENDATIONS + 1)). Add required_providers to terraform.tf with pinned AWS version"
  RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [[ "$TF_FILES" -eq 0 ]]; then
  echo "$((RECOMMENDATIONS + 1)). Create terraform.tf, variables.tf, outputs.tf, main.tf"
  RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [[ ! -f "variables.tf" ]]; then
  echo "$((RECOMMENDATIONS + 1)). Create variables.tf with input variable definitions"
  RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [[ ! -f "outputs.tf" ]]; then
  echo "$((RECOMMENDATIONS + 1)). Create outputs.tf with output value definitions"
  RECOMMENDATIONS=$((RECOMMENDATIONS + 1))
fi

if [[ "$RECOMMENDATIONS" -eq 0 ]]; then
  echo -e "${GREEN}✓ Repository structure looks good!${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo ""
read -p "✓ Presiona Enter para cerrar..." _

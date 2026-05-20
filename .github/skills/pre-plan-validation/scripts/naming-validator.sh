#!/usr/bin/env bash
# naming-validator.sh: Check naming consistency with project conventions
# Usage: ./naming-validator.sh [path]
# Example: ./naming-validator.sh modules/rds

set -euo pipefail

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH" || exit 1

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Terraform Naming Convention Validator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

ISSUES=0

# ============================================================================
# Check Variable Naming
# ============================================================================

echo -e "${BLUE}📝 Variable Names${NC}"
echo ""

if [[ ! -f "variables.tf" ]]; then
  echo "  (no variables.tf found)"
else
  # Extract variable names
  VARS=$(grep "^variable \"" variables.tf | grep -oP '"[^"]+' | tr -d '"')
  
  if [[ -z "$VARS" ]]; then
    echo "  (no variables defined)"
  else
    echo "Checking variable naming convention (should be snake_case):"
    echo "$VARS" | while read -r var; do
      if [[ "$var" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo -e "  ${GREEN}✓${NC} $var"
      else
        echo -e "  ${RED}✗${NC} $var (should be snake_case)"
        ISSUES=$((ISSUES + 1))
      fi
    done
  fi
fi

echo ""

# ============================================================================
# Check Output Naming
# ============================================================================

echo -e "${BLUE}📤 Output Names${NC}"
echo ""

if [[ ! -f "outputs.tf" ]]; then
  echo "  (no outputs.tf found)"
else
  OUTPUTS=$(grep "^output \"" outputs.tf | grep -oP '"[^"]+' | tr -d '"')
  
  if [[ -z "$OUTPUTS" ]]; then
    echo "  (no outputs defined)"
  else
    echo "Checking output naming convention (should be snake_case):"
    echo "$OUTPUTS" | while read -r output; do
      if [[ "$output" =~ ^[a-z][a-z0-9_]*$ ]]; then
        echo -e "  ${GREEN}✓${NC} $output"
      else
        echo -e "  ${RED}✗${NC} $output (should be snake_case)"
        ISSUES=$((ISSUES + 1))
      fi
    done
  fi
fi

echo ""

# ============================================================================
# Check for module_name usage in resource naming
# ============================================================================

echo -e "${BLUE}🏷️  Resource Naming Patterns${NC}"
echo ""

if grep -q "var.module_name" *.tf 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Uses var.module_name for consistent naming"
else
  # Check if there's a module_name variable
  if grep -q 'variable.*"module_name"' variables.tf 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC} module_name variable defined but not used in resources"
  else
    echo -e "${YELLOW}~${NC} Consider adding module_name variable for consistent resource naming"
  fi
fi

echo ""

# ============================================================================
# Check Tag Consistency
# ============================================================================

echo -e "${BLUE}🏷️  Tagging Convention${NC}"
echo ""

if grep -q "default_tags" provider* 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Provider uses default_tags"
elif grep -q "merge(var.default_tags" *.tf 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Resources use merge(...var.default_tags)"
else
  echo -e "${YELLOW}~${NC} Consider using default_tags or var.default_tags for consistency"
fi

echo ""

# ============================================================================
# Check for local variable usage (DRY principle)
# ============================================================================

echo -e "${BLUE}🎯 DRY Principle (locals)${NC}"
echo ""

if [[ -f "locals.tf" ]]; then
  LOCALS=$(grep "^  [a-z_]* =" locals.tf | wc -l)
  echo -e "${GREEN}✓${NC} locals.tf found ($LOCALS local values)"
else
  # Check if locals are inline
  if grep -q "^locals {" *.tf 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Inline locals detected"
  else
    echo -e "${YELLOW}~${NC} Consider using locals for repeated values"
  fi
fi

echo ""

# ============================================================================
# Check Variable/Output Descriptions
# ============================================================================

echo -e "${BLUE}📚 Documentation${NC}"
echo ""

if [[ -f "variables.tf" ]]; then
  VARS_WITH_DESC=$(grep -c 'description =' variables.tf 2>/dev/null || echo "0")
  TOTAL_VARS=$(grep -c '^variable "' variables.tf 2>/dev/null || echo "0")
  
  if [[ "$TOTAL_VARS" -gt 0 ]]; then
    if [[ "$VARS_WITH_DESC" -eq "$TOTAL_VARS" ]]; then
      echo -e "${GREEN}✓${NC} All variables have descriptions"
    else
      echo -e "${YELLOW}⚠${NC} $VARS_WITH_DESC/$TOTAL_VARS variables documented"
    fi
  fi
fi

if [[ -f "outputs.tf" ]]; then
  OUTS_WITH_DESC=$(grep -c 'description =' outputs.tf 2>/dev/null || echo "0")
  TOTAL_OUTS=$(grep -c '^output "' outputs.tf 2>/dev/null || echo "0")
  
  if [[ "$TOTAL_OUTS" -gt 0 ]]; then
    if [[ "$OUTS_WITH_DESC" -eq "$TOTAL_OUTS" ]]; then
      echo -e "${GREEN}✓${NC} All outputs have descriptions"
    else
      echo -e "${YELLOW}⚠${NC} $OUTS_WITH_DESC/$TOTAL_OUTS outputs documented"
    fi
  fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
if [[ "$ISSUES" -eq 0 ]]; then
  echo -e "${GREEN}✓ Naming conventions look good!${NC}"
else
  echo -e "${YELLOW}⚠ Found $ISSUES naming issues - review above${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

echo ""
read -p "✓ Presiona Enter para cerrar..." _

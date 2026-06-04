#!/usr/bin/env bash
# detect-hardcodes.sh: Scan for hardcoded values that should be parameterized
# Usage: ./detect-hardcodes.sh [path]
# Example: ./detect-hardcodes.sh modules/rds

set -euo pipefail

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH" || exit 1

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Hardcoded Values Scanner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

CRITICAL=0
HIGH=0
MEDIUM=0

# ============================================================================
# 1. Detect Hardcoded Passwords
# ============================================================================

echo -e "${BLUE}🔐 Password Literals${NC}"
echo ""

if grep -rn 'password\s*=\s*"[^"]*"' --include="*.tf" 2>/dev/null | grep -v 'sensitive'; then
  echo -e "${RED}[CRITICAL]${NC} Found hardcoded password"
  CRITICAL=$((CRITICAL + 1))
else
  echo -e "${GREEN}✓${NC} No hardcoded passwords detected"
fi

echo ""

# ============================================================================
# 2. Detect Hardcoded API Keys/Secrets
# ============================================================================

echo -e "${BLUE}🔑 API Keys / Secrets${NC}"
echo ""

if grep -rn 'api_key\|api-key\|apikey\|secret\s*=' --include="*.tf" | grep -P '\s*=\s*"[A-Za-z0-9_\-]{20,}"'; then
  echo -e "${RED}[CRITICAL]${NC} Found potential hardcoded API key or secret"
  CRITICAL=$((CRITICAL + 1))
else
  echo -e "${GREEN}✓${NC} No obvious hardcoded API keys detected"
fi

echo ""

# ============================================================================
# 3. Detect AWS Credentials Pattern
# ============================================================================

echo -e "${BLUE}👤 AWS Credentials${NC}"
echo ""

if grep -rn 'AKIA[0-9A-Z]\{16\}' --include="*.tf"; then
  echo -e "${RED}[CRITICAL]${NC} Found AWS access key pattern"
  CRITICAL=$((CRITICAL + 1))
else
  echo -e "${GREEN}✓${NC} No AWS access key patterns detected"
fi

echo ""

# ============================================================================
# 4. Detect Hardcoded Account IDs
# ============================================================================

echo -e "${BLUE}🏢 Account IDs${NC}"
echo ""

# Look for 12-digit numbers in ARNs or role references
ACCOUNT_IDS=$(grep -rn 'arn:aws.*:[0-9]\{12\}' --include="*.tf" | grep -v 'data.aws_caller_identity' | wc -l)

if [[ "$ACCOUNT_IDS" -gt 0 ]]; then
  echo -e "${YELLOW}[HIGH]${NC} Found hardcoded AWS account IDs (should use data.aws_caller_identity.current.account_id)"
  grep -rn 'arn:aws.*:[0-9]\{12\}' --include="*.tf" | grep -v 'data.aws_caller_identity' | head -5
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} No hardcoded account IDs detected"
fi

echo ""

# ============================================================================
# 5. Detect Hardcoded Regions
# ============================================================================

echo -e "${BLUE}🌍 Regions${NC}"
echo ""

REGIONS=$(grep -n 'availability_zone\s*=\s*"[a-z]' *.tf 2>/dev/null | grep -v 'data.aws')
if [[ -n "$REGIONS" ]]; then
  echo -e "${YELLOW}[MEDIUM]${NC} Found hardcoded availability zones (should use data source)"
  echo "$REGIONS"
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} No hardcoded availability zones"
fi

REGIONS=$(grep -n 'region\s*=\s*"' *.tf 2>/dev/null | grep -v 'var.aws_region' | grep -v 'provider')
if [[ -n "$REGIONS" ]]; then
  echo -e "${YELLOW}[MEDIUM]${NC} Found hardcoded region (should use var.aws_region)"
  echo "$REGIONS"
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} No hardcoded regions in resources"
fi

echo ""

# ============================================================================
# 6. Detect Hardcoded Environment Names
# ============================================================================

echo -e "${BLUE}🏷️  Environment-Specific Names${NC}"
echo ""

ENV_PATTERN='(production|prod|staging|stage|development|dev|test)\b'

# Check in identifiers and names
ENV_NAMES=$(grep -rn 'identifier\s*=\|name\s*=\|\.main\|\.prod\|\.stage' --include="*.tf" | \
  grep -E "$ENV_PATTERN" | \
  grep -v "var\." | \
  grep -v "#" | wc -l)

if [[ "$ENV_NAMES" -gt 0 ]]; then
  echo -e "${YELLOW}[MEDIUM]${NC} Found hardcoded environment names in resource IDs (should use var.environment)"
  grep -rn 'identifier\s*=\|name\s*=' --include="*.tf" | \
    grep -E "$ENV_PATTERN" | \
    grep -v "var\." | \
    grep -v "#" | head -5
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} No obvious hardcoded environment names"
fi

echo ""

# ============================================================================
# 7. Detect Hardcoded Bucket/Instance Names
# ============================================================================

echo -e "${BLUE}🪣 Storage/Instance Names${NC}"
echo ""

# Common patterns: bucket names, RDS identifiers with version/date
TIME_PATTERNS=$(grep -rn 'bucket.*=\|identifier.*=\|name.*=' --include="*.tf" | \
  grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}|timestamp()' | wc -l)

if [[ "$TIME_PATTERNS" -gt 0 ]]; then
  echo -e "${YELLOW}[HIGH]${NC} Found timestamp-based identifiers (causes replacement on every apply)"
  grep -rn 'timestamp()' --include="*.tf" | head -5
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} No timestamp-based identifiers"
fi

echo ""

# ============================================================================
# 8. Detect Environment Variables Used Directly
# ============================================================================

echo -e "${BLUE}🔧 Environment Variable References${NC}"
echo ""

if grep -rn 'var(TF_VAR' --include="*.tf"; then
  echo -e "${YELLOW}[MEDIUM]${NC} Found direct environment variable references (use input variables instead)"
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} No problematic environment variable references"
fi

echo ""

# ============================================================================
# 9. Summary
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "Hardcode Detection Summary:"
echo -e "  ${RED}CRITICAL: $CRITICAL${NC}"
echo -e "  ${YELLOW}HIGH:     $HIGH${NC}"
echo -e "  ${YELLOW}MEDIUM:   $MEDIUM${NC}"

if [[ "$CRITICAL" -gt 0 ]]; then
  echo -e "\n${RED}❌ Critical issues found - fix before planning${NC}"
elif [[ "$HIGH" -gt 0 ]] || [[ "$MEDIUM" -gt 0 ]]; then
  echo -e "\n${YELLOW}⚠️  Found issues - review above${NC}"
else
  echo -e "\n${GREEN}✓ No hardcoded values detected${NC}"
fi

echo ""
read -p "✓ Presiona Enter para cerrar..." _

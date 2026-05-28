#!/usr/bin/env bash
# replacement-detector.sh: Identify terraform plan forced replacements and destructive changes
# Usage: ./replacement-detector.sh [path]
# Example: ./replacement-detector.sh envs/prod

set -euo pipefail

TARGET_PATH="${1:-.}"
cd "$TARGET_PATH" || exit 1

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Replacement Risk Detector${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

CRITICAL=0
HIGH=0
MEDIUM=0

# ============================================================================
# 1. Detect Changes to Resource Identifiers (Force New)
# ============================================================================

echo -e "${BLUE}🔄 Resource Identifier Changes${NC}"
echo ""

# Look for identifier, name, bucket changes in destructive resources
DESTRUCTIVE_RESOURCES=('aws_db_instance' 'aws_elasticache_cluster' 'aws_rds_cluster' 'aws_s3_bucket')

for RESOURCE in "${DESTRUCTIVE_RESOURCES[@]}"; do
  IDENTIFIER_CHANGES=$(grep -rn "resource \"$RESOURCE\"" --include="*.tf" | wc -l)
  if [[ "$IDENTIFIER_CHANGES" -gt 0 ]]; then
    # Check if identifier is using timestamp or local value
    if grep -A20 "resource \"$RESOURCE\"" --include="*.tf" | grep -q 'identifier\s*=\|name\s*='; then
      echo -e "${MAGENTA}→${NC} Checking $RESOURCE identifier mutations..."
      
      if grep -A20 "resource \"$RESOURCE\"" --include="*.tf" | grep -q 'timestamp()\|format(".*%s"'; then
        echo -e "  ${RED}[CRITICAL]${NC} $RESOURCE identifier uses timestamp/function (recreates on every apply!)"
        CRITICAL=$((CRITICAL + 1))
      fi
    fi
  fi
done

echo -e "${GREEN}✓${NC} Identifier analysis complete"
echo ""

# ============================================================================
# 2. Detect Changes to immutable attributes
# ============================================================================

echo -e "${BLUE}⚡ Immutable Attribute Changes${NC}"
echo ""

# RDS engine version changes (within patch ok, major/minor requires replacement)
if grep -rn 'engine_version\s*=' --include="*.tf" | grep -v 'var.' | grep -q '.'; then
  echo -e "${YELLOW}[HIGH]${NC} Found hardcoded engine_version (upgrade requires replacement)"
  grep -rn 'engine_version\s*=' --include="*.tf" | grep -v 'var.' | head -3
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} engine_version parameterized or not present"
fi

# Engine type changes
if grep -rn 'engine\s*=\s*"' --include="*.tf" | grep -v 'var.' | grep -q '.'; then
  echo -e "${YELLOW}[HIGH]${NC} Found hardcoded engine (changing engine type requires replacement)"
  grep -rn 'engine\s*=\s*"' --include="*.tf" | grep -v 'var.' | head -3
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} engine parameterized or not present"
fi

echo ""

# ============================================================================
# 3. Detect VPC/AZ/Subnet Changes (potential downtime)
# ============================================================================

echo -e "${BLUE}🌐 Network Configuration Changes${NC}"
echo ""

# Availability zone pinning
AZ_HARDCODED=$(grep -rn 'availability_zone\s*=' --include="*.tf" | grep -v 'data.aws' | grep -v 'var.' | wc -l)
if [[ "$AZ_HARDCODED" -gt 0 ]]; then
  echo -e "${YELLOW}[MEDIUM]${NC} Found hardcoded availability_zone (changing causes replacement + downtime)"
  grep -rn 'availability_zone\s*=' --include="*.tf" | grep -v 'data.aws' | grep -v 'var.'
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} availability_zone not hardcoded"
fi

# VPC ID changes
VPC_HARDCODED=$(grep -rn 'vpc_id\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws' | wc -l)
if [[ "$VPC_HARDCODED" -gt 0 ]]; then
  echo -e "${RED}[CRITICAL]${NC} Found hardcoded vpc_id (changing causes resource replacement + downtime)"
  grep -rn 'vpc_id\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws'
  CRITICAL=$((CRITICAL + 1))
else
  echo -e "${GREEN}✓${NC} vpc_id properly parameterized"
fi

# Subnet ID changes
SUBNET_HARDCODED=$(grep -rn 'subnet_id\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws' | wc -l)
if [[ "$SUBNET_HARDCODED" -gt 0 ]]; then
  echo -e "${YELLOW}[HIGH]${NC} Found hardcoded subnet_id (changing causes resource replacement)"
  grep -rn 'subnet_id\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws' | head -3
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} subnet_id properly parameterized"
fi

echo ""

# ============================================================================
# 4. Detect CIDR Block Changes (would cause replacement)
# ============================================================================

echo -e "${BLUE}📊 CIDR Block Configuration${NC}"
echo ""

CIDR_HARDCODED=$(grep -rn 'cidr_block\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws' | wc -l)
if [[ "$CIDR_HARDCODED" -gt 0 ]]; then
  echo -e "${YELLOW}[HIGH]${NC} Found hardcoded CIDR blocks (changing causes replacement)"
  grep -rn 'cidr_block\s*=' --include="*.tf" | grep -v 'var.' | grep -v 'data.aws' | head -3
  HIGH=$((HIGH + 1))
else
  echo -e "${GREEN}✓${NC} CIDR blocks properly parameterized"
fi

echo ""

# ============================================================================
# 5. Detect Database Parameter Changes
# ============================================================================

echo -e "${BLUE}🗄️  Database Parameter Group Changes${NC}"
echo ""

if grep -rn 'parameter_group_name\s*=' --include="*.tf" | grep -q '.'; then
  echo -e "${MAGENTA}→${NC} Found parameter_group_name references"
  
  if grep -rn 'create_before_destroy\|lifecycle' --include="*.tf" | grep -q 'parameter_group'; then
    echo -e "${GREEN}✓${NC} Has lifecycle rule for safe parameter group updates"
  else
    echo -e "${YELLOW}[MEDIUM]${NC} Parameter group changes may cause downtime (consider lifecycle { create_before_destroy })"
    MEDIUM=$((MEDIUM + 1))
  fi
else
  echo -e "${GREEN}✓${NC} No database parameter group configuration found"
fi

echo ""

# ============================================================================
# 6. Check for lifecycle { create_before_destroy }
# ============================================================================

echo -e "${BLUE}🔁 Lifecycle Protection${NC}"
echo ""

RESOURCES_WITH_LIFECYCLE=$(grep -rn 'lifecycle {\|create_before_destroy' --include="*.tf" | grep 'create_before_destroy' | wc -l)
TOTAL_RESOURCES=$(grep -rn '^resource ' --include="*.tf" | wc -l)

if [[ "$RESOURCES_WITH_LIFECYCLE" -lt "$((TOTAL_RESOURCES / 4))" ]]; then
  echo -e "${YELLOW}[MEDIUM]${NC} Recommended: Add create_before_destroy to critical resources (RDS, ElastiCache, Load Balancers)"
  echo "  Found: $RESOURCES_WITH_LIFECYCLE with create_before_destroy policy of $TOTAL_RESOURCES resources"
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} Good coverage of create_before_destroy lifecycle rules"
fi

echo ""

# ============================================================================
# 7. Check for prevent_destroy on production resources
# ============================================================================

echo -e "${BLUE}🛡️  Destruction Prevention${NC}"
echo ""

PREVENT_DESTROY=$(grep -rn 'prevent_destroy\s*=\s*true' --include="*.tf" | wc -l)
if [[ "$PREVENT_DESTROY" -eq 0 ]] && grep -rn 'resource "aws_db_instance"\|resource "aws_s3_bucket"\|resource "aws_rds_cluster"' --include="*.tf" | grep -q '.'; then
  echo -e "${YELLOW}[MEDIUM]${NC} Consider adding prevent_destroy = true to production databases and data stores"
  MEDIUM=$((MEDIUM + 1))
else
  echo -e "${GREEN}✓${NC} Destruction prevention configured appropriately"
fi

echo ""

# ============================================================================
# 8. Suggest terraform plan analysis
# ============================================================================

echo -e "${BLUE}📋 Next Steps${NC}"
echo ""
echo "To see actual replacement plans, run:"
echo -e "  ${MAGENTA}terraform plan -out=tfplan${NC}"
echo ""
echo "Then check for '-> must replace' in the output for:"
echo "  • Resource identifier changes"
echo "  • Engine/version upgrades"
echo "  • VPC/subnet reassignments"
echo "  • CIDR block changes"
echo ""

# ============================================================================
# 9. Summary
# ============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "Replacement Risk Summary:"
echo -e "  ${RED}CRITICAL: $CRITICAL${NC}"
echo -e "  ${YELLOW}HIGH:     $HIGH${NC}"
echo -e "  ${YELLOW}MEDIUM:   $MEDIUM${NC}"

if [[ "$CRITICAL" -gt 0 ]]; then
  echo -e "\n${RED}❌ Critical risks found - must address before planning${NC}"
elif [[ "$HIGH" -gt 0 ]]; then
  echo -e "\n${YELLOW}⚠️  High-risk issues found - review terraform plan carefully${NC}"
elif [[ "$MEDIUM" -gt 0 ]]; then
  echo -e "\n${YELLOW}💡 Medium-risk issues found - verify with terraform plan${NC}"
else
  echo -e "\n${GREEN}✓ No replacement risks detected${NC}"
fi

echo ""
read -p "✓ Presiona Enter para cerrar..." _

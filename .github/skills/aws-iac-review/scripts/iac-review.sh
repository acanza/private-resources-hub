#!/usr/bin/env bash
# iac-review.sh: Automated security scan of AWS IaC changes
# Checks for: IAM over-permissioning, public exposure, encryption, logging, risky replacements
# Usage: ./iac-review.sh <path-to-scan> [--strict]
# Example: ./iac-review.sh modules/rds

set -euo pipefail

SCAN_PATH="${1:-.}"
STRICT_MODE="${2:-}"

# Color output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counters
CRITICAL=0
HIGH=0
MEDIUM=0
INFO=0

# Helper function for colored output
log_critical() {
  echo -e "${RED}[CRITICAL]${NC} $1"
  CRITICAL=$((CRITICAL + 1))
}

log_high() {
  echo -e "${RED}[HIGH]${NC} $1"
  HIGH=$((HIGH + 1))
}

log_medium() {
  echo -e "${YELLOW}[MEDIUM]${NC} $1"
  MEDIUM=$((MEDIUM + 1))
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
  INFO=$((INFO + 1))
}

# Header
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}AWS IaC Security Review${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "Scanning: $SCAN_PATH"
echo ""

# Check if path exists
if [[ ! -e "$SCAN_PATH" ]]; then
  echo -e "${RED}Error: Path does not exist: $SCAN_PATH${NC}"
  exit 1
fi

# ============================================================================
# 1. IAM OVER-PERMISSIONING CHECKS
# ============================================================================
echo -e "${BLUE}--- IAM Over-Permissioning Checks ---${NC}"

# Check for wildcard actions in IAM policies
if grep -r 'Action.*"\*"\|Action.*:\*' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_critical "IAM policy with wildcard Action (*)"
fi

# Check for wildcard resources in IAM policies
if grep -r 'Resource.*"\*"\|Resource\s*=\s*\[.*"\*"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_critical "IAM policy with Resource = \"*\" (overly broad)"
fi

# Check for Principal: * in resource policies
if grep -r 'Principal.*"\*"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_critical "Resource policy with Principal: * (allows any AWS account)"
fi

# Check for AdminAccess policy attachments
if grep -r 'AdministratorAccess\|arn:aws:iam::aws:policy/AdministratorAccess' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_high "AdministratorAccess policy used (should limit to admin breakglass only)"
fi

# Check for inline policies (prefer managed policies)
if grep -r 'inline_policy' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_info "Inline policy defined (prefer managed policies for reusability)"
fi

echo ""

# ============================================================================
# 2. PUBLIC EXPOSURE CHECKS
# ============================================================================
echo -e "${BLUE}--- Public Exposure Checks ---${NC}"

# Check for publicly_accessible = true
if grep -r 'publicly_accessible\s*=\s*true' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_critical "Database/resource with publicly_accessible = true"
fi

# Check for cidr_blocks = ["0.0.0.0/0"] in security groups
if grep -r 'cidr_blocks\s*=\s*\["0\.0\.0\.0/0"\]\|cidr_blocks\s*=\s*\[.*0\.0\.0\.0\/0' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#' | grep -i 'ingress'; then
  log_high "Security group with ingress from 0.0.0.0/0 (verify intentional)"
fi

# Check for IPv6 equivalency ::/0
if grep -r 'ipv6_cidr_blocks\s*=\s*\["::/0"\]' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#' | grep -i 'ingress'; then
  log_high "Security group with ingress from ::/0 IPv6 (verify intentional)"
fi

# Check for map_public_ip_on_launch
if grep -r 'map_public_ip_on_launch\s*=\s*true' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_medium "Subnet with map_public_ip_on_launch = true (should be private only)"
fi

# Check for ASG with public IP
if grep -r 'associate_public_ip_address\s*=\s*true' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_medium "Auto Scaling Group with associate_public_ip_address = true (should use NAT)"
fi

# Check for unrestricted S3 bucket policies
if grep -r '"Statement".*"Principal".*"\*"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_high "Bucket policy with Principal: * (verify intentional)"
fi

echo ""

# ============================================================================
# 3. ENCRYPTION CHECKS
# ============================================================================
echo -e "${BLUE}--- Encryption Checks ---${NC}"

# Check EBS without encryption
if grep -r 'resource "aws_ebs_volume"' "$SCAN_PATH" --include="*.tf" -A 5 2>/dev/null | grep -v 'encrypted\s*=\s*true' | grep -v '#'; then
  log_high "EBS Volume without explicit encrypted = true"
fi

# Check RDS without encryption
if grep -r 'resource "aws_db_instance"\|resource "aws_rds_cluster"' "$SCAN_PATH" --include="*.tf" -A 10 2>/dev/null | grep -v 'storage_encrypted\s*=\s*true' | head -20; then
  log_high "RDS resource may not have storage_encrypted = true"
fi

# Check S3 without server-side encryption
if grep -r 'resource "aws_s3_bucket"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_info "S3 bucket defined - verify server_side_encryption_configuration exists"
fi

# Check DynamoDB without encryption
if grep -r 'resource "aws_dynamodb_table"' "$SCAN_PATH" --include="*.tf" -A 20 2>/dev/null | grep -v 'sse_specification' | head -10; then
  log_info "DynamoDB table found - verify sse_specification.enabled = true"
fi

# Check for unencrypted snapshots
if grep -r 'encrypted\s*=\s*false' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_high "Encryption explicitly disabled (verify this is intentional)"
fi

echo ""

# ============================================================================
# 4. LOGGING CHECKS
# ============================================================================
echo -e "${BLUE}--- Logging Checks ---${NC}"

# Check RDS without CloudWatch logs
if grep -r 'resource "aws_db_instance"\|resource "aws_rds_cluster"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_info "RDS resource defined - verify enabled_cloudwatch_logs_exports configured"
fi

# Check VPC without Flow Logs
if grep -r 'resource "aws_vpc"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_medium "VPC defined - consider enabling VPC Flow Logs for production"
fi

# Check S3 without logging configuration
if grep -r 'resource "aws_s3_bucket"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v 'logging' | grep -v '#'; then
  log_medium "S3 bucket without logging configuration (for audit trail)"
fi

# Check ALB/NLB without access logs
if grep -r 'resource "aws_lb"\|resource "aws_alb"' "$SCAN_PATH" --include="*.tf" -A 10 2>/dev/null | grep -v 'access_logs' | head -10; then
  log_medium "Load Balancer without access_logs configuration"
fi

# Check Lambda CloudWatch logs
if grep -r 'resource "aws_lambda_function"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_info "Lambda function defined - verify CloudWatch Logs group exists"
fi

# Check for disabled CloudTrail
if grep -r 'enable_logging\s*=\s*false' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_critical "CloudTrail with enable_logging = false"
fi

echo ""

# ============================================================================
# 5. RISKY RESOURCE REPLACEMENT CHECKS
# ============================================================================
echo -e "${BLUE}--- Risky Resource Replacement Checks ---${NC}"

# Check for force_destroy on S3 (can delete buckets with objects)
if grep -r 'force_destroy\s*=\s*true' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#' | grep 'aws_s3'; then
  log_high "S3 bucket with force_destroy = true (will delete all objects)"
fi

# Check for skip_final_snapshot = true (data loss risk)
if grep -r 'skip_final_snapshot\s*=\s*true' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_high "RDS with skip_final_snapshot = true (data loss if replacement occurs)"
fi

# Check for enable_deletion_protection = false on critical resources
if grep -r 'enable_deletion_protection\s*=\s*false' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v '#'; then
  log_medium "Resource with deletion protection disabled (consider enabling for prod)"
fi

# Check for terraform lifecycle prevent_destroy rules
if grep -r 'resource "aws_db_instance"\|resource "aws_rds_cluster"' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v 'prevent_destroy' | head -5; then
  log_info "Critical database resource - consider adding lifecycle { prevent_destroy = true }"
fi

# Check for hardcoded availability zones (forces replacement on AZ removal)
if grep -r 'availability_zone\s*=' "$SCAN_PATH" --include="*.tf" 2>/dev/null | grep -v 'data\.' | grep -v '#'; then
  log_medium "Hardcoded availability_zone (prefer availability_zones list)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "Review Summary:"
echo -e "  ${RED}CRITICAL: $CRITICAL${NC}"
echo -e "  ${RED}HIGH:     $HIGH${NC}"
echo -e "  ${YELLOW}MEDIUM:   $MEDIUM${NC}"
echo -e "  ${BLUE}INFO:     $INFO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Exit code logic
if [[ $CRITICAL -gt 0 ]]; then
  echo -e "${RED}❌ Review FAILED: Critical issues found${NC}"
  exit 1
elif [[ $HIGH -gt 0 ]]; then
  if [[ "$STRICT_MODE" == "--strict" ]]; then
    echo -e "${RED}❌ Review FAILED (strict mode): High-severity issues found${NC}"
    exit 1
  else
    echo -e "${YELLOW}⚠️  Review PASSED with HIGH severity findings (review before merge)${NC}"
    exit 0
  fi
else
  echo -e "${GREEN}✅ Review PASSED${NC}"
  exit 0
fi

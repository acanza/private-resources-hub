#!/usr/bin/env bash
# validate-secrets.sh: Scan Terraform module for hardcoded secrets and unsafe patterns
# Usage: ./validate-secrets.sh <module-path>
# Example: ./validate-secrets.sh modules/rds

set -euo pipefail

MODULE_PATH="${1:-}"

if [[ -z "$MODULE_PATH" ]]; then
    echo "❌ Error: Module path required"
    echo "Usage: $0 <module-path>"
    echo "Example: $0 modules/rds"
    exit 1
fi

if [[ ! -d "$MODULE_PATH" ]]; then
    echo "❌ Error: Module path does not exist: $MODULE_PATH"
    exit 1
fi

echo "🔍 Scanning $MODULE_PATH for hardcoded secrets and unsafe patterns..."
echo ""

FOUND_ISSUES=0
WARNINGS=0

# Check for password literals (basic patterns)
if grep -r 'password\s*=\s*"[^"]*"' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "⚠️  WARNING: Possible hardcoded password found"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for API key patterns
if grep -r '(api_key|apikey|api-key|secret|token|access.key|secret.key)\s*=\s*"[a-zA-Z0-9]*"' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "❌ ERROR: Possible hardcoded API key or secret found"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

# Check for AWS credential patterns
if grep -rE '(AKIA[0-9A-Z]{16}|aws_access_key|aws_secret_key)' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "❌ ERROR: AWS credential pattern detected"
    FOUND_ISSUES=$((FOUND_ISSUES + 1))
fi

# Check for common unsafe patterns
if grep -r 'skip_final_snapshot\s*=\s*true' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "⚠️  WARNING: skip_final_snapshot = true (data loss risk in production)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for publicly accessible resources
if grep -r 'publicly_accessible\s*=\s*true' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "⚠️  WARNING: publicly_accessible = true (ensure intentional)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for unencrypted storage
if grep -r 'encrypted\s*=\s*false' "$MODULE_PATH" --include="*.tf" 2>/dev/null; then
    echo "⚠️  WARNING: Encryption disabled on storage resource"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for missing sensitive flag on password variables
if grep -r 'variable.*password' "$MODULE_PATH" --include="*.tf" -A 3 | grep -v 'sensitive\s*=\s*true' 2>/dev/null; then
    echo "ℹ️  INFO: Password variable without sensitive = true flag"
fi

echo ""
if [[ $FOUND_ISSUES -eq 0 && $WARNINGS -eq 0 ]]; then
    echo "✅ No critical security issues found"
    exit 0
elif [[ $FOUND_ISSUES -eq 0 ]]; then
    echo "✓ No critical errors, but $WARNINGS warning(s) found"
    exit 0
else
    echo "❌ Found $FOUND_ISSUES critical security issue(s)"
    exit 1
fi

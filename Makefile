# ==============================================================================
# Makefile — private-resources-hub
#
# Standardises the Terraform workflow across environments.
# All commands operate on envs/$(ENV) unless otherwise stated.
#
# Usage:
#   make fmt            # format all code (modules + target env)
#   make validate       # validate configuration syntax, no AWS calls
#   make plan           # generate and save a plan for review
#   make apply          # apply the saved plan (requires prior make plan)
#   make destroy        # destroy all resources (irreversible — prompts first)
#
# Override the target environment:
#   make plan ENV=stage
#   make plan ENV=prod
# ==============================================================================

ENV ?= dev

.PHONY: fmt validate plan apply destroy

# ------------------------------------------------------------------------------
# fmt
# Formats all .tf files under modules/ and the target environment directory.
# Idempotent: safe to run at any time.
# ------------------------------------------------------------------------------
fmt:
	terraform fmt -recursive modules/
	terraform fmt -recursive envs/$(ENV)/

# ------------------------------------------------------------------------------
# validate
# Checks configuration syntax and internal consistency.
# Requires terraform init to have been run at least once.
# Makes no AWS API calls.
# ------------------------------------------------------------------------------
validate:
	terraform -chdir=envs/$(ENV) validate

# ------------------------------------------------------------------------------
# plan
# Generates an execution plan and saves it to envs/$(ENV)/tfplan.
# Read-only: makes no infrastructure changes.
# Review the output before running apply.
# ------------------------------------------------------------------------------
plan:
	terraform -chdir=envs/$(ENV) plan -out=tfplan

# ------------------------------------------------------------------------------
# apply
# Applies the plan previously saved by make plan.
# Only run after reviewing plan output. Never apply without a prior plan.
# ------------------------------------------------------------------------------
apply:
	terraform -chdir=envs/$(ENV) apply tfplan

# ------------------------------------------------------------------------------
# destroy
# Destroys all resources managed in the target environment.
# IRREVERSIBLE. Prompts for confirmation before proceeding.
# ------------------------------------------------------------------------------
destroy:
	@echo ""
	@echo "  WARNING: This will destroy ALL resources in envs/$(ENV)."
	@echo "  This action is irreversible and may cause data loss."
	@echo "  Press Ctrl+C within 10 seconds to abort."
	@echo ""
	@sleep 10
	terraform -chdir=envs/$(ENV) destroy

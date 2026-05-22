# 02 — Security Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the security requirements for the Private Resource Hub MVP.

The system must ensure that:

1. Only authenticated users can call the backend API.
2. Users can only view resources assigned to them.
3. Private files are never publicly accessible.
4. Temporary access to private content is granted only after authorization.
5. AWS permissions follow least-privilege principles.

---

## Security Principles

The MVP must follow these security principles:

- Authentication before API access.
- Authorization before private content access.
- Least-privilege IAM permissions.
- No public access to private S3 buckets.
- No secrets in frontend code.
- No secrets in Terraform outputs.
- No direct S3 access for private files.
- Temporary access for private resources.
- Clear separation between public frontend assets and private content.

---

## Identity and Authentication

## Cognito User Pool

Amazon Cognito User Pool must be used as the identity provider.

Users must authenticate through Cognito before accessing protected API routes.

The frontend must obtain a valid Cognito token after login.

## Token Usage

The frontend must call the backend API using the following header:

```http
Authorization: Bearer <jwt>
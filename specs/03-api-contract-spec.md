# 03 — API Contract Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the backend API contract for the Private Resource Hub MVP.

The API must allow authenticated users to:

1. Retrieve the list of resources they are authorized to access.
2. Request temporary access to a specific private resource.

All API routes must be protected by Amazon Cognito authentication through API Gateway JWT Authorizer.

---

## API Overview

## Base URL

The API will be exposed through Amazon API Gateway HTTP API.

The final API base URL will be provided as a Terraform output.

Example:

```txt
https://{api_id}.execute-api.{region}.amazonaws.com
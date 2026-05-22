# 01 — Architecture Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the target AWS architecture for the Private Resource Hub MVP.

The system must follow a simple serverless three-tier architecture:

1. Presentation and authentication layer.
2. Application layer.
3. Data and private content layer.

The architecture must prioritize security, low operational overhead, low cost, and clarity for a Terraform portfolio project.

---

## Architecture Overview

```txt
User Browser
   |
   v
CloudFront Distribution
   |
   v
S3 Frontend Bucket

User authenticates with Cognito
   |
   v
Cognito User Pool
   |
   v
JWT Token

Frontend calls API with JWT
   |
   v
API Gateway HTTP API + JWT Authorizer
   |
   v
Lambda Backend
   |
   +--> DynamoDB resource access table
   |
   +--> CloudFront signed URL/cookie generation
             |
             v
      CloudFront Private Content Distribution
             |
             v
      S3 Private Content Bucket
# 00 — Product Specification

## Project Name

Private Resource Hub

## Purpose

The goal of this project is to build a private resource hub where authenticated users can access only the resources they are explicitly authorized to view.

The system must provide a simple web interface where users can log in, see their available resources, and open private content through temporary authorized access.

## MVP Scope

The MVP must support the following capabilities:

1. Users can authenticate through Amazon Cognito.
2. Authenticated users can view a list of resources available to them.
3. Each resource must include:
   - `title`
   - `description`
   - `content_prefix`
4. User access permissions must be stored in DynamoDB.
5. A user must only be able to access resources assigned to them.
6. Private files must be stored in a private S3 bucket.
7. Temporary access to private files must be granted through CloudFront signed URLs or signed cookies.

## Out of Scope for MVP

The following features are intentionally excluded from the MVP:

- Admin dashboard.
- Resource creation from the frontend.
- User management UI.
- Advanced role-based access control.
- Multi-tenant support.
- Payment or subscription logic.
- Full-text search.
- Analytics or audit dashboard.
- CI/CD pipeline.
- Production-grade observability.

## User Roles

### Authenticated User

An authenticated user can:

- Log in.
- View their authorized resources.
- Request temporary access to an authorized resource.
- Open private content only when access has been granted.

An authenticated user cannot:

- View resources assigned to other users.
- Access private S3 objects directly.
- Generate access to unauthorized resources.
- Modify resources or permissions.

### System Administrator

For the MVP, the system administrator is not represented by a dedicated UI.

Administrative actions such as creating users, uploading files, and inserting access records into DynamoDB may be performed manually or through scripts.

## Functional Requirements

### FR-001 — User Authentication

The system must allow users to authenticate using Amazon Cognito.

After successful authentication, the frontend must receive a valid token that can be used to call the backend API.

### FR-002 — Resource Listing

The system must provide an endpoint that returns the list of resources available to the authenticated user.

The response must include only resources for which the user has explicit access.

### FR-003 — Resource Metadata

Each resource must expose the following metadata:

```json
{
  "id": "res-1",
  "title": "Example Resource",
  "description": "Example resource description",
  "content_prefix": "resources/res-1/"
}
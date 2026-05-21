# 04 — Data Model Specification

## Project Name

Private Resource Hub

## Purpose

This specification defines the DynamoDB data model for the Private Resource Hub MVP.

The model uses a simple single-table design to support:

1. Resource metadata storage.
2. User-to-resource access relationships.
3. Efficient reads for user resource listing and resource metadata retrieval.

---

## Table Definition

## DynamoDB Table

- Table name: `resource_access`
- Partition key (`pk`): string
- Sort key (`sk`): string

The table stores multiple item types in the same table.

---

## Item Types

## 1) RESOURCE Item

Represents the canonical metadata for a private resource.

### Key Pattern

- `pk = RESOURCE#{resource_id}`
- `sk = METADATA`

### Attributes

- `resource_id` (string)
- `title` (string)
- `description` (string)
- `content_prefix` (string)

### Example

```json
{
  "pk": "RESOURCE#res-001",
  "sk": "METADATA",
  "resource_id": "res-001",
  "title": "AWS Security Basics",
  "description": "Introductory security guide",
  "content_prefix": "resources/res-001/"
}
```

## 2) USER_RESOURCE_ACCESS Item

Represents an authorization edge between a user and a resource.

### Key Pattern

- `pk = USER#{email}`
- `sk = RESOURCE#{resource_id}`

### Attributes

- `user_id` (string)
- `resource_id` (string)

### Example

```json
{
  "pk": "USER#user@example.com",
  "sk": "RESOURCE#res-001",
  "user_id": "cognito-sub-1234567890",
  "resource_id": "res-001"
}
```

---

## Primary Access Patterns

The MVP data model must support the following access patterns without scans:

1. Get resource metadata by `resource_id`.
2. List all resources authorized for a user (by email).
3. Verify if a user has access to a specific resource.

### AP-001 — Get Resource Metadata

- Operation: `GetItem`
- Key:
  - `pk = RESOURCE#{resource_id}`
  - `sk = METADATA`

### AP-002 — List User Authorized Resources

- Operation: `Query`
- Key condition:
  - `pk = USER#{email}`
  - `begins_with(sk, 'RESOURCE#')`

Returns access edges, then the backend resolves metadata for each `resource_id`.

### AP-003 — Check User Access to One Resource

- Operation: `GetItem`
- Key:
  - `pk = USER#{email}`
  - `sk = RESOURCE#{resource_id}`

If the item exists, access is granted; otherwise, access is denied.

---

## Backend Resolution Flow

For listing resources in the API:

1. Query user access edges using `USER#{email}`.
2. Extract `resource_id` values.
3. Fetch corresponding `RESOURCE` metadata items.
4. Return a response containing:
   - `resource_id`
   - `title`
   - `description`
   - `content_prefix`

---

## Constraints and Conventions

- `resource_id` must be stable and unique.
- `content_prefix` must point to a private S3 path prefix.
- `pk` and `sk` values must always use the exact prefixes:
  - `RESOURCE#`
  - `USER#`
- Resource metadata must only be stored in `RESOURCE` items.
- Authorization relationships must only be stored in `USER_RESOURCE_ACCESS` items.

---

## Non-Goals for MVP

The following are out of scope for this model version:

- Secondary indexes (GSI/LSI).
- Hierarchical resource categories.
- Time-based expiration for access edges.
- Audit history for grants/revocations.
- Multi-tenant key namespace expansion.

---

## Notes

- The access edge key uses user email (`USER#{email}`), while `user_id` remains available as an attribute for identity traceability.
- If future requirements demand lookups by `user_id` only, a dedicated key strategy or GSI should be introduced in a later version.

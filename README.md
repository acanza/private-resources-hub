# AWS infrastructure for private resource hub

## Implemented infrastructure

Serverless private content platform on AWS with authentication (Cognito User Pool), API Gateway HTTP API with Lambda backend, DynamoDB single-table design for resource metadata and access control, and CloudFront distributions for secure frontend and private content delivery.

### Terraform modules

| Module | Main Resource | Purpose |
| :--- | :--- | :--- |
| `auth_cognito` | Cognito User Pool | User authentication and JWT token generation |
| `backend_api` | API Gateway HTTP API + Lambda | RESTful API endpoint with authorization |
| `backend_iam` | IAM Role | Lambda execution permissions (Logs, DynamoDB, Secrets Manager, S3) |
| `data_dynamodb` | DynamoDB Table | Single-table design for resource metadata and access records |
| `frontend_delivery` | S3 Bucket + CloudFront Distribution | Public SPA/static site delivery |
| `private_content_delivery` | S3 Bucket + CloudFront Distribution | Private content delivery with signed URLs/cookies |

### Architecture diagram

![Private Resources Hub Architecture](./docs/private-resources-hub-diagram.png)

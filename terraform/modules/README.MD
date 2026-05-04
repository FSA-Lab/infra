# Terraform Modules Description

Each module is a separate Terraform configuration that can be applied independently.
Initially, the project is deployed as Kubernetes services.
However, latest requirements required to deploy the app as serverless functions.

## Backend

This module creates an Azure Storage Account to store the Terraform state file.
This module must be initialized first.

## AKS

This module creates an Azure Kubernetes Service cluster to deploy:
A. CI tools: Jenkins, SonarQube, ...
B. CD tools: ArgoCD, ...
C. Monitoring tools: Prometheus, Grafana, ...

## Gateway

This module creates an API Gateway to route traffic to the services deployed in AKS.
The API Gateway also serves as the entry point for the app and handles authentication, rate limiting, and other cross-cutting concerns.

## Functions

Each submodule under `functions` creates an Azure Function App to deploy a microservice as serverless functions.

1. `auth`: This module creates an Azure Function App for the authentication service, which handles user authentication and authorization
2. `import`: This module creates an Azure Function App for the import transactions
3. `export`: This module creates an Azure Function App for the export transactions
4. `email`: This module creates an Azure Function App for the email service

## Generator

This is a VM responsible for generating load to the app.

## Queue

This is a Service Bus to be used as a message queue for the app. Its sole purpose is to allow Export service to send messages to Email service, which will then send emails to users. This is to demonstrate the use of message queue in a microservices architecture, and to decouple the Export and Email services.

## Database

This is an Azure SQL Database to be used as the main database for the app. Each service can have its own database, but for simplicity, we will use a single database for all services in this project.

## Storage

This is an Azure Blob Storage to be used as the main storage for the app. Its sole purpose is to store output files from the Export service, which will then be sent to users via email by the Email service.

# External Modules

## Container Registry

GitHub is used as project container registry.

## CI Runner (partial)

GitHub Actions is used as CI runner for the project. However, we still set up Jenkins in AKS for demonstration purposes, and it can be used as a CI runner if needed.

## Email Service

[TBA]

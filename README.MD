# CI/CD Lab

This repository contains the infrastructure code for the CI/CD lab. The goal of this lab is to create a simple app and set up a CI/CD pipeline for it.

# Tech Stack

1. App

The app follows a microservices architecture, and each service introduces a different tech stack.

- Node.js

2. CI/CD

- Jenkins
- Argo CD

3. Infrastructure

- Terraform
- Ansible
- Azure

# Project Structure

- `ansible/`: Ansible playbooks and roles for configuration management and deployment.
- `docs/`: documentation, including requirements and design decisions.
- `terraform/`: Terraform configurations for provisioning infrastructure.
- `config/`: configuration files for CI/CD pipelines and other tools.
- `scripts/`: deployment, testing, and other automation tasks.

# Roles

The project team consists of 4 members, each responsible for different aspects of the project. However, all members should have a good understanding of the entire project and be able to contribute to any part of it when needed.

Under each role below, tasks are divided into multiple parallel tracks. Each track can be worked on independently by each team member.

## Track 0: Project Setup

For this track only, a single team member will be responsible for setting up the initial project, including:

- Project structure
- Initial configurations: Git, Terraform, CI/CD pipelines, etc.
- Conduct a meeting to vote for the tech stack

## Track 1: App Development

- Design services: each team member handles the design of one or more services from auth, order, inventory, and email.
- Implement services: each team member implements the services they designed, ensuring they meet the requirements and integrate well with other services.
- Write tests: each team member writes unit and integration tests for their services.

## Track 2: CI/CD Pipeline

- Set up CI/CD pipelines:
  - Pre-build: linting, static code analysis, testing
  - Build: building Docker images, pushing to registry
  - Post-build: vulnerability scanning (Trivy\*)
  <!-- - Post-build: deployment -->

> \* Trivy is also used as a live scanning operator in the cluster, but it can also be used in the CI/CD pipeline to scan images before deployment.

## Track 3: Infrastructure

- Setup repositories for app and infrastructure code.
- Setup Azure Kubernetes Service (AKS) pods using Terraform:
  - Message Queue (RabbitMQ)
  - Databases for each service
  - Monitoring tools (Grafana, Loki, Prometheus, Jaeger, ...)
  - mTLS: Envoy & sidecar injection
  - Jenkins
  - SonarQube (on different region)
  - Trivy (operator): live scanning of cluster images

## Track 4: Monitoring (\*\*)

- Grafana: set up dashboards for monitoring the app and infrastructure.
- Loki: set up log aggregation for the app and infrastructure.
- Prometheus: set up metrics collection for the app and infrastructure.
- Jaeger: set up distributed tracing for the app.
- Set up alerts and notifications for critical issues.

> Ensure each service has its own monitoring and alerting setup (e.g. via agent/lib) to instrument the service and send metrics/logs/traces to the monitoring stack.

> \*\* Team members are responsible for monitoring their services. This does not apply to infrastructure monitoring.

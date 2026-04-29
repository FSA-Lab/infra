# Project Contributing Guide

This document outlines the guidelines for contributing to the CI/CD Lab project.

## Git Workflow

- Branch strategy:
  - Use `main` for tracking releases.
  - Use `test` for testing and running pipelines.
  - Use `prod` for production-ready code.
  - Use `dev` for ongoing development.
  - Code flow: `dev` → `test` → `main` → `prod`.
  - Feature branches must be created from `dev` and named `feature/<feature-name>`. Feature names must be in lowercase and use hyphens to separate words (e.g., `feature/add-auth-service`).

- Pull Requests (PRs):
  - PRs must be created from a feature branch to `dev`.
  - PRs must include a clear description of the changes made and the reason for the changes.
  - PRs must be reviewed and approved by at least one other team member before merging.
  - PRs must pass all CI/CD pipeline checks before merging. See the CI/CD section below for details on the required checks.
  - PRs can be created early in the development process, but they must be synced with the latest changes in `dev` to avoid merge conflicts.

## CI/CD Pipelines

1. CI pipelines:

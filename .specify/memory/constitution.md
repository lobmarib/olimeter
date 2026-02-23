<!--
SYNC IMPACT REPORT
==================
Version: 1.0.0 → 1.1.0 → 1.1.1 (PATCH: Java version updated)
Ratified: 2026-02-20
Last Amended: 2026-02-23

CHANGES SUMMARY:
- Type: Amendment - Technology Stack Specification
- Added concrete technology choices for backend, frontend, mobile, and database
- Enforces consistency across all layers

PRINCIPLES (5 total - UNCHANGED):
✅ I. API-First Design - Define contracts before implementation
✅ II. Separation of Concerns - Organize by domain (backend, web, mobile, database)
✅ III. Database Schema Versioning - Track all schema changes in migrations
✅ IV. Testing Requirements - Backend: unit & integration; Frontend/Mobile: component tests
✅ V. Minimal Complexity - No premature abstraction

SECTIONS:
✅ Code Organization - Monorepo structure with clear boundaries
✅ Development Workflow - 6-step ordered process with API-first precedence
✅ Technology Stack - NEW (Backend, Frontend, Mobile, Database specifications)
✅ Governance - Amendment procedures with semantic versioning

TECHNOLOGY ADDITIONS:
- Backend: Spring Boot 4.0.1, Java 21 LTS, Gradle 9.3.0 with Kotlin DSL, Docker Java SDK, SpringDoc OpenAPI
- Frontend: React 19.2.4, TypeScript 5.9, Ant Design 6.2.0, React Query + Context API, Axios, Vite
- Mobile: React Native (cross-platform iOS/Android)
- Database: PostgreSQL 15+ (open-source, battle-tested SQL database)

TEMPLATE SYNC STATUS:
✅ .specify/templates/plan-template.md - Updated (Technical Context section now has concrete versions)
✅ .specify/templates/spec-template.md - Aligned (FR requirements now scoped to chosen stack)
✅ .specify/templates/tasks-template.md - Aligned (Task templates account for layered architecture)

DEFERRED ITEMS: None

NEXT STEPS:
1. Run /speckit.plan after feature specs are defined
2. Constitution Check gate validates API-First + Tech Stack adherence
3. Tasks reference Spring Boot service paths, React component paths, React Native screen paths
-->

# OliMeeter Constitution

## Core Principles

### I. API-First Design
Backend API MUST define contracts before frontend/mobile implementation begins. All client-server communication through RESTful endpoints with documented request/response schemas. Breaking API changes require version bumping.

### II. Separation of Concerns
Code MUST be organized by domain: backend services, web app, mobile app, and database migrations kept separate. Each tier has independent deployment cycle and can be tested in isolation.

### III. Database Schema Versioning
All schema changes MUST be tracked in migrations. No direct database modifications outside version control. Migrations MUST be reversible when possible. Schema changes require corresponding backend and client coordination.

### IV. Testing Requirements
Backend: unit tests for business logic, integration tests for API endpoints. Web/Mobile: component tests for UI logic. All PRs require passing tests before merge.

### V. Minimal Complexity
Start with essential features only. No premature abstraction or over-architecting. Prefer simple solutions over framework magic.

## Code Organization

Monorepo or multi-repo structure with clear boundaries:
- `/backend` - REST API, business logic, database connectivity
- `/web` - Web application frontend
- `/mobile` - Mobile application code
- `/database` - Schema migrations and initialization scripts

## Technology Stack

All layers MUST use the specified technology versions. Deviations require amendment.

### Backend Stack
- **Framework**: Spring Boot 4.0.1 (latest stable)
- **Language**: Java 25
- **Build Tool**: Gradle 9.3.0 with Kotlin DSL
- **Docker Integration**: Docker Java SDK (docker-java)
- **API Documentation**: SpringDoc OpenAPI (Swagger UI)
- **Testing**: JUnit 5, Mockito, Spring Test

### Frontend Stack (Web)
- **Framework**: React 19.2.4 with TypeScript 5.9
- **UI Library**: Ant Design 6.2.0 (latest stable)
- **State Management**: React Query for server state, Context API for UI state
- **HTTP Client**: Axios with TypeScript types
- **Build Tool**: Vite for development and production builds
- **Testing**: Vitest, React Testing Library

### Mobile Stack
- **Framework**: React Native (cross-platform iOS/Android)
- **Language**: TypeScript (same as web for consistency)
- **State Management**: React Query for server state, Context API for UI state
- **HTTP Client**: Axios with TypeScript types
- **Testing**: Jest, React Native Testing Library

### Database Stack
- **Database**: PostgreSQL 15+ (open-source SQL database)
- **Query Language**: SQL with prepared statements (no SQL injection vulnerabilities)
- **Migrations**: Flyway or Liquibase for schema versioning from backend
- **ORM** (optional in backend): Spring Data JPA with Hibernate as persistence provider

### Technology Rationale
- **Java 25**: Latest stable release with modern language features and optimizations
- **Spring Boot**: Mature ecosystem, built-in conventions reduce boilerplate
- **PostgreSQL**: Reliable open-source RDBMS with strong JSONB support for flexible schemas
- **React + TypeScript**: Type safety reduces bugs, consistent web + mobile codebase
- **React Native**: Single codebase for iOS/Android, shared business logic with web

## Development Workflow

1. Changes start with documented requirements
2. Backend API changes precede client implementation
3. Schema changes require migration files
4. All code changes include tests
5. Code review verifies architecture consistency and technology stack adherence
6. Deployment: backend/database first (with migrations), then web/mobile clients

## Governance

This constitution supersedes all other development guidelines. Amendments require documentation of the change rationale and impact assessment on existing services. Version increments follow semantic versioning: MAJOR for principle changes, MINOR for clarifications, PATCH for non-semantic updates.

**Version**: 1.1.1 | **Ratified**: 2026-02-20 | **Last Amended**: 2026-02-23

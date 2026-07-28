# RoleWeave

An open source, self-hostable recruiting platform.

[日本語](README.md) | English

## Current status

**Under development. Not recommended for production use.**

This repository is at an early stage. The Rails application foundation is present,
but business features such as job postings, applications, and authentication have
not yet been implemented. Breaking changes may be made without notice.

## About this project

We are building a self-hostable, open source recruiting platform that covers job
posting publication, job search, candidate profiles, job applications, hiring
workflows, sourcing, messaging, notifications, and external integrations.

### Built from scratch

No code, database schema, routing, naming, or directory structure has been ported
from any existing application. Existing material is used only as reference for
understanding which features are needed.

### Japanese and English

The following are provided in both Japanese and English:

- User-facing text (UI) is treated equally in Japanese and English from the beginning
- Public specifications, setup instructions, and usage documentation are provided in both languages

The following use Japanese as the source of truth:

- Internal design documents, ADRs, task definitions, and review records are written in Japanese
- An English translation is not required for all of them

### No hosted demo

We do not provide a permanently hosted demo environment or hosting service at this
stage. Evaluation is expected to be done in a local environment.

## Technology stack

The following are the initial baselines. Each version will be pinned to the stable
patch release available at initialization time.

- A modular monolith built with Ruby on Rails
- PostgreSQL as the system of record
- Server-side rendering with Turbo and Stimulus
- Active Job, Solid Queue, and Active Storage
- Docker Compose for the local development environment
- GitHub Actions for verification

Redis, OpenSearch, and Kubernetes are not required at this stage.

## Setup

Setup instructions will be added once the development environment is in place
(when P0 of the roadmap is complete).

## Documentation

The documents below are internal design documents and are written in Japanese, as
described above. Setup and usage documentation will be provided in both languages.

- [Project brief](design/brief.md) — what is being built and who it is for
- [Constitution](design/constitution.md) — the principles that guide planning and implementation decisions
- [Roadmap](design/roadmap.yaml) — phase index from P0 through P15
- [Architecture principles](docs/architecture/principles.md) — how structural decisions are made
- [Language and naming policy](docs/development/language-policy.md) — when Japanese and English are used
- [code-pact operations guide](docs/development/code-pact.md) — how the development control plane is used

## How development proceeds

As a rule, each task produces one verifiable result and one pull request.
See the [architecture principles](docs/architecture/principles.md) for details.

## License

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)

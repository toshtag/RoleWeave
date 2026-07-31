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

Regular local development can be started with Docker Compose alone.

### Requirements

- Git
- Docker Engine or Docker Desktop
- Docker Compose v2

The following do not need to be installed on the host for regular development:

- Ruby
- PostgreSQL
- Node.js
- npm

### Get the repository

```bash
git clone https://github.com/toshtag/RoleWeave.git
cd RoleWeave
```

### Build the image

```bash
docker compose build app
```

To rebuild the base image and dependencies without the cache, run the following.
This is used for re-verifying the foundation and is not needed for regular development.

```bash
docker compose build --no-cache app
```

### Initial setup

```bash
docker compose run --rm app bin/setup
```

`bin/setup` does the following:

- Checks the Ruby dependencies and prepares them only when they are missing
- Prepares the development database
- Clears old logs and temporary files

It does not start the development server; starting it is the responsibility of
`docker compose up`. It converges on the same state however many times it is run,
so it can be run again. It changes neither the contents of an existing development
database nor any tracked file.

### Start the application

```bash
docker compose up
```

Business screens and the root route are not implemented at this stage, so there is
no top page. Use the health check to confirm that the application is running.

```text
http://127.0.0.1:3000/up
```

To change the host port, specify `APP_PORT`.

```bash
APP_PORT=3001 docker compose up
```

### Standard verification

```bash
docker compose run --rm app bin/verify
```

This runs the dependency check, the security checks, Ruby style, Zeitwerk, and the
Rails test suite. It does not install dependencies, change the development database,
or start the server.

bundler-audit updates the advisory database before auditing, so network access is
required.

### Stop the application

Press `Ctrl+C` when it is running in the foreground.
To stop and remove the containers, run the following.

```bash
docker compose down
```

To remove the development data as well, add `--volumes`. **This is a destructive
operation.** The named volumes holding the PostgreSQL data and the bundle cache are
removed, and the contents of the development database are lost.

```bash
docker compose down --volumes
```

### Full verification

`bin/verify --full` is the full P0 verification, including the Docker foundation and
the idempotency of `bin/setup`. It is intended for maintainers and is not needed for
regular development.

Unlike the standard verification it runs directly on the host, so the following are
required:

- The Ruby version recorded in `.ruby-version` (4.0.6)
- Bundler
- Docker Engine or Docker Desktop, and Docker Compose v2
- The Ruby dependencies on the host

```bash
bundle install
bin/verify --full
```

The full verification checks that `Gemfile` and `Gemfile.lock` are unchanged in the
working tree. Commit them first if dependencies have been updated.

## Documentation

The documents below are internal design documents and are written in Japanese, as
described above. Setup and usage documentation will be provided in both languages.

- [Project overview](docs/project-overview.md) — what is being built and who it is for
- [Project principles](docs/project-principles.md) — the principles that guide planning and implementation decisions
- [Roadmap](docs/roadmap/index.yaml) — phase index from P0 through P15
- [Architecture principles](docs/architecture/principles.md) — how structural decisions are made
- [Language and naming policy](docs/development/language-policy.md) — when Japanese and English are used
- [Coding style](docs/development/coding-style.md) — language, comment, and structure rules referenced while implementing
- [Development workflow](docs/development/workflow.md) — responsibilities of the roadmap, issues, PRs, and ADRs
- [Cross-cutting quality requirements](docs/quality/cross-cutting-requirements.md) — quality requirements met within each feature phase

## How development proceeds

The roadmap is the source of truth for long-term planning, GitHub Issues for
implementation tasks and bugs, and pull requests for implementation results
and verification records. As a rule, each issue produces one verifiable result
and one pull request. See the [development workflow](docs/development/workflow.md)
for details.

## License

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)

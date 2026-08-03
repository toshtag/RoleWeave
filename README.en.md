# RoleWeave

An open source, self-hostable recruiting platform.

[日本語](README.md) | English

## Current status

**Ready to evaluate, not guaranteed for production use.**

The latest published release is `v0.1.0`. The current `main` contains features and
fixes added after `v0.1.0`. They have not been versioned yet, so they have not been
published as a release.

Every planned phase, P0 through P15, is complete.

The following is implemented on the current `main`:

| Area | Contents |
| --- | --- |
| Accounts | Sign-up, email confirmation, sign-in, password reset, authentication records |
| Organizations | Creation, invitations, roles (owner / member), role change history, operators |
| Job postings | Creation and editing, separation of submission and approval, publication history |
| Public discovery | Job list and detail, keyword and attribute filters, pagination, sitemap and robots, structured data |
| Profiles | Basic information, work history, education, skills, desired conditions, document attachments, visibility |
| Applications | Applying, duplicate prevention, snapshot at the time of applying, withdrawal, organization-side access |
| Hiring workflow | Selection stages, reviews and comments, assignees, interview schedules, decision deadlines |
| Messaging | Conversations tied to an application, read state, in-app notifications, email notifications, delivery failures and resending |
| Saving and sourcing | Saved jobs, saved searches, new job notifications, candidate search, talent pools |
| Scouting | Sending, templates, sending limits, opting out, duplicate prevention |
| Integrations | Generic webhooks, job posting CSV import and export, integration run history |
| Safety | Rate limiting, CSP, reverse proxy assumptions, request size limits, retention, deletion and anonymization, audit log |
| Operations | Structured logging, slow query logging, load testing, capacity model, backup procedure |
| Evaluation | Fictional demo data, role-based guides, architecture overview |

Candidate search and scouting only reach candidates **who have explicitly opted in**.
The default is opted out (see
[ADR 0055](docs/decisions/0055-candidate-search.md), written in Japanese).

What is still *not* included and the known limitations are listed in the
[changelog](CHANGELOG.md). Quality requirements that are not met are listed in
[the known gaps](docs/known-gaps.md).

While on `0.x`, breaking changes may still land between versions.

## About this project

We are building a self-hostable, open source recruiting platform that covers job
posting publication, job search, candidate profiles, job applications, hiring
workflows, sourcing, messaging, notifications, and external integrations.

It is aimed at organizations that want their hiring data under their own control,
and at the developers who build and operate that environment. Success is measured
by ease of change, safety, and reproducibility rather than by feature count.

### Built from scratch

No code, database schema, routing, naming, or directory structure has been ported
from any existing application. Existing material is used only as reference for
understanding which features are needed.

### Japanese and English

User-facing text (UI), public specifications, setup instructions, and usage
documentation are provided in both languages. Internal design documents, ADRs,
task definitions, and verification records use Japanese as the source of truth;
an English translation is not required for them.

### No hosted demo

We do not provide a permanently hosted demo environment or hosting service at this
stage. Evaluation is expected to be done in a local environment.

## Technology stack

- A modular monolith built with Ruby on Rails 8.1 (Puma)
- PostgreSQL 18 as the system of record
- Server-side rendering with Turbo, Stimulus, Propshaft, and Importmap
- Solid Queue, Solid Cache, and Active Storage (Disk)
- Docker Compose for local development, GitHub Actions for verification

**No Redis, OpenSearch, Kubernetes, or external CDN.** Everything is chosen so
that the application can be self-hosted (see the
[architecture overview](docs/architecture.md), written in Japanese).

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

Downloaded `.deb` and `.gem` files live in BuildKit cache mounts. They are not
kept in the image, and the next build does not fetch them again.

Build cache accumulates on the Docker side. Run `docker builder prune` to reclaim
the space. **This also removes cache belonging to other projects.**

### Initial setup

```bash
docker compose run --rm app bin/setup
```

It checks the dependencies, prepares the development database, and clears old logs
and temporary files. It does not start the development server; that is the
responsibility of `docker compose up`.

**It never drops or resets an existing database.** Pending migrations are applied,
so the contents may change as those migrations define. Rerunning it converges on
the same development-ready state.

### Start the application

```bash
docker compose up
```

Japanese and English entry pages are provided.

```text
http://127.0.0.1:3000/ja
http://127.0.0.1:3000/en
```

`/` redirects to the Japanese page. The public job list is at `/en/jobs`, sign-in at
`/en/session/new`, and account creation at `/en/registration/new`.
The role-based guides ([candidate](docs/guides/candidate.md),
[organization](docs/guides/organization.md)) list the entry points per role.
They are written in Japanese; the URLs apply to `/en` as well.

The health check is still available for confirming that the application is running.

```text
http://127.0.0.1:3000/up
```

To change the host port, specify `APP_PORT`.

```bash
APP_PORT=3001 docker compose up
```

### Load the demo data

This loads fictional data for evaluation. It can only be run in development.

```bash
docker compose run --rm app bin/rails roleweave:demo:seed
```

The accounts and passwords it creates are printed. Every email address is under
`@example.invalid`, a domain that cannot exist.

To remove it, run the following.

```bash
docker compose run --rm app bin/rails roleweave:demo:clean
```

Granting operator privileges, applying the retention policy, and measuring
performance are covered in
[using it as an operator](docs/guides/operator.md), written in Japanese.

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

Unlike the standard verification it runs directly on the host, so it needs the Ruby
version recorded in `.ruby-version` (4.0.6), Bundler, Docker, and an environment
with Bash and common Unix command-line tools (macOS, Linux, WSL, or Git Bash).
Running it from native PowerShell or Command Prompt alone is out of scope.

```bash
bundle install
bin/verify --full
```

It fails if `Gemfile` or `Gemfile.lock` is modified in the working tree. Commit
them first if dependencies have been updated.

## Documentation

Setup and usage documentation is provided in both languages. The design documents
below are written in Japanese.

### Using it

- [As a candidate](docs/guides/candidate.md) — from sign-up to applying and leaving
- [As an organization](docs/guides/organization.md) — organizations, job postings, hiring
- [As an operator](docs/guides/operator.md) — for whoever runs the server

### Operating it

- [Backup and restore](docs/operations/backup-and-restore.md) — the database and the attachments are handled as a pair
- [Reverse proxy assumptions](docs/operations/reverse-proxy.md) — what the front proxy must provide, and what stops working without it
- [File storage](docs/operations/file-storage.md) — where attachments live and how they are handled when self-hosting
- [Load test results](docs/operations/load-test-results.md) — measured values only
- [Capacity model](docs/operations/capacity-model.md) — estimates with the assumptions stated

### Developing it

- [Contributing](CONTRIBUTING.md) — how work proceeds and what verification is required
- [Architecture overview](docs/architecture.md) — how the pieces fit together
- [Development principles](docs/principles.md) — how planning, implementation, and code decisions are made
- [Development workflow](docs/development/workflow.md) — responsibilities of issues, PRs, verification, and ADRs
- [Language and naming policy](docs/development/language-policy.md) — when Japanese and English are used
- [Release procedure](docs/development/release.md) — how versions are assigned and checked before release
- [Decision records](docs/decisions/) — the [architecture overview](docs/architecture.md) indexes them by topic

### Knowing what is missing

- [Changelog](CHANGELOG.md) — what each version contains and its known limitations
- [Known gaps](docs/known-gaps.md) — what is met and what is not
- [Threat model](docs/threat-model.md) — what is defended against and what is accepted
- [Security policy](SECURITY.md) — where to report a problem
- [Post-v1 options](docs/decisions/0059-post-v1-evaluation.md) — candidates under consideration, not commitments, and how they are evaluated

## How development proceeds

GitHub Issues are the source of truth for implementation tasks and bugs, and
pull requests for implementation results and verification records. As a rule, each issue produces one verifiable result
and one pull request. See the [development workflow](docs/development/workflow.md)
for details.

**Every planned phase (P0 through P15) is complete.** From here on, features are not
added by working down a plan. When a concrete bug report or a request grounded in
actual use arrives, an issue is opened and judged on its own
(see [ADR 0059](docs/decisions/0059-post-v1-evaluation.md)).

## License

[Apache License 2.0](LICENSE)

Copyright 2026 Pocket (@toshtag)

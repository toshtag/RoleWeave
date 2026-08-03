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
[the verification status](docs/known-gaps.md).

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

Downloaded `.deb` and `.gem` files live in BuildKit cache mounts. They are not
kept in the image, and the next build does not fetch them again.

To rebuild the base image and dependencies without the cache, run the following.
This is used for re-verifying the foundation and is not needed for regular development.

```bash
docker compose build --no-cache app
```

`--no-cache` also empties the cache mounts, so this path always refetches.

Build cache accumulates on the Docker side. To reclaim the space, run the
following. **This also removes cache belonging to other projects.**

```bash
docker builder prune
```

### Initial setup

```bash
docker compose run --rm app bin/setup
```

`bin/setup` does the following:

- Checks the Ruby dependencies and prepares them only when they are missing
- Prepares the development database
- Clears old logs and temporary files, including the `log/*.log.0` files Rails
  rotates every 100 MB

It does not start the development server; starting it is the responsibility of
`docker compose up`.

`bin/setup` does not drop or reset an existing development database. If pending
migrations exist, it applies them, so the database schema or data may change as
defined by those migrations.

When rerun against the same code and migration state, it preserves the existing
database state, leaves tracked files unchanged, and converges on the same
development-ready state.

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

### Granting operator privileges

Grant operator privileges to the person running this server. There is no screen for this.

```bash
docker compose run --rm app bin/rails "roleweave:operator:grant[you@example.com]"
```

Use `revoke` to take them away.

```bash
docker compose run --rm app bin/rails "roleweave:operator:revoke[you@example.com]"
```

Operators can only list every organization and restore an organization's administrator.
See [`docs/decisions/0015-operator-role.md`](docs/decisions/0015-operator-role.md) for details.

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

### Run the load test

Create the data first, then measure. No external load tool is required.

```bash
docker compose run --rm app bin/rails "roleweave:load:seed[5000]"
```

```bash
docker compose run --rm app bin/rails "roleweave:load:measure[20]"
```

Remove the data once you are done measuring.

```bash
docker compose run --rm app bin/rails roleweave:load:clean
```

Measured values are in
[`docs/operations/load-test-results.md`](docs/operations/load-test-results.md) and
the estimates in
[`docs/operations/capacity-model.md`](docs/operations/capacity-model.md).

### Apply the retention policy

This deletes and anonymizes data past its retention period. It is never run
automatically.

```bash
docker compose run --rm app bin/rails roleweave:retention:report
```

Check the counts with `report` first, then apply.

```bash
docker compose run --rm app bin/rails roleweave:retention:apply
```

See [`docs/decisions/0046-data-retention.md`](docs/decisions/0046-data-retention.md)
for what is kept and for how long.

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
- An environment with Bash and common Unix command-line tools
  (such as macOS, Linux, WSL, or Git Bash)

The full verification is a Bash script and uses tools such as `awk`, `grep`, `find`,
`mktemp`, and `tr`. Running it from native PowerShell or Command Prompt alone is out
of scope. This requirement applies only to the full verification, not to regular
Docker-based development.

```bash
bundle install
bin/verify --full
```

The full verification checks that `Gemfile` and `Gemfile.lock` are unchanged in the
working tree. Commit them first if dependencies have been updated.

## Documentation

The documents below are internal design documents and are written in Japanese, as
described above. Setup and usage documentation will be provided in both languages.

- [Using it as a candidate](docs/guides/candidate.md) — from sign-up to applying and leaving
- [Using it as an organization](docs/guides/organization.md) — organizations, job postings, hiring
- [Using it as an operator](docs/guides/operator.md) — for whoever runs the server
- [Architecture overview](docs/architecture.md) — how the pieces fit together
- [Contributing](CONTRIBUTING.md) — how work proceeds and what verification is required
- [Changelog](CHANGELOG.md) — what each version contains and its known limitations
- [Release procedure](docs/development/release.md) — how versions are assigned and checked before release
- [Development principles](docs/principles.md) — how planning, implementation, and code decisions are made
- [Post-v1 options](docs/decisions/0059-post-v1-evaluation.md) — candidates under consideration, not commitments, and how they are evaluated
- [Language and naming policy](docs/development/language-policy.md) — when Japanese and English are used
- [Development workflow](docs/development/workflow.md) — responsibilities of issues, PRs, verification, and ADRs
- [File storage](docs/operations/file-storage.md) — where attachments live and how they are handled when self-hosting
- [Reverse proxy assumptions](docs/operations/reverse-proxy.md) — what the front proxy must provide, and what stops working without it
- [Verification status](docs/known-gaps.md) — what is met and what is not
- [Threat model](docs/threat-model.md) — what is defended against and what is accepted
- [Security policy](SECURITY.md) — where to report a problem
- [Backup and restore](docs/operations/backup-and-restore.md) — the database and the attachments are handled as a pair
- [Load test results](docs/operations/load-test-results.md) — measured values only
- [Capacity model](docs/operations/capacity-model.md) — estimates with the assumptions stated

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

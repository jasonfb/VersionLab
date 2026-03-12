# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VersionLab is a Rails 8.1 + React 19 full-stack application for AI-powered email template versioning and A/B testing. It uses Vite 5 for frontend bundling and PostgreSQL. The React SPA lives inside the Rails app at `app/frontend/` and mounts into the Rails view at a `#VersionLabApp` div.

## Development Commands

```bash
bin/dev                    # Start Vite + Rails together via Foreman (recommended, port 3100)
bin/rails s                # Rails server only (port 3000)
bin/vite dev               # Vite dev server only (port 3036)
```

Note: Do not start the dev server. Let the operator start & stop it directly; prompt them to do so when testing is needed.

### CSS

```bash
yarn build:css             # Compile and prefix Sass stylesheets
yarn watch:css             # Watch SCSS changes and rebuild
```

### Testing

RSpec is the primary test framework. `bin/rails test` runs Minitest (legacy).

```bash
bin/rspec                              # Run all RSpec tests
bin/rspec spec/path/to/test_spec.rb   # Run a single test file
bin/rails test:system                 # Run system tests (Capybara + Selenium)
```

### Linting & Security

```bash
bin/rubocop                # Ruby linting (rubocop-rails-omakase style)
bin/brakeman               # Rails security scanner
bin/bundler-audit          # Gem vulnerability check
bin/ci                     # Full CI suite locally
```

### Setup

```bash
bin/setup                  # Full setup: bundle install, db:prepare, etc.
```

### Local

For local development, always use `localhost:3100` (not `127.0.0.1`).

Local test account: `jason@heliosdev.shop` / `password`

## Testing Approach

- RSpec with FactoryBot for test data
- VCR cassettes for external API (OpenAI) testing
- Capybara + Selenium for system/integration tests
- SimpleCov for coverage reporting

## Database Considerations

- PostgreSQL with UUID primary keys — do not use Rails `references`; use UUIDs for foreign keys
- Paranoia gem for soft deletes on critical models
- When creating enums, always use a Postgres Enum-backed field; do not define enums against string columns in models
- Data-only migrations: `bin/rails g data_migration XyzName` (not schema migrations)
- Do not use `seeds.rb`

## Architecture

### Route Zones

- `/app/*` — React SPA (client-facing). Once on `/app`, React Router handles all navigation. No links back into the Rails routing layer except via full page navigations.
- `/admin/*` — Administrator dashboard; Turbo Rails
- `/` — Marketing pages; Turbo Rails
- `/api/*` — JSON API endpoints consumed by the React frontend

### Frontend

React entry point is `app/frontend/entrypoints/client_app.js`, which renders `App.jsx`. Vite config is split: `vite.config.mts` (bundler) and `config/vite.json` (Rails integration, source dir, ports). Layout uses `vite_javascript_tag` / `vite_stylesheet_tag` helpers. Propshaft handles Rails assets; Vite handles JS/React.

### Backend

Standard Rails MVC. API controllers live under `app/controllers/api/` and return JSON. Authorization uses Pundit policies in `app/policies/`.

### Multi-Tenancy

`Account` is the top-level tenant. Users belong to accounts through `AccountUsers`. Projects belong to Accounts; EmailTemplates belong to Projects. All API controllers scope data to the current account.

### Core Feature: AI Merges

`AiMergeService` (`app/services/ai_merge_service.rb`) calls the OpenAI API to generate email copy variants. A `Merge` job runs against an `EmailTemplate`, targeting one or more `Audience` segments, and produces `MergeVersion` records with AI-generated `MergeVersionVariable` values. Merge state: `setup → pending → merged` (also `regenerating`). MergeVersion state: `generating → active` (or `rejected`).

### Infrastructure

- **Database**: PostgreSQL. Rails 8 Solid stack — Solid Cache, Solid Queue, Solid Cable — each with their own schema files in `db/`.
- **Background jobs**: Solid Queue via Puma plugin (`config/puma.rb`)
- **Package manager**: Yarn
- **Ruby**: 3.4.7 (`.ruby-version`), **Node**: 24.8.0 (`.node-version`)

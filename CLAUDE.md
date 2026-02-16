# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VersionLab is a Rails 8.1 + React 19 full-stack application using Vite 5 for frontend bundling and PostgreSQL for the database. The React frontend lives inside the Rails app at `app/frontend/` and mounts into the Rails view at a `#VersionLabApp` div.

## Development Commands

```bash
bin/dev                    # Start Vite + Rails together via Foreman (recommended)
bin/rails s                # Rails server only (port 3000)
bin/vite dev               # Vite dev server only (port 3036)
```

### Testing

```bash
bin/rails test             # Run all unit/integration tests (Minitest)
bin/rails test test/models/foo_test.rb        # Run a single test file
bin/rails test test/models/foo_test.rb:42     # Run a single test by line number
bin/rails test:system      # Run system tests (Capybara + Selenium)
```

### Database
- don't use rails References. instead use uuids for foreign keys

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
For local development, always use localhost:3100 to access the site (not 127.0.0.1)

A good local username is jason@heliosdev.shop with password "password"


## Architecture

- **Rails backend**: Standard Rails MVC. Routes in `config/routes.rb`, root points to `WelcomeController#index`.
- **React frontend**: Lives in `app/frontend/`. Entry point is `app/frontend/entrypoints/application.js` which renders `App.jsx` into the DOM. Vite config is split between `vite.config.mts` (bundler) and `config/vite.json` (Rails integration, source dir, ports).
- **Asset pipeline**: Propshaft for Rails assets, Vite for JS/React bundling. Layout uses `vite_javascript_tag` and `vite_stylesheet_tag` helpers.
- **Database**: PostgreSQL. Uses Rails 8 Solid stack — Solid Cache, Solid Queue, and Solid Cable — each with their own schema files in `db/`.
- **Background jobs**: Solid Queue via Puma plugin (configured in `config/puma.rb`).
- **Package manager**: Yarn for Node dependencies.
- **Ruby version**: 3.4.7 (.ruby-version), Node version: 24.8.0 (.node-version).


/app 
    the client facing frontend app implemented fully in React. once the client lands on `/app` we will use React routing for all page navigations.


/admin
    administrator dashboard; uses Turbo Rails

/ (homepage)
    marketing pages; uses Turbo rails


Except for links from the Rails app into the app, the client app will not really have links from itself back into the rails app. 
if it does, those links will work outside of the React routing. 

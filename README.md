# Phoenix Installer

An alternative to `mix phx.new` that installs Phoenix into any Elixir project — new or existing — using [Igniter](https://hex.pm/packages/igniter) for AST-aware code generation.

Instead of generating a project from a template, phx_install composes individual installer tasks that each add a specific feature (endpoint, router, LiveView, etc.). Each task manipulates your project's actual AST, so it can safely merge into existing code rather than overwriting it.

## Quick Start

### Existing Project

Install the default Phoenix stack (LiveView, assets, Gettext, LiveDashboard) into your project:

```bash
mix igniter.install phx_install
```

See [Options](#options) for flags to customise what gets installed.

To add the dependency without running the installer, and then explore the available tasks:

```bash
mix igniter.add phx_install
mix help phx.install
```

### New Project

Create a new Elixir application with Phoenix installed:

```bash
mix igniter.new my_app --install phx_install
```

## How It Differs from `mix phx.new`

`mix phx.new` is the standard Phoenix generator — it creates a complete project from a template and is the right choice for most greenfield apps. phx_install takes a different approach that's useful when you want to:

- **Add Phoenix to an existing Elixir project** — phx_install merges Phoenix into your current code rather than starting from a fresh project.
- **Install features incrementally** — start with an API-only app and add LiveView later with `mix phx.install.live`.
- **Run it again safely** — every task is idempotent. Running it twice won't duplicate code or overwrite your changes.

## Options

By default, `mix phx.install` sets up a full Phoenix application with LiveView, assets, Gettext, and LiveDashboard. Use flags to opt out:

```bash
# API-only (no LiveView, no assets)
mix phx.install --no-live --no-assets

# Skip internationalisation
mix phx.install --no-gettext

# Skip LiveDashboard
mix phx.install --no-dashboard
```

Database and email support are separate tasks you can add at any time:

```bash
# Ecto with PostgreSQL (default), MySQL, or SQLite
mix phx.install.ecto
mix phx.install.ecto --adapter mysql
mix phx.install.ecto --adapter sqlite

# Swoosh email
mix phx.install.mailer
```

## Individual Tasks

Each feature is a standalone task. The orchestrator (`mix phx.install`) composes them, but you can also run them independently:

| Task                    | Description                                            |
|-------------------------|--------------------------------------------------------|
| `phx.install.core`      | Application module, config files, base dependencies    |
| `phx.install.endpoint`  | Phoenix.Endpoint, Telemetry, web module                |
| `phx.install.router`    | Router with pipelines, error handling                  |
| `phx.install.html`      | HTML components, layouts, error pages                  |
| `phx.install.live`      | LiveView socket, helpers, and macros (composes `html`) |
| `phx.install.assets`    | esbuild and Tailwind CSS                               |
| `phx.install.gettext`   | Internationalisation with Gettext                      |
| `phx.install.dashboard` | Phoenix LiveDashboard (dev only)                       |
| `phx.install.ecto`      | Ecto database support with Repo                        |
| `phx.install.mailer`    | Swoosh email support                                   |

## Development

```bash
# Run tests
mix test

# Run acceptance tests (generates phx.new projects for comparison)
mix test --include acceptance
```

## Licence

Apache-2.0

---

[![Alembic](logos/alembic.svg)](https://alembic.com.au)

Proudly written and maintained by the team at [Alembic](https://alembic.com.au) for the Ash community.

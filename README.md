# Phoenix Installer

An alternative to `mix phx.new` that installs Phoenix into any Elixir project — new or existing — using [Igniter](https://hex.pm/packages/igniter) for AST-aware code generation.

Instead of generating a project from a template, phx_install composes individual installer tasks that each add a specific feature (endpoint, router, LiveView, etc.). Each task manipulates your project's actual AST, so it can safely merge into existing code rather than overwriting it.

## Quick Start

### New Project

```bash
mix igniter.new my_app --install phx_install --only dev
```

### Existing Project

Add the dependency:

```elixir
def deps do
  [
    {:phx_install, "~> 0.1", only: :dev, runtime: false}
  ]
end
```

Then run:

```bash
mix deps.get
mix phx.install
```

## Why Not `mix phx.new`?

`mix phx.new` is a template-based generator that creates an entire project from scratch. That works well for greenfield apps, but falls short when you want to:

- **Add Phoenix to an existing Elixir project** — phx_install merges Phoenix into your current code rather than requiring a fresh project.
- **Install features incrementally** — start with an API-only app and add LiveView later with `mix phx.install.live`, without re-running the full generator.
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

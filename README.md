# PhxInstall

Igniter-based installers for Phoenix Framework. Add Phoenix to any Elixir project with a single command.

## Installation

### New Project

Create a new Elixir project with Phoenix installed:

```bash
mix igniter.new my_app --install phx_install
```

### Existing Project

Add `phx_install` to your dependencies:

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

## Usage

### Full Installation

```bash
mix phx.install
```

This installs a complete Phoenix application with:
- Phoenix core (endpoint, router, telemetry)
- LiveView with socket and components
- Asset pipeline (esbuild + Tailwind CSS)
- Gettext for internationalisation
- LiveDashboard for development monitoring

### Options

```bash
# API-only (no LiveView, no assets)
mix phx.install --no-live --no-assets

# Skip LiveDashboard
mix phx.install --no-dashboard

# Skip Gettext
mix phx.install --no-gettext
```

### Database Support

Add Ecto with PostgreSQL (default):

```bash
mix phx.install.ecto
```

Or with a different adapter:

```bash
mix phx.install.ecto --adapter mysql
mix phx.install.ecto --adapter sqlite
```

### Email Support

Add Swoosh for email:

```bash
mix phx.install.mailer
```

## Individual Tasks

Each component can be installed separately:

| Task | Description |
|------|-------------|
| `phx.install.core` | Application module, config files, base dependencies |
| `phx.install.endpoint` | Phoenix.Endpoint, Telemetry, web module |
| `phx.install.router` | Router with browser/API pipelines, error handling |
| `phx.install.html` | HTML components, layouts, error pages |
| `phx.install.live` | LiveView socket, helpers, and macros |
| `phx.install.assets` | esbuild, Tailwind CSS, static assets |
| `phx.install.gettext` | Internationalisation with Gettext |
| `phx.install.dashboard` | Phoenix LiveDashboard (dev only) |
| `phx.install.ecto` | Ecto database support with Repo |
| `phx.install.mailer` | Swoosh email support |

## What Gets Created

### Directory Structure

```
lib/
├── my_app/
│   ├── application.ex      # OTP Application
│   ├── repo.ex             # Ecto Repo (with --ecto)
│   └── mailer.ex           # Swoosh Mailer (with --mailer)
└── my_app_web/
    ├── endpoint.ex         # Phoenix.Endpoint
    ├── router.ex           # Phoenix.Router
    ├── telemetry.ex        # Telemetry supervisor
    ├── gettext.ex          # Gettext backend
    ├── components/
    │   ├── core_components.ex
    │   └── layouts/
    │       ├── app.html.heex
    │       └── root.html.heex
    └── controllers/
        ├── error_html.ex
        └── error_json.ex

config/
├── config.exs              # Base configuration
├── dev.exs                 # Development config
├── test.exs                # Test config
├── prod.exs                # Production config
└── runtime.exs             # Runtime config

assets/
├── js/app.js               # JavaScript entry point
├── css/app.css             # Tailwind CSS entry point
└── vendor/
    └── topbar.js           # LiveView progress indicator

priv/
├── static/                 # Static assets
├── gettext/                # Translation files
└── repo/                   # Database migrations & seeds
```

### Dependencies Added

**Always:**
- `phoenix`
- `phoenix_html`
- `jason`
- `bandit`
- `dns_cluster`

**With LiveView (default):**
- `phoenix_live_view`

**With Assets (default):**
- `esbuild`
- `tailwind`

**With Dashboard (default):**
- `phoenix_live_dashboard`

**With Gettext (default):**
- `gettext`

**With Ecto:**
- `ecto_sql`
- `postgrex` / `myxql` / `ecto_sqlite3`

**With Mailer:**
- `swoosh`
- `finch`

## Differences from `mix phx.new`

This project aims to produce equivalent output to `mix phx.new`, but uses Igniter for composable, incremental installation. Key differences:

- **Composable**: Install only what you need
- **Incremental**: Add features to existing projects
- **Idempotent**: Safe to run multiple times

## Development

```bash
# Run tests
mix test

# Run acceptance tests (compares against phx.new output)
mix test --include acceptance
```

## Licence

MIT

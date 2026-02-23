# CLAUDE.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Project Overview

**phx_install** is an Igniter-based installer library for Phoenix Framework. It replaces `mix phx.new` with composable, incremental Mix tasks that can install Phoenix into new or existing Elixir projects. Each task uses Igniter's AST manipulation (via Sourceror) to create/update modules and config files idempotently.

## Commands

```bash
# Run all tests (excludes acceptance tests by default)
mix test

# Run a single test file
mix test test/mix/tasks/phx/install/core_test.exs

# Run a specific test by line number
mix test test/mix/tasks/phx/install/core_test.exs:7

# Run acceptance tests (slow - generates real phx.new projects for comparison)
mix test test/acceptance --include acceptance

# Format code
mix format
```

## Architecture

### Task Composition

The main orchestrator `Mix.Tasks.Phx.Install` (`lib/mix/tasks/phx/install.ex`) composes individual installer tasks. Core tasks always run; optional tasks are controlled by flags (`--live`, `--assets`, `--gettext`, `--dashboard`).

**Composition order:** core → endpoint → router → (optional: live, gettext, assets, dashboard)

### Task Pattern

Every task in `lib/mix/tasks/phx/install/` follows the same structure:

1. `use Igniter.Mix.Task`
2. `info/2` returns `%Igniter.Mix.Task.Info{}` with schema, defaults, and composed tasks
3. `igniter/1` builds an Igniter pipeline that creates/updates modules, config files, and dependencies

Tasks are idempotent — they use `find_and_update_or_create_module/4` and `create_new_file/3` with `on_exists: :skip`.

### Task Dependency Graph

- `phx.install.live` composes `phx.install.html`
- `phx.install.dashboard` requires live (guarded by `opts[:live] && opts[:dashboard]`)
- `phx.install.html` is not directly invoked by the orchestrator — it's pulled in via `live`

### Entry Point for Package Installation

`lib/mix/tasks/phx_install.install.ex` makes this package installable via `mix igniter.install phx_install`.

### Testing Approach

Unit tests use `Igniter.Test` helpers:
- `test_project()` / `test_project(app_name: :my_app)` — creates an in-memory test project
- `Igniter.compose_task/2` — applies a task to the test project
- `apply_igniter!/1` — materialises changes so you can inspect file contents
- `assert_has_patch/3`, `assert_creates/2`, `assert_unchanged/1` — assertion helpers

Acceptance tests (`test/acceptance/`, tagged `:acceptance`) generate real `phx.new` projects and verify our installers target the same file structure and dependencies.

### Key Igniter APIs Used

- `Igniter.Project.Module.find_and_update_or_create_module/4` — create or update Elixir modules
- `Igniter.Project.Config.configure/5` — update config files
- `Igniter.Project.Deps.add_dep/2` — add mix dependencies
- `Igniter.Project.Formatter.import_dep/1` — add formatter imports
- `Igniter.create_or_update_elixir_file/3` — create/update arbitrary .ex files
- `Igniter.create_new_file/3` — create new files (non-Elixir or templates)
- `Igniter.compose_task/2` — compose another Igniter task into the pipeline

### Module Naming Convention

Generated modules derive from the app name: app `my_app` produces `MyApp` (context modules) and `MyAppWeb` (web modules like Endpoint, Router, Telemetry).

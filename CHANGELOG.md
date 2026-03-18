# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.1.1](https://github.com/team-alembic/phx_install/compare/v0.1.0...v0.1.1) (2026-03-18)




### Improvements:

* use `add_new_child` to add supervision children individually by [@beam-bots](https://github.com/beam-bots)

## [v0.1.0](https://github.com/team-alembic/phx_install/compare/v0.1.0...v0.1.0) (2026-02-24)




### Features:

* wire ecto, mailer, and `--all` flag into orchestrator by James Harton

* add acceptance tests for phx.new reference validation by James Harton

* add `phx.install.mailer` task for email support by James Harton

* add `phx.install.ecto` task for database support by James Harton

* add `phx.install.dashboard` task for LiveDashboard by James Harton

* add `phx.install.gettext` task for i18n support by James Harton

* add `phx.install.assets` task for esbuild and Tailwind by James Harton

* add `phx.install.live` task for LiveView support by James Harton

* add `phx.install.html` task for HTML rendering support by James Harton

* add phx_install.install entry point by James Harton

* add phx.install orchestrator task by James Harton

* add phx.install.router task by James Harton

* add phx.install.endpoint task by James Harton

* add phx.install.core task by James Harton

### Improvements:

* add `--remove-after-install` flag, remove redundant `--all` flag, fix dialyzer by James Harton

* fixes and new page task across installer tasks by James Harton

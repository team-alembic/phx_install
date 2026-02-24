import Config

if config_env() in [:dev, :test] do
  config :git_ops,
    mix_project: Mix.Project.get!(),
    types: [tidbit: [hidden?: true], important: [header: "Important Changes"]],
    github_handle_lookup?: true,
    repository_url: "https://github.com/team-alembic/phx_install",
    version_tag_prefix: "v",
    manage_mix_version?: true,
    manage_readme_version: true
end

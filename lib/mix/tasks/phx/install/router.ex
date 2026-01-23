defmodule Mix.Tasks.Phx.Install.Router do
  @moduledoc """
  Installs Phoenix Router with pipelines and error handling.

  This task sets up:
  - `lib/<app>_web/router.ex` - Router with `:api` pipeline
  - `lib/<app>_web/controllers/error_json.ex` - JSON error rendering
  - `test/support/conn_case.ex` - Test case for controller tests

  ## Usage

      mix phx.install.router

  This task is typically called by `mix phx.install` rather than directly.

  Note: The `:browser` pipeline is added by `phx.install.html` (HTML support).
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.router"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    endpoint_module = Module.concat(web_module, Endpoint)

    igniter
    |> create_router(web_module)
    |> create_error_json(web_module)
    |> create_conn_case(web_module, endpoint_module)
  end

  defp create_router(igniter, web_module) do
    router_module = Module.concat(web_module, Router)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      router_module,
      """
      use #{inspect(web_module)}, :router

      pipeline :api do
        plug :accepts, ["json"]
      end

      scope "/api", #{inspect(web_module)} do
        pipe_through :api
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_error_json(igniter, web_module) do
    error_json_module = Module.concat(web_module, ErrorJSON)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      error_json_module,
      """
      @moduledoc \"\"\"
      This module is invoked by your endpoint in case of errors on JSON requests.

      See config/config.exs.
      \"\"\"

      def render(template, _assigns) do
        %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_conn_case(igniter, web_module, endpoint_module) do
    conn_case_module = Module.concat(web_module, ConnCase)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      conn_case_module,
      """
      @moduledoc \"\"\"
      This module defines the test case to be used by
      tests that require setting up a connection.

      Such tests rely on `Phoenix.ConnTest` and also
      import other functionality to make it easier
      to build common data structures and query the data layer.
      \"\"\"

      use ExUnit.CaseTemplate

      using do
        quote do
          @endpoint #{inspect(endpoint_module)}

          use #{inspect(web_module)}, :verified_routes

          import Plug.Conn
          import Phoenix.ConnTest
          import #{inspect(conn_case_module)}
        end
      end

      setup _tags do
        {:ok, conn: Phoenix.ConnTest.build_conn()}
      end
      """,
      fn zipper -> {:ok, zipper} end
    )
  end
end

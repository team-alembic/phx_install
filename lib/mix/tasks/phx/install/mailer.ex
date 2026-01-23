defmodule Mix.Tasks.Phx.Install.Mailer do
  @moduledoc """
  Adds Swoosh mailer support to a Phoenix application.

  This task sets up:
  - `swoosh` dependency
  - `lib/<app>/mailer.ex` - Mailer module
  - Mailer configuration in config.exs (Local adapter for dev)
  - Test adapter configuration in test.exs
  - Production configuration in prod.exs
  - `/dev/mailbox` route for viewing emails in development

  ## Usage

      mix phx.install.mailer

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.mailer"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    app_module =
      Igniter.Project.Application.app_module(igniter) ||
        Module.concat([Macro.camelize(to_string(app_name))])

    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    mailer_module = Module.concat(app_module, Mailer)
    router_module = Module.concat(web_module, Router)

    igniter
    |> Igniter.Project.Deps.add_dep({:swoosh, "~> 1.5"})
    |> create_mailer_module(app_name, mailer_module)
    |> configure_mailer(app_name, mailer_module)
    |> configure_test_mailer(app_name, mailer_module)
    |> configure_dev_swoosh()
    |> configure_prod_swoosh()
    |> add_mailbox_route(app_name, router_module)
  end

  defp create_mailer_module(igniter, app_name, mailer_module) do
    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      mailer_module,
      """
      use Swoosh.Mailer, otp_app: #{inspect(app_name)}
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_mailer(igniter, app_name, mailer_module) do
    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [mailer_module, :adapter],
      Swoosh.Adapters.Local,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_test_mailer(igniter, app_name, mailer_module) do
    igniter
    |> Igniter.Project.Config.configure(
      "test.exs",
      app_name,
      [mailer_module, :adapter],
      Swoosh.Adapters.Test,
      updater: fn zipper -> {:ok, zipper} end
    )
    |> Igniter.Project.Config.configure(
      "test.exs",
      :swoosh,
      [:api_client],
      false,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_dev_swoosh(igniter) do
    Igniter.Project.Config.configure(
      igniter,
      "dev.exs",
      :swoosh,
      [:api_client],
      false,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp configure_prod_swoosh(igniter) do
    igniter
    |> Igniter.Project.Config.configure(
      "prod.exs",
      :swoosh,
      [:api_client],
      Swoosh.ApiClient.Req,
      updater: fn zipper -> {:ok, zipper} end
    )
    |> Igniter.Project.Config.configure(
      "prod.exs",
      :swoosh,
      [:local],
      false,
      updater: fn zipper -> {:ok, zipper} end
    )
  end

  defp add_mailbox_route(igniter, app_name, router_module) do
    mailbox_code = ~s|forward "/mailbox", Plug.Swoosh.MailboxPreview|

    Igniter.Project.Module.find_and_update_module!(igniter, router_module, fn zipper ->
      case Igniter.Code.Common.move_to(zipper, fn z ->
             node = Sourceror.Zipper.node(z)

             case node do
               {:forward, _, [{:__block__, _, ["/mailbox"]} | _]} -> true
               {:forward, _, ["/mailbox" | _]} -> true
               _ -> false
             end
           end) do
        {:ok, _} ->
          {:ok, zipper}

        :error ->
          case Igniter.Code.Common.move_to(zipper, fn z ->
                 node = Sourceror.Zipper.node(z)

                 case node do
                   {:if, _, [{:compile_env, _, [_, ^app_name, :dev_routes | _]} | _]} -> true
                   {:if, _, [{:compile_env, _, [:erlang, :binary_to_atom, [^app_name | _], _]} | _]} -> true
                   _ -> false
                 end
               end) do
            {:ok, dev_routes_zipper} ->
              case Igniter.Code.Common.move_to_do_block(dev_routes_zipper) do
                {:ok, do_block_zipper} ->
                  case Igniter.Code.Function.move_to_function_call_in_current_scope(
                         do_block_zipper,
                         :scope,
                         [1, 2]
                       ) do
                    {:ok, scope_zipper} ->
                      case Igniter.Code.Common.move_to_do_block(scope_zipper) do
                        {:ok, scope_do_zipper} ->
                          {:ok, Igniter.Code.Common.add_code(scope_do_zipper, mailbox_code)}

                        :error ->
                          {:ok, Igniter.Code.Common.add_code(do_block_zipper, mailbox_code)}
                      end

                    :error ->
                      {:ok, Igniter.Code.Common.add_code(do_block_zipper, mailbox_code)}
                  end

                :error ->
                  {:warning,
                   Igniter.Util.Warning.formatted_warning(
                     "Could not find dev_routes do block. Please add manually:",
                     mailbox_code
                   )}
              end

            :error ->
              dev_routes_code = """
              if Application.compile_env(#{inspect(app_name)}, :dev_routes) do
                scope "/dev" do
                  pipe_through :browser

                  #{mailbox_code}
                end
              end
              """

              {:ok, Igniter.Code.Common.add_code(zipper, dev_routes_code)}
          end
      end
    end)
  end
end

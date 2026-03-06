defmodule Mix.Tasks.Phx.Install.Gettext do
  @shortdoc "Adds Gettext internationalisation support"
  @moduledoc """
  Adds Gettext (i18n) support to a Phoenix application.

  This task sets up:
  - `gettext` dependency
  - `lib/<app>_web/gettext.ex` - Gettext backend module
  - `priv/gettext/errors.pot` - Error message template
  - `priv/gettext/en/LC_MESSAGES/errors.po` - English translations
  - Imports Gettext in the web module
  - Adds gettext to formatter imports

  ## Usage

      mix phx.install.gettext

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.gettext",
      adds_deps: [{:gettext, "~> 0.26"}]
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    web_module = Igniter.Libs.Phoenix.web_module(igniter)

    igniter
    |> Igniter.Project.Deps.add_dep({:gettext, "~> 0.26"})
    |> create_gettext_module(app_name, web_module)
    |> create_errors_pot()
    |> create_errors_po()
    |> add_gettext_to_web_module(web_module)
    |> add_gettext_to_formatter()
  end

  defp create_gettext_module(igniter, app_name, web_module) do
    gettext_module = Module.concat(web_module, Gettext)

    Igniter.Project.Module.find_and_update_or_create_module(
      igniter,
      gettext_module,
      """
      @moduledoc \"""
      A module providing Internationalization with a gettext-based API.

      By using [Gettext](https://hexdocs.pm/gettext), your module compiles translations
      that you can use in your application. To use this Gettext backend module,
      call `use Gettext` and pass it as an option:

          use Gettext, backend: #{inspect(gettext_module)}

          # Simple translation
          gettext("Here is the string to translate")

          # Plural translation
          ngettext("Here is the string to translate",
                   "Here are the strings to translate",
                   3)

          # Domain-based translation
          dgettext("errors", "Here is the error message to translate")

      See the [Gettext Docs](https://hexdocs.pm/gettext) for detailed usage.
      \"""
      use Gettext.Backend, otp_app: #{inspect(app_name)}
      """,
      fn zipper -> {:ok, zipper} end
    )
  end

  defp create_errors_pot(igniter) do
    content = """
    ## This is a PO Template file.
    ##
    ## `msgid`s here are often extracted from source code.
    ## Add new translations manually only if they're dynamic
    ## translations that can't be statically extracted.
    ##
    ## Run `mix gettext.extract` to bring this file up to
    ## date. Leave `msgstr`s empty as changing them here has no
    ## effect: edit them in PO (`.po`) files instead.
    """

    Igniter.create_new_file(igniter, "priv/gettext/errors.pot", content, on_exists: :skip)
  end

  defp create_errors_po(igniter) do
    content = """
    ## `msgid`s in this file come from POT (.pot) files.
    ##
    ## Do not add, change, or remove `msgid`s manually here as
    ## they're tied to the ones in the corresponding POT file
    ## (with the same domain).
    ##
    ## Use `mix gettext.extract --merge` or `mix gettext.merge`
    ## to merge POT files into PO files.
    msgid ""
    msgstr ""
    "Language: en\\n"
    """

    Igniter.create_new_file(
      igniter,
      "priv/gettext/en/LC_MESSAGES/errors.po",
      content,
      on_exists: :skip
    )
  end

  defp add_gettext_to_web_module(igniter, web_module) do
    gettext_module = Module.concat(web_module, Gettext)

    Igniter.Project.Module.find_and_update_module!(igniter, web_module, fn zipper ->
      with :error <- Igniter.Code.Function.move_to_defp(zipper, :html_helpers, 0),
           :error <- Igniter.Code.Function.move_to_def(zipper, :controller, 0) do
        {:ok, zipper}
      else
        {:ok, target_zipper} ->
          add_gettext_import_to_function(target_zipper, gettext_module)
      end
    end)
  end

  defp add_gettext_import_to_function(zipper, gettext_module) do
    import_code = "use Gettext, backend: #{inspect(gettext_module)}"

    with {:ok, quote_body_zipper} <- Igniter.Code.Common.move_to_do_block(zipper),
         :error <-
           Igniter.Code.Function.move_to_function_call_in_current_scope(
             quote_body_zipper,
             :use,
             [1, 2],
             &Igniter.Code.Function.argument_equals?(&1, 0, Gettext)
           ) do
      {:ok, Igniter.Code.Common.add_code(quote_body_zipper, import_code)}
    else
      {:ok, _} ->
        {:ok, zipper}

      :error ->
        {:ok, Igniter.Code.Common.add_code(zipper, import_code)}
    end
  end

  defp add_gettext_to_formatter(igniter) do
    Igniter.Project.Formatter.import_dep(igniter, :gettext)
  end
end

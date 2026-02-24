defmodule Mix.Tasks.Phx.Install.Components do
  @moduledoc """
  Adds data display components required by Phoenix generators.

  This task adds the following components to CoreComponents:
  - `header/1` — page header with title, subtitle, and actions
  - `table/1` — data table with streaming support
  - `list/1` — data list with title/content pairs

  These components are required by `phx.gen.html` and `phx.gen.live`.

  ## Usage

      mix phx.install.components

  ## Prerequisites

  This task requires LiveView to be installed (table/1 references
  `Phoenix.LiveView.LiveStream`). It is typically called by
  `mix phx.install` with the `--live` flag (default: true).

  This task is typically called by `mix phx.install` rather than directly.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :phoenix,
      example: "mix phx.install.components"
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    web_module = Igniter.Libs.Phoenix.web_module(igniter)
    core_components_module = Module.concat(web_module, CoreComponents)

    igniter
    |> add_header_component(core_components_module)
    |> add_table_component(core_components_module)
    |> add_list_component(core_components_module)
  end

  defp add_header_component(igniter, core_components_module) do
    header_code = """
    @doc \"\"\"
    Renders a header with title.
    \"\"\"
    slot :inner_block, required: true
    slot :subtitle
    slot :actions

    def header(assigns) do
      ~H\"\"\"
      <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
        <div>
          <h1 class="text-lg font-semibold leading-8">
            {render_slot(@inner_block)}
          </h1>
          <p :if={@subtitle != []} class="text-sm text-base-content/70">
            {render_slot(@subtitle)}
          </p>
        </div>
        <div class="flex-none">{render_slot(@actions)}</div>
      </header>
      \"\"\"
    end
    """

    add_component_if_missing(igniter, core_components_module, :header, 1, header_code)
  end

  defp add_table_component(igniter, core_components_module) do
    table_code = """
    @doc \"\"\"
    Renders a table with generic styling.

    ## Examples

        <.table id="users" rows={@users}>
          <:col :let={user} label="id">{user.id}</:col>
          <:col :let={user} label="username">{user.username}</:col>
        </.table>
    \"\"\"
    attr :id, :string, required: true
    attr :rows, :list, required: true
    attr :row_id, :any, default: nil, doc: "the function for generating the row id"
    attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

    attr :row_item, :any,
      default: &Function.identity/1,
      doc: "the function for mapping each row before calling the :col and :action slots"

    slot :col, required: true do
      attr :label, :string
    end

    slot :action, doc: "the slot for showing user actions in the last table column"

    def table(assigns) do
      assigns =
        with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
          assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
        end

      ~H\"\"\"
      <table class="table table-zebra">
        <thead>
          <tr>
            <th :for={col <- @col}>{col[:label]}</th>
            <th :if={@action != []}>
              <span class="sr-only">Actions</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={@row_click && "hover:cursor-pointer"}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="w-0 font-semibold">
              <div class="flex gap-4">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      \"\"\"
    end
    """

    add_component_if_missing(igniter, core_components_module, :table, 1, table_code)
  end

  defp add_list_component(igniter, core_components_module) do
    list_code = """
    @doc \"\"\"
    Renders a data list.

    ## Examples

        <.list>
          <:item title="Title">{@post.title}</:item>
          <:item title="Views">{@post.views}</:item>
        </.list>
    \"\"\"
    slot :item, required: true do
      attr :title, :string, required: true
    end

    def list(assigns) do
      ~H\"\"\"
      <ul class="list">
        <li :for={item <- @item} class="list-row">
          <div class="list-col-grow">
            <div class="font-bold">{item.title}</div>
            <div>{render_slot(item)}</div>
          </div>
        </li>
      </ul>
      \"\"\"
    end
    """

    add_component_if_missing(igniter, core_components_module, :list, 1, list_code)
  end

  defp add_component_if_missing(igniter, module, function_name, arity, code) do
    Igniter.Project.Module.find_and_update_module!(igniter, module, fn zipper ->
      case Igniter.Code.Function.move_to_def(zipper, function_name, arity) do
        {:ok, _} -> {:ok, zipper}
        :error -> {:ok, Igniter.Code.Common.add_code(zipper, code)}
      end
    end)
  end
end

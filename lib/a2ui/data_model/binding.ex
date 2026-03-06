defmodule A2UI.DataModel.Binding do
  @moduledoc """
  Resolves dynamic values in A2UI component props.

  Values can be:
  - **Literals** — returned as-is
  - **Path bindings** (`%{"path" => "/some/path"}`) — resolved from the data model
  - **Function calls** (`%{"call" => "openUrl", ...}`) — returned as-is (descriptors for renderer)
  """

  alias A2UI.DataModel

  @doc """
  Resolves a value against the data model.

  ## Parameters

  - `value` — the raw prop value (literal, path binding, or function call)
  - `data_model` — the `%DataModel{}` to resolve paths against
  - `scope_path` — base path for relative path resolution (used in templates)

  ## Examples

      iex> dm = A2UI.DataModel.new(%{"user" => %{"name" => "Alice"}})
      iex> A2UI.DataModel.Binding.resolve(%{"path" => "/user/name"}, dm)
      {:ok, "Alice"}

      iex> A2UI.DataModel.Binding.resolve("hello", A2UI.DataModel.new())
      {:ok, "hello"}
  """
  @spec resolve(any(), DataModel.t(), String.t() | nil) :: {:ok, any()} | :error
  def resolve(value, data_model, scope_path \\ nil)

  # Function call descriptor — pass through for renderer
  def resolve(%{"call" => _} = value, _data_model, _scope_path) do
    {:ok, value}
  end

  # Path binding — resolve from data model
  def resolve(%{"path" => path}, data_model, scope_path) do
    resolve_path(path, data_model, scope_path)
  end

  # Literal — return as-is
  def resolve(value, _data_model, _scope_path) do
    {:ok, value}
  end

  defp resolve_path("/" <> _ = absolute_path, data_model, _scope_path) do
    DataModel.get(data_model, absolute_path)
  end

  defp resolve_path(_relative_path, _data_model, nil) do
    :error
  end

  defp resolve_path(relative_path, data_model, scope_path) do
    full_path = scope_path <> "/" <> relative_path
    DataModel.get(data_model, full_path)
  end
end

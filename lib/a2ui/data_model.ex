defmodule A2UI.DataModel do
  @moduledoc """
  JSON document store for A2UI surface data.

  Provides get/set/delete operations using JSON Pointer (RFC 6901) paths.
  """

  alias A2UI.DataModel.JsonPointer

  defstruct data: %{}

  @type t :: %__MODULE__{data: map()}

  @doc """
  Creates a new empty data model.
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a data model with initial data.
  """
  @spec new(map()) :: t()
  def new(data) when is_map(data), do: %__MODULE__{data: data}

  @doc """
  Gets a value at the given JSON Pointer path.

  Returns `{:ok, value}` if found, `:error` if the path doesn't exist.

  ## Examples

      iex> model = A2UI.DataModel.new(%{"user" => %{"name" => "Alice"}})
      iex> A2UI.DataModel.get(model, "/user/name")
      {:ok, "Alice"}

      iex> model = A2UI.DataModel.new(%{"a" => 1})
      iex> A2UI.DataModel.get(model, "/")
      {:ok, %{"a" => 1}}
  """
  @spec get(t(), String.t()) :: {:ok, any()} | :error
  def get(%__MODULE__{data: data}, path) do
    with {:ok, tokens} <- JsonPointer.parse(path) do
      get_in_tokens(data, normalize_root(tokens))
    end
  end

  @doc """
  Sets a value at the given JSON Pointer path.

  Auto-vivifies intermediate maps as needed.

  ## Examples

      iex> model = A2UI.DataModel.new()
      iex> {:ok, model} = A2UI.DataModel.set(model, "/user/name", "Alice")
      iex> A2UI.DataModel.get(model, "/user/name")
      {:ok, "Alice"}
  """
  @spec set(t(), String.t(), any()) :: {:ok, t()} | {:error, String.t()}
  def set(%__MODULE__{data: data} = model, path, value) do
    with {:ok, tokens} <- JsonPointer.parse(path) do
      {:ok, %{model | data: set_in_tokens(data, normalize_root(tokens), value)}}
    end
  end

  @doc """
  Deletes a value at the given JSON Pointer path.

  ## Examples

      iex> model = A2UI.DataModel.new(%{"a" => 1, "b" => 2})
      iex> {:ok, model} = A2UI.DataModel.delete(model, "/a")
      iex> model.data
      %{"b" => 2}
  """
  @spec delete(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def delete(%__MODULE__{} = model, path) do
    with {:ok, tokens} <- JsonPointer.parse(path) do
      {:ok, %{model | data: delete_in_tokens(model.data, normalize_root(tokens))}}
    end
  end

  # In A2UI, "/" means the root of the data model.
  # RFC 6901 parses "/" as [""], so we normalize [""] to [].
  defp normalize_root([""]), do: []
  defp normalize_root(tokens), do: tokens

  # Get

  defp get_in_tokens(data, []), do: {:ok, data}

  defp get_in_tokens(data, [key | rest]) when is_map(data) do
    case Map.fetch(data, key) do
      {:ok, child} -> get_in_tokens(child, rest)
      :error -> :error
    end
  end

  defp get_in_tokens(data, [key | rest]) when is_list(data) do
    case Integer.parse(key) do
      {index, ""} when index >= 0 and index < length(data) ->
        get_in_tokens(Enum.at(data, index), rest)

      _ ->
        :error
    end
  end

  defp get_in_tokens(_data, _tokens), do: :error

  # Set

  defp set_in_tokens(_data, [], value), do: value

  defp set_in_tokens(data, [key | rest], value) when is_map(data) do
    child = Map.get(data, key, %{})
    Map.put(data, key, set_in_tokens(child, rest, value))
  end

  defp set_in_tokens(nil, [key | rest], value) do
    %{key => set_in_tokens(%{}, rest, value)}
  end

  defp set_in_tokens(data, [key | rest], value) when is_list(data) do
    case Integer.parse(key) do
      {index, ""} ->
        List.update_at(data, index, &set_in_tokens(&1, rest, value))

      _ ->
        data
    end
  end

  # Delete

  defp delete_in_tokens(data, []) when is_map(data), do: %{}

  defp delete_in_tokens(data, [key]) when is_map(data) do
    Map.delete(data, key)
  end

  defp delete_in_tokens(data, [key | rest]) when is_map(data) do
    case Map.fetch(data, key) do
      {:ok, child} -> Map.put(data, key, delete_in_tokens(child, rest))
      :error -> data
    end
  end

  defp delete_in_tokens(data, _tokens), do: data
end

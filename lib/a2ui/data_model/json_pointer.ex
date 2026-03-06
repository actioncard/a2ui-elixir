defmodule A2UI.DataModel.JsonPointer do
  @moduledoc """
  RFC 6901 JSON Pointer implementation.

  Parses JSON Pointer strings into token lists and vice versa,
  handling `~0` (tilde) and `~1` (slash) escaping.
  """

  @doc """
  Parses a JSON Pointer string into a list of reference tokens.

  ## Examples

      iex> A2UI.DataModel.JsonPointer.parse("")
      {:ok, []}

      iex> A2UI.DataModel.JsonPointer.parse("/")
      {:ok, [""]}

      iex> A2UI.DataModel.JsonPointer.parse("/foo/bar/0")
      {:ok, ["foo", "bar", "0"]}

      iex> A2UI.DataModel.JsonPointer.parse("/a~1b/c~0d")
      {:ok, ["a/b", "c~d"]}
  """
  @spec parse(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def parse(""), do: {:ok, []}

  def parse("/" <> rest) do
    tokens =
      rest
      |> String.split("/")
      |> Enum.map(&unescape/1)

    {:ok, tokens}
  end

  def parse(_), do: {:error, "JSON Pointer must be empty or start with /"}

  @doc """
  Converts a list of reference tokens back to a JSON Pointer string.

  ## Examples

      iex> A2UI.DataModel.JsonPointer.to_string([])
      ""

      iex> A2UI.DataModel.JsonPointer.to_string(["foo", "bar"])
      "/foo/bar"

      iex> A2UI.DataModel.JsonPointer.to_string(["a/b", "c~d"])
      "/a~1b/c~0d"
  """
  @spec to_string([String.t()]) :: String.t()
  def to_string([]), do: ""

  def to_string(tokens) when is_list(tokens) do
    "/" <> Enum.map_join(tokens, "/", &escape/1)
  end

  @doc """
  Escapes a reference token for use in a JSON Pointer string.
  `~` becomes `~0`, `/` becomes `~1`.
  """
  @spec escape(String.t()) :: String.t()
  def escape(token) do
    token
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end

  @doc """
  Unescapes a JSON Pointer reference token.
  `~1` becomes `/`, `~0` becomes `~`.
  Order matters: ~1 must be processed before ~0.
  """
  @spec unescape(String.t()) :: String.t()
  def unescape(token) do
    token
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end
end

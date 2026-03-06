defmodule A2UI.Protocol.Parser do
  @moduledoc """
  Parses A2UI JSONL streams into protocol message structs.
  """

  alias A2UI.Protocol.Message

  @doc """
  Parses a single JSON string into a message struct.

  ## Examples

      iex> A2UI.Protocol.Parser.parse(~s({"version":"v0.9","deleteSurface":{"surfaceId":"main"}}))
      {:ok, %A2UI.Protocol.Messages.DeleteSurface{surface_id: "main"}}
  """
  @spec parse(String.t()) :: {:ok, Message.t()} | {:error, String.t()}
  def parse(json), do: Message.from_json(json)

  @doc """
  Parses a JSONL string (multiple JSON objects separated by newlines) into a list of messages.

  Blank lines are skipped. Returns `{:ok, messages}` if all lines parse successfully,
  or `{:error, reason}` on the first failure.

  ## Examples

      iex> jsonl = ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}\\n{"version":"v0.9","deleteSurface":{"surfaceId":"b"}})
      iex> {:ok, messages} = A2UI.Protocol.Parser.parse_stream(jsonl)
      iex> length(messages)
      2
  """
  @spec parse_stream(String.t()) :: {:ok, [Message.t()]} | {:error, String.t()}
  def parse_stream(jsonl) when is_binary(jsonl) do
    results =
      jsonl
      |> String.split("\n")
      |> Enum.reject(&blank?/1)
      |> Enum.map(&parse/1)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, msg} -> msg end)}
      error -> error
    end
  end

  @doc """
  Returns a lazy stream that parses each line from an enumerable into messages.

  Each element yields `{:ok, message}` or `{:error, reason}`.
  """
  @spec stream(Enumerable.t()) :: Enumerable.t()
  def stream(lines) do
    lines
    |> Stream.reject(&blank?/1)
    |> Stream.map(&parse/1)
  end

  defp blank?(line), do: String.trim(line) == ""
end

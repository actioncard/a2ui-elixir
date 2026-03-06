defmodule A2UI.Protocol.ParserTest do
  use ExUnit.Case, async: true

  alias A2UI.Protocol.Parser
  alias A2UI.Protocol.Messages.{CreateSurface, DeleteSurface, UpdateComponents, UpdateDataModel}

  describe "parse/1" do
    test "parses single JSON message" do
      json = ~s({"version":"v0.9","deleteSurface":{"surfaceId":"main"}})
      assert {:ok, %DeleteSurface{surface_id: "main"}} = Parser.parse(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Parser.parse("not json")
    end
  end

  describe "parse_stream/1" do
    test "parses JSONL string" do
      jsonl =
        [
          ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}),
          ~s({"version":"v0.9","deleteSurface":{"surfaceId":"b"}})
        ]
        |> Enum.join("\n")

      assert {:ok, [%DeleteSurface{surface_id: "a"}, %DeleteSurface{surface_id: "b"}]} =
               Parser.parse_stream(jsonl)
    end

    test "skips blank lines" do
      jsonl = "\n" <> ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}) <> "\n\n"
      assert {:ok, [%DeleteSurface{surface_id: "a"}]} = Parser.parse_stream(jsonl)
    end

    test "returns error on first bad line" do
      jsonl =
        [
          ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}),
          "bad json"
        ]
        |> Enum.join("\n")

      assert {:error, _} = Parser.parse_stream(jsonl)
    end

    test "parses restaurant booking fixture" do
      jsonl = File.read!("test/support/fixtures/restaurant_booking.jsonl")
      assert {:ok, messages} = Parser.parse_stream(jsonl)
      assert length(messages) == 3

      assert [%CreateSurface{}, %UpdateComponents{}, %UpdateDataModel{}] = messages
    end
  end

  describe "stream/1" do
    test "lazily parses lines" do
      lines = [
        ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}),
        ~s({"version":"v0.9","deleteSurface":{"surfaceId":"b"}})
      ]

      results = lines |> Parser.stream() |> Enum.to_list()

      assert [
               {:ok, %DeleteSurface{surface_id: "a"}},
               {:ok, %DeleteSurface{surface_id: "b"}}
             ] = results
    end

    test "skips blank lines in stream" do
      lines = ["", ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}), "  "]
      results = lines |> Parser.stream() |> Enum.to_list()
      assert [{:ok, %DeleteSurface{surface_id: "a"}}] = results
    end

    test "includes errors in stream without halting" do
      lines = [
        ~s({"version":"v0.9","deleteSurface":{"surfaceId":"a"}}),
        "bad",
        ~s({"version":"v0.9","deleteSurface":{"surfaceId":"b"}})
      ]

      results = lines |> Parser.stream() |> Enum.to_list()
      assert [{:ok, _}, {:error, _}, {:ok, _}] = results
    end
  end
end

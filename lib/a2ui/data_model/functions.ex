defmodule A2UI.DataModel.Functions do
  @moduledoc """
  Evaluates A2UI client-side function descriptors server-side.

  Handles formatting functions (`formatString`, `formatNumber`, `formatCurrency`,
  `formatDate`, `pluralize`) and boolean logic functions (`and`, `or`, `not`).

  Unknown functions (e.g., `openUrl`, validators) pass through as raw descriptors.
  """

  alias A2UI.DataModel
  alias A2UI.DataModel.Binding

  @known_functions ~w(formatString formatNumber formatCurrency formatDate pluralize and or not)

  @currency_symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥",
    "SEK" => "kr",
    "NOK" => "kr",
    "DKK" => "kr",
    "CHF" => "CHF",
    "CAD" => "CA$",
    "AUD" => "A$",
    "CNY" => "¥"
  }

  @zero_decimal_currencies ~w(JPY KRW)

  @doc """
  Evaluates a named function with the given args against a data model.

  Returns `{:ok, result}` for known functions or `:pass_through` for unknown ones.
  If any required arg fails to resolve, returns `:pass_through`.

  ## Parameters

  - `name` — function name (e.g., `"formatNumber"`)
  - `args` — map of argument names to values (may contain path bindings)
  - `data_model` — the `%DataModel{}` for resolving path bindings in args
  - `scope_path` — base path for relative path resolution
  """
  @spec evaluate(String.t(), map(), DataModel.t(), String.t() | nil) ::
          {:ok, any()} | :pass_through
  def evaluate(name, args, data_model, scope_path)

  def evaluate("formatString", args, data_model, scope_path) do
    case resolve_args(args, data_model, scope_path) do
      {:ok, %{"value" => value}} when is_binary(value) ->
        {:ok, format_string(value, data_model)}

      _ ->
        :pass_through
    end
  end

  def evaluate(name, args, data_model, scope_path) when name in @known_functions do
    case resolve_args(args, data_model, scope_path) do
      {:ok, resolved} -> apply_function(name, resolved)
      :error -> :pass_through
    end
  end

  def evaluate(_name, _args, _data_model, _scope_path), do: :pass_through

  # --- Arg resolution ---

  defp resolve_args(args, data_model, scope_path) when is_map(args) do
    Enum.reduce_while(args, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case resolve_arg(key, value, data_model, scope_path) do
        {:ok, resolved} -> {:cont, {:ok, Map.put(acc, key, resolved)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp resolve_arg("values", value, data_model, scope_path) do
    resolve_list_arg(value, data_model, scope_path)
  end

  defp resolve_arg(_key, value, data_model, scope_path) do
    Binding.resolve(value, data_model, scope_path)
  end

  defp resolve_list_arg(values, data_model, scope_path) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case Binding.resolve(value, data_model, scope_path) do
        {:ok, resolved} -> {:cont, {:ok, acc ++ [resolved]}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp resolve_list_arg(value, _data_model, _scope_path), do: {:ok, value}

  # --- Function implementations ---

  defp format_string(value, data_model) do
    value
    |> interpolate_paths(data_model)
    |> unescape_dollar_brace()
  end

  defp apply_function("formatNumber", %{"value" => value} = args) do
    grouping = Map.get(args, "grouping", true)
    decimals = Map.get(args, "decimals", nil)
    {:ok, format_number(value, grouping, decimals)}
  end

  defp apply_function("formatNumber", _args), do: :pass_through

  defp apply_function("formatCurrency", %{"value" => value, "currency" => currency} = args) do
    default_decimals = if currency in @zero_decimal_currencies, do: 0, else: 2
    decimals = Map.get(args, "decimals", default_decimals)
    grouping = Map.get(args, "grouping", true)
    symbol = Map.get(@currency_symbols, currency, currency)
    formatted = format_number(value, grouping, decimals)
    {:ok, "#{symbol}#{formatted}"}
  end

  defp apply_function("formatCurrency", _args), do: :pass_through

  defp apply_function("formatDate", %{"value" => value, "format" => format}) do
    case parse_datetime(value) do
      {:ok, dt} -> {:ok, format_datetime(dt, format)}
      :error -> :pass_through
    end
  end

  defp apply_function("formatDate", _args), do: :pass_through

  defp apply_function("pluralize", %{"value" => count} = args) do
    result =
      cond do
        count == 0 and Map.has_key?(args, "zero") -> Map.get(args, "zero")
        count == 1 and Map.has_key?(args, "one") -> Map.get(args, "one")
        true -> Map.get(args, "other", "")
      end

    {:ok, result}
  end

  defp apply_function("pluralize", _args), do: :pass_through

  defp apply_function("and", %{"values" => values}) when is_list(values) do
    {:ok, Enum.all?(values, &(&1 == true))}
  end

  defp apply_function("and", _args), do: :pass_through

  defp apply_function("or", %{"values" => values}) when is_list(values) do
    {:ok, Enum.any?(values, &(&1 == true))}
  end

  defp apply_function("or", _args), do: :pass_through

  defp apply_function("not", %{"value" => value}) do
    {:ok, value != true}
  end

  defp apply_function("not", _args), do: :pass_through

  # --- formatString helpers ---

  @interpolation_regex ~r/(?<!\\)\$\{([^}]+)\}/

  defp interpolate_paths(str, data_model) do
    Regex.replace(@interpolation_regex, str, fn _match, path ->
      case DataModel.get(data_model, "/" <> path) do
        {:ok, value} -> to_string(value)
        :error -> "${#{path}}"
      end
    end)
  end

  defp unescape_dollar_brace(str) do
    String.replace(str, "\\${", "${")
  end

  # --- formatNumber helpers ---

  defp format_number(value, grouping, decimals) do
    {neg, integer_part, decimal_part} = split_number(value)

    formatted_int =
      if grouping do
        group_digits(integer_part)
      else
        integer_part
      end

    decimal_str = format_decimals(decimal_part, decimals)

    result =
      if decimal_str == "" do
        formatted_int
      else
        "#{formatted_int}.#{decimal_str}"
      end

    neg <> result
  end

  defp split_number(value) when is_integer(value) do
    neg = if value < 0, do: "-", else: ""
    {neg, Integer.to_string(abs(value)), ""}
  end

  defp split_number(value) when is_float(value) do
    neg = if value < 0, do: "-", else: ""
    str = Float.to_string(abs(value))

    case String.split(str, ".") do
      [int] -> {neg, int, ""}
      [int, dec] -> {neg, int, dec}
    end
  end

  defp split_number(value) when is_binary(value) do
    {neg, str} =
      if String.starts_with?(value, "-") do
        {"-", String.slice(value, 1..-1//1)}
      else
        {"", value}
      end

    case String.split(str, ".") do
      [int] -> {neg, int, ""}
      [int, dec] -> {neg, int, dec}
    end
  end

  defp group_digits(str) do
    str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
  end

  defp format_decimals(_decimal_part, 0), do: ""

  defp format_decimals(decimal_part, nil) do
    decimal_part
  end

  defp format_decimals(decimal_part, decimals) when is_integer(decimals) and decimals > 0 do
    String.pad_trailing(String.slice(decimal_part, 0, decimals), decimals, "0")
  end

  # --- formatDate helpers ---

  defp parse_datetime(value) when is_binary(value) do
    with :error <- try_parse_datetime(value),
         :error <- try_parse_naive_datetime(value),
         :error <- try_parse_date(value) do
      :error
    end
  end

  defp parse_datetime(_), do: :error

  defp try_parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> {:ok, dt}
      _ -> :error
    end
  end

  defp try_parse_naive_datetime(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, ndt} -> {:ok, ndt}
      _ -> :error
    end
  end

  defp try_parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  @month_names ~w(January February March April May June July August
                   September October November December)
  @month_abbrs ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @day_names ~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday)
  @day_abbrs ~w(Mon Tue Wed Thu Fri Sat Sun)

  @tokens [
    {"yyyy", :year4},
    {"yy", :year2},
    {"MMMM", :month_full},
    {"MMM", :month_abbr},
    {"MM", :month2},
    {"M", :month1},
    {"dd", :day2},
    {"d", :day1},
    {"EEEE", :weekday_full},
    {"E", :weekday_abbr},
    {"HH", :hour24_2},
    {"H", :hour24_1},
    {"hh", :hour12_2},
    {"h", :hour12_1},
    {"mm", :minute2},
    {"ss", :second2},
    {"a", :ampm}
  ]

  defp format_datetime(dt, format) do
    scan_format(format, dt, [])
  end

  defp scan_format("", _dt, acc), do: acc |> Enum.reverse() |> Enum.join()

  defp scan_format("'" <> rest, dt, acc) do
    case String.split(rest, "'", parts: 2) do
      [literal, remaining] -> scan_format(remaining, dt, [literal | acc])
      [remaining] -> scan_format("", dt, [remaining | acc])
    end
  end

  defp scan_format(format, dt, acc) do
    case match_token(format) do
      {token, rest} ->
        scan_format(rest, dt, [render_token(token, dt) | acc])

      nil ->
        {char, rest} = String.split_at(format, 1)
        scan_format(rest, dt, [char | acc])
    end
  end

  defp match_token(format) do
    Enum.find_value(@tokens, fn {pattern, token} ->
      if String.starts_with?(format, pattern) do
        {token, String.slice(format, String.length(pattern)..-1//1)}
      end
    end)
  end

  defp render_token(:year4, dt), do: pad(dt.year, 4)
  defp render_token(:year2, dt), do: pad(rem(dt.year, 100), 2)
  defp render_token(:month_full, dt), do: Enum.at(@month_names, dt.month - 1)
  defp render_token(:month_abbr, dt), do: Enum.at(@month_abbrs, dt.month - 1)
  defp render_token(:month2, dt), do: pad(dt.month, 2)
  defp render_token(:month1, dt), do: Integer.to_string(dt.month)
  defp render_token(:day2, dt), do: pad(dt.day, 2)
  defp render_token(:day1, dt), do: Integer.to_string(dt.day)
  defp render_token(:weekday_full, dt), do: Enum.at(@day_names, day_of_week(dt) - 1)
  defp render_token(:weekday_abbr, dt), do: Enum.at(@day_abbrs, day_of_week(dt) - 1)
  defp render_token(:hour24_2, dt), do: pad(get_hour(dt), 2)
  defp render_token(:hour24_1, dt), do: Integer.to_string(get_hour(dt))
  defp render_token(:hour12_2, dt), do: pad(to_12h(get_hour(dt)), 2)
  defp render_token(:hour12_1, dt), do: Integer.to_string(to_12h(get_hour(dt)))
  defp render_token(:minute2, dt), do: pad(get_minute(dt), 2)
  defp render_token(:second2, dt), do: pad(get_second(dt), 2)
  defp render_token(:ampm, dt), do: if(get_hour(dt) < 12, do: "AM", else: "PM")

  defp pad(n, width), do: n |> Integer.to_string() |> String.pad_leading(width, "0")

  defp to_12h(0), do: 12
  defp to_12h(h) when h > 12, do: h - 12
  defp to_12h(h), do: h

  defp get_hour(%{hour: h}), do: h
  defp get_hour(_), do: 0
  defp get_minute(%{minute: m}), do: m
  defp get_minute(_), do: 0
  defp get_second(%{second: s}), do: s
  defp get_second(_), do: 0

  defp day_of_week(%Date{} = d), do: Date.day_of_week(d)

  defp day_of_week(%{year: y, month: m, day: d}) do
    Date.new!(y, m, d) |> Date.day_of_week()
  end
end

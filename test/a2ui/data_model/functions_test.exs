defmodule A2UI.DataModel.FunctionsTest do
  use ExUnit.Case, async: true

  alias A2UI.DataModel
  alias A2UI.DataModel.Functions

  defp dm(data \\ %{}), do: DataModel.new(data)

  describe "evaluate/4 dispatch" do
    test "unknown function returns :pass_through" do
      assert :pass_through = Functions.evaluate("openUrl", %{"url" => "https://example.com"}, dm(), nil)
    end

    test "known function with unresolvable arg returns :pass_through" do
      args = %{"value" => %{"path" => "/missing"}}
      assert :pass_through = Functions.evaluate("formatNumber", args, dm(), nil)
    end
  end

  describe "formatString" do
    test "plain string passes through" do
      assert {:ok, "hello"} = Functions.evaluate("formatString", %{"value" => "hello"}, dm(), nil)
    end

    test "interpolates data model paths" do
      data = dm(%{"user" => %{"name" => "Alice"}})
      assert {:ok, "Hello, Alice!"} = Functions.evaluate("formatString", %{"value" => "Hello, ${user/name}!"}, data, nil)
    end

    test "missing path keeps placeholder" do
      assert {:ok, "Hello, ${missing}!"} = Functions.evaluate("formatString", %{"value" => "Hello, ${missing}!"}, dm(), nil)
    end

    test "escaped dollar-brace passes through as literal" do
      assert {:ok, "Price: ${amount}"} =
               Functions.evaluate("formatString", %{"value" => "Price: \\${amount}"}, dm(), nil)
    end

    test "value from path binding" do
      data = dm(%{"template" => "Count: ${count}", "count" => 42})

      assert {:ok, "Count: 42"} =
               Functions.evaluate("formatString", %{"value" => %{"path" => "/template"}}, data, nil)
    end

    test "non-string value returns :pass_through" do
      assert :pass_through = Functions.evaluate("formatString", %{"value" => 42}, dm(), nil)
    end
  end

  describe "formatNumber" do
    test "integer with grouping" do
      assert {:ok, "1,234,567"} = Functions.evaluate("formatNumber", %{"value" => 1_234_567}, dm(), nil)
    end

    test "integer without grouping" do
      assert {:ok, "1234567"} =
               Functions.evaluate("formatNumber", %{"value" => 1_234_567, "grouping" => false}, dm(), nil)
    end

    test "float with decimals" do
      assert {:ok, "1,234.50"} =
               Functions.evaluate("formatNumber", %{"value" => 1234.5, "decimals" => 2}, dm(), nil)
    end

    test "integer with decimals" do
      assert {:ok, "100.00"} =
               Functions.evaluate("formatNumber", %{"value" => 100, "decimals" => 2}, dm(), nil)
    end

    test "small number no grouping needed" do
      assert {:ok, "42"} = Functions.evaluate("formatNumber", %{"value" => 42}, dm(), nil)
    end

    test "zero" do
      assert {:ok, "0"} = Functions.evaluate("formatNumber", %{"value" => 0}, dm(), nil)
    end

    test "negative number" do
      assert {:ok, "-1,234"} = Functions.evaluate("formatNumber", %{"value" => -1234}, dm(), nil)
    end

    test "negative float" do
      assert {:ok, "-1,234.56"} =
               Functions.evaluate("formatNumber", %{"value" => -1234.56, "decimals" => 2}, dm(), nil)
    end

    test "value from path binding" do
      data = dm(%{"price" => 1234.5})

      assert {:ok, "1,234.50"} =
               Functions.evaluate(
                 "formatNumber",
                 %{"value" => %{"path" => "/price"}, "decimals" => 2},
                 data,
                 nil
               )
    end

    test "zero decimals strips decimal part" do
      assert {:ok, "1,234"} =
               Functions.evaluate("formatNumber", %{"value" => 1234.5, "decimals" => 0}, dm(), nil)
    end

    test "missing value returns :pass_through" do
      assert :pass_through = Functions.evaluate("formatNumber", %{"grouping" => true}, dm(), nil)
    end
  end

  describe "formatCurrency" do
    test "USD" do
      assert {:ok, "$1,234.56"} =
               Functions.evaluate(
                 "formatCurrency",
                 %{"value" => 1234.56, "currency" => "USD"},
                 dm(),
                 nil
               )
    end

    test "EUR" do
      assert {:ok, "€100.00"} =
               Functions.evaluate("formatCurrency", %{"value" => 100, "currency" => "EUR"}, dm(), nil)
    end

    test "SEK" do
      assert {:ok, "kr500.00"} =
               Functions.evaluate("formatCurrency", %{"value" => 500, "currency" => "SEK"}, dm(), nil)
    end

    test "JPY zero-decimal currency" do
      assert {:ok, "¥1,000"} =
               Functions.evaluate("formatCurrency", %{"value" => 1000, "currency" => "JPY"}, dm(), nil)
    end

    test "unknown currency uses code as symbol" do
      assert {:ok, "BRL100.00"} =
               Functions.evaluate("formatCurrency", %{"value" => 100, "currency" => "BRL"}, dm(), nil)
    end

    test "custom decimals override" do
      assert {:ok, "$100.0"} =
               Functions.evaluate(
                 "formatCurrency",
                 %{"value" => 100, "currency" => "USD", "decimals" => 1},
                 dm(),
                 nil
               )
    end

    test "missing currency returns :pass_through" do
      assert :pass_through = Functions.evaluate("formatCurrency", %{"value" => 100}, dm(), nil)
    end
  end

  describe "formatDate" do
    test "full datetime format" do
      assert {:ok, "2024-03-15 14:30:00"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T14:30:00Z", "format" => "yyyy-MM-dd HH:mm:ss"},
                 dm(),
                 nil
               )
    end

    test "date only format" do
      assert {:ok, "March 15, 2024"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15", "format" => "MMMM dd, yyyy"},
                 dm(),
                 nil
               )
    end

    test "12-hour format with AM/PM" do
      assert {:ok, "02:30 PM"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T14:30:00Z", "format" => "hh:mm a"},
                 dm(),
                 nil
               )
    end

    test "AM time" do
      assert {:ok, "09:15 AM"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T09:15:00Z", "format" => "hh:mm a"},
                 dm(),
                 nil
               )
    end

    test "midnight in 12h" do
      assert {:ok, "12:00 AM"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T00:00:00Z", "format" => "hh:mm a"},
                 dm(),
                 nil
               )
    end

    test "abbreviated month and weekday" do
      assert {:ok, "Fri, Mar 15"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T00:00:00Z", "format" => "E, MMM dd"},
                 dm(),
                 nil
               )
    end

    test "full weekday name" do
      assert {:ok, "Friday"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T00:00:00Z", "format" => "EEEE"},
                 dm(),
                 nil
               )
    end

    test "short year" do
      assert {:ok, "15/03/24"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15", "format" => "dd/MM/yy"},
                 dm(),
                 nil
               )
    end

    test "single-digit month and day" do
      assert {:ok, "3/5/2024"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-05", "format" => "M/d/yyyy"},
                 dm(),
                 nil
               )
    end

    test "quoted literal text" do
      assert {:ok, "Year: 2024"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15", "format" => "'Year: 'yyyy"},
                 dm(),
                 nil
               )
    end

    test "naive datetime" do
      assert {:ok, "2024-03-15"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15T14:30:00", "format" => "yyyy-MM-dd"},
                 dm(),
                 nil
               )
    end

    test "date-only input with time tokens defaults to zero" do
      assert {:ok, "00:00"} =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "2024-03-15", "format" => "HH:mm"},
                 dm(),
                 nil
               )
    end

    test "invalid date returns :pass_through" do
      assert :pass_through =
               Functions.evaluate(
                 "formatDate",
                 %{"value" => "not-a-date", "format" => "yyyy"},
                 dm(),
                 nil
               )
    end

    test "missing format returns :pass_through" do
      assert :pass_through =
               Functions.evaluate("formatDate", %{"value" => "2024-03-15"}, dm(), nil)
    end
  end

  describe "pluralize" do
    test "zero with zero category" do
      args = %{"value" => 0, "zero" => "No items", "one" => "1 item", "other" => "items"}
      assert {:ok, "No items"} = Functions.evaluate("pluralize", args, dm(), nil)
    end

    test "zero without zero category falls to other" do
      args = %{"value" => 0, "one" => "1 item", "other" => "0 items"}
      assert {:ok, "0 items"} = Functions.evaluate("pluralize", args, dm(), nil)
    end

    test "one" do
      args = %{"value" => 1, "one" => "1 item", "other" => "items"}
      assert {:ok, "1 item"} = Functions.evaluate("pluralize", args, dm(), nil)
    end

    test "other" do
      args = %{"value" => 5, "one" => "1 item", "other" => "5 items"}
      assert {:ok, "5 items"} = Functions.evaluate("pluralize", args, dm(), nil)
    end

    test "missing other returns empty string" do
      assert {:ok, ""} = Functions.evaluate("pluralize", %{"value" => 5}, dm(), nil)
    end

    test "value from path binding" do
      data = dm(%{"count" => 1})
      args = %{"value" => %{"path" => "/count"}, "one" => "1 item", "other" => "items"}
      assert {:ok, "1 item"} = Functions.evaluate("pluralize", args, data, nil)
    end
  end

  describe "and" do
    test "all true" do
      assert {:ok, true} = Functions.evaluate("and", %{"values" => [true, true, true]}, dm(), nil)
    end

    test "one false" do
      assert {:ok, false} = Functions.evaluate("and", %{"values" => [true, false, true]}, dm(), nil)
    end

    test "empty list is true" do
      assert {:ok, true} = Functions.evaluate("and", %{"values" => []}, dm(), nil)
    end

    test "non-boolean values are not true" do
      assert {:ok, false} = Functions.evaluate("and", %{"values" => [true, 1, "yes"]}, dm(), nil)
    end

    test "values from path bindings" do
      data = dm(%{"a" => true, "b" => true})

      assert {:ok, true} =
               Functions.evaluate(
                 "and",
                 %{"values" => [%{"path" => "/a"}, %{"path" => "/b"}]},
                 data,
                 nil
               )
    end
  end

  describe "or" do
    test "one true" do
      assert {:ok, true} = Functions.evaluate("or", %{"values" => [false, true, false]}, dm(), nil)
    end

    test "all false" do
      assert {:ok, false} = Functions.evaluate("or", %{"values" => [false, false]}, dm(), nil)
    end

    test "empty list is false" do
      assert {:ok, false} = Functions.evaluate("or", %{"values" => []}, dm(), nil)
    end
  end

  describe "not" do
    test "not true is false" do
      assert {:ok, false} = Functions.evaluate("not", %{"value" => true}, dm(), nil)
    end

    test "not false is true" do
      assert {:ok, true} = Functions.evaluate("not", %{"value" => false}, dm(), nil)
    end

    test "not nil is true (strict boolean)" do
      assert {:ok, true} = Functions.evaluate("not", %{"value" => nil}, dm(), nil)
    end

    test "not 0 is true (strict boolean)" do
      assert {:ok, true} = Functions.evaluate("not", %{"value" => 0}, dm(), nil)
    end

    test "value from path binding" do
      data = dm(%{"flag" => true})
      assert {:ok, false} = Functions.evaluate("not", %{"value" => %{"path" => "/flag"}}, data, nil)
    end
  end
end

defmodule GenReport do
  alias GenReport.Parser

  @months %{
    "1" => "janeiro",
    "2" => "fevereiro",
    "3" => "março",
    "4" => "abril",
    "5" => "maio",
    "6" => "junho",
    "7" => "julho",
    "8" => "agosto",
    "9" => "setembro",
    "10" => "outubro",
    "11" => "novembro",
    "12" => "dezembro"
  }

  def build(file_name) do
    file_name
    |> Parser.parse_file()
    |> Enum.reduce(gen_report_structure(), fn line, report -> build_report(line, report) end)
  end

  def build_from_many(file_names) do
    file_names
    |> Task.async_stream(&build(&1))
    |> Enum.reduce(%{}, fn {:ok, report}, report_acc ->
      aggregate_reports(report_acc, report)
    end)
  end

  defp aggregate_reports(report_acc, report) when map_size(report_acc) == 0 do
    %{
      "all_hours" => all_hours,
      "hours_per_month" => hours_per_month,
      "hours_per_year" => hours_per_year
    } = report

    update_report(all_hours, hours_per_month, hours_per_year)
  end

  defp aggregate_reports(report_acc, report) when map_size(report_acc) > 0 do
    %{
      "all_hours" => all_hours_acc,
      "hours_per_month" => hours_per_month_acc,
      "hours_per_year" => hours_per_year_acc
    } = report_acc

    %{
      "all_hours" => all_hours,
      "hours_per_month" => hours_per_month,
      "hours_per_year" => hours_per_year
    } = report

    all_hours_acc = merge_maps(all_hours_acc, all_hours)
    hours_per_month_acc = merge_maps(hours_per_month_acc, hours_per_month)
    hours_per_year_acc = merge_maps(hours_per_year_acc, hours_per_year)

    update_report(all_hours_acc, hours_per_month_acc, hours_per_year_acc)
  end

  defp merge_maps(map_acc, map) do
    Map.merge(map_acc, map, fn _key, value1, value2 ->
      sum_values(is_map(value1), value1, value2)
    end)
  end

  defp sum_values(is_map, value1, value2) when is_map == false do
    value1 + value2
  end

  defp sum_values(is_map, map1, map2) when is_map == true do
    merge_maps(map1, map2)
  end

  defp build_report([name, hours, _day, _month, _year] = line, report) do
    %{
      "all_hours" => all_hours,
      "hours_per_month" => hours_per_month,
      "hours_per_year" => hours_per_year
    } = report

    all_hours = Map.put(all_hours, name, sum_hours(all_hours[name], hours))

    hours_per_month =
      build_hours_per_month(Map.has_key?(hours_per_month, name), hours_per_month, line)

    hours_per_year =
      build_hours_per_year(Map.has_key?(hours_per_year, name), hours_per_year, line)

    update_report(all_hours, hours_per_month, hours_per_year)
  end

  defp build_hours_per_year(has_key, hours_per_year, line) when has_key == false do
    [name, _hours, _day, _month, _year] = line
    hours_per_year = Map.put(hours_per_year, name, %{})
    hours_per_year
  end

  defp build_hours_per_year(has_key, hours_per_year, line) when has_key == true do
    [name, hours, _day, _month, year] = line

    employee_hours = Map.get(hours_per_year, name)

    employee_hours = Map.put(employee_hours, year, sum_hours(employee_hours[year], hours))

    %{hours_per_year | name => employee_hours}
  end

  defp build_hours_per_month(has_key, hours_per_month, line)
       when has_key == false do
    [name, _hours, _day, _month, _year] = line
    hours_per_month = Map.put(hours_per_month, name, %{})
    hours_per_month
  end

  defp build_hours_per_month(has_key, hours_per_month, line)
       when has_key == true do
    [name, hours, _day, month_number, _year] = line

    month = @months[month_number]

    employee_hours = Map.get(hours_per_month, name)

    employee_hours = Map.put(employee_hours, month, sum_hours(employee_hours[month], hours))

    %{hours_per_month | name => employee_hours}
  end

  defp sum_hours(hours, hours_to_add) when not is_nil(hours) do
    hours + hours_to_add
  end

  defp sum_hours(hours, hours_to_add) when hours == nil do
    hours_to_add
  end

  defp gen_report_structure() do
    %{"all_hours" => %{}, "hours_per_month" => %{}, "hours_per_year" => %{}}
  end

  defp update_report(all_hours, hours_per_month, hours_per_year) do
    %{
      "all_hours" => all_hours,
      "hours_per_month" => hours_per_month,
      "hours_per_year" => hours_per_year
    }
  end
end

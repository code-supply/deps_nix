defmodule DepsNix.Packages do
  def dependency_names(packages, name) do
    case Enum.find(packages, &(&1.app == name)) do
      nil ->
        raise "Couldn't find #{name} in #{packages |> Enum.map(& &1.app) |> inspect}"

      package ->
        dep_names = Enum.map(package.deps, & &1.app)
        dep_names ++ Enum.flat_map(dep_names, &dependency_names(packages, &1))
    end
  end
end

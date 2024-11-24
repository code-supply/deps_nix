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

  def filter(deps, :all) do
    deps
  end

  def filter(packages, permitted_names) do
    permitted = permitted(packages, permitted_names)

    sub_dependency_names =
      Enum.flat_map(permitted, &dependency_names(packages, &1.app))

    permitted ++
      Enum.filter(packages, &(&1.app in sub_dependency_names))
  end

  defp permitted(packages, permitted_names) do
    Enum.filter(packages, &("#{&1.app}" in permitted_names))
  end

  def reject_paths(deps) do
    deps
    |> Enum.reject(fn dep ->
      dep.scm == Mix.SCM.Path
    end)
  end
end

defmodule SymphonyElixir.BuildGuard do
  @moduledoc false

  @tracked_entries ["mix.exs", "mix.lock", "config", "lib", "priv"]

  @spec check(String.t() | charlist()) :: :ok | {:error, String.t()}
  def check(script_path) when is_list(script_path) do
    script_path
    |> List.to_string()
    |> check()
  end

  def check(script_path) when is_binary(script_path) do
    script_path = Path.expand(script_path)

    with {:ok, project_root} <- project_root(script_path),
         {:ok, script_mtime} <- mtime(script_path),
         newest_source_path <- newest_tracked_path(project_root),
         {:ok, source_mtime} <- mtime(newest_source_path),
         true <- source_mtime > script_mtime do
      {:error, stale_build_message(project_root, script_path, newest_source_path)}
    else
      false -> :ok
      {:error, :not_source_checkout} -> :ok
      {:error, _reason} -> :ok
    end
  end

  @spec project_root(String.t()) :: {:ok, String.t()} | {:error, :not_source_checkout}
  defp project_root(script_path) do
    script_dir = Path.dirname(script_path)
    project_root = Path.dirname(script_dir)

    if Path.basename(script_dir) == "bin" and
         File.regular?(Path.join(project_root, "mix.exs")) and
         File.dir?(Path.join(project_root, "lib")) do
      {:ok, project_root}
    else
      {:error, :not_source_checkout}
    end
  end

  @spec newest_tracked_path(String.t()) :: String.t()
  defp newest_tracked_path(project_root) do
    @tracked_entries
    |> Enum.flat_map(&expand_tracked_entry(project_root, &1))
    |> Enum.filter(&File.regular?/1)
    |> Enum.max_by(&mtime_sort_key/1, fn -> Path.join(project_root, "mix.exs") end)
  end

  @spec expand_tracked_entry(String.t(), String.t()) :: [String.t()]
  defp expand_tracked_entry(project_root, entry) do
    path = Path.join(project_root, entry)

    cond do
      File.regular?(path) ->
        [path]

      File.dir?(path) ->
        Path.wildcard(Path.join(path, "**/*"))

      true ->
        []
    end
  end

  @spec mtime(String.t()) :: {:ok, integer()} | {:error, term()}
  defp mtime(path) do
    case File.stat(path, time: :posix) do
      {:ok, stat} -> {:ok, stat.mtime}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec mtime_sort_key(String.t()) :: integer()
  defp mtime_sort_key(path) do
    path
    |> File.stat!(time: :posix)
    |> Map.fetch!(:mtime)
  end

  @spec stale_build_message(String.t(), String.t(), String.t()) :: String.t()
  defp stale_build_message(project_root, script_path, source_path) do
    relative_script_path = Path.relative_to(script_path, project_root)
    relative_source_path = Path.relative_to(source_path, project_root)

    "Stale Symphony build detected: #{relative_script_path} is older than #{relative_source_path}. " <>
      "Run `mise exec -- mix build` from #{project_root} before starting Symphony."
  end
end

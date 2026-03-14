defmodule SymphonyElixir.BuildGuardTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.BuildGuard

  test "returns a stale build error when tracked sources are newer than the escript" do
    project_root = unique_project_root()
    script_path = Path.join(project_root, "bin/symphony")
    source_path = Path.join(project_root, "lib/symphony_elixir/runtime.ex")

    create_checkout!(project_root)
    write_file!(script_path, "#!/usr/bin/env escript\n")
    Process.sleep(1_100)
    write_file!(source_path, "defmodule SymphonyElixir.Runtime do\nend\n")

    assert {:error, message} = BuildGuard.check(script_path)
    assert message =~ "Stale Symphony build detected"
    assert message =~ "bin/symphony"
    assert message =~ "lib/symphony_elixir/runtime.ex"
    assert message =~ "mise exec -- mix build"
  end

  test "returns ok when the escript is newer than tracked sources" do
    project_root = unique_project_root()
    script_path = Path.join(project_root, "bin/symphony")
    source_path = Path.join(project_root, "priv/static/dashboard.css")

    create_checkout!(project_root)
    write_file!(source_path, "body { color: black; }\n")
    Process.sleep(1_100)
    write_file!(script_path, "#!/usr/bin/env escript\n")

    assert :ok = BuildGuard.check(script_path)
  end

  test "returns ok when the script is not running from a source checkout" do
    script_root = unique_project_root()
    script_path = Path.join(script_root, "symphony")

    File.mkdir_p!(script_root)
    write_file!(script_path, "#!/usr/bin/env escript\n")

    assert :ok = BuildGuard.check(script_path)
  end

  test "returns ok when the script path cannot be statted after project root detection" do
    project_root = unique_project_root()
    script_path = Path.join(project_root, "bin/symphony")

    create_checkout!(project_root)

    assert :ok = BuildGuard.check(String.to_charlist(script_path))
  end

  defp unique_project_root do
    Path.join(
      System.tmp_dir!(),
      "symphony-build-guard-#{System.unique_integer([:positive])}"
    )
  end

  defp create_checkout!(project_root) do
    File.mkdir_p!(Path.join(project_root, "bin"))
    File.mkdir_p!(Path.join(project_root, "lib/symphony_elixir"))
    File.mkdir_p!(Path.join(project_root, "priv/static"))
    File.write!(Path.join(project_root, "mix.exs"), "defmodule SymphonyElixir.MixProject do\nend\n")
  end

  defp write_file!(path, content) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, content)
  end
end

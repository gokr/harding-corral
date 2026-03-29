when defined(harding_corral) and defined(harding_sqlite):
  import std/[osproc, strutils, unittest]

  suite "Corral":
    test "Corral wraps SQLite parameterized queries":
      let cmd = "./harding external/corral/tests/sqlite_parameterized_corral.hrd"
      let (output, exitCode) = execCmdEx(cmd)
      check exitCode == 0
      check output.contains("1")
      check output.contains("name")
      check output.contains("score")
      check output.contains("Grace:1337")

    test "Corral maps rows to objects and supports insert update":
      let cmd = "./harding external/corral/tests/sqlite_corral_mapper.hrd"
      let (output, exitCode) = execCmdEx(cmd)
      check exitCode == 0
      check output.contains("Ada")
      check output.contains("1201")
      check output.contains("admin")
      check output.contains("1400")
      check output.contains("2")

    test "Corral supports sql templates plus upsert and delete":
      let cmd = "./harding external/corral/tests/sqlite_corral_sql_template.hrd"
      let (output, exitCode) = execCmdEx(cmd)
      check exitCode == 0
      check output.contains("Ada")
      check output.contains("1")
      check output.contains("Grace")
      check output.contains("1400")

else:
  echo "Corral tests skipped (compile with -d:harding_corral -d:harding_sqlite)"

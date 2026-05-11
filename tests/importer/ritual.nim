import std/[os, strutils]
import ../../src/rituals


proc expectCurrentDir*(expectedDir: string) =
  let actual =   "actual cwd:   " & getCurrentDir() & "\n"
  let expected = "expected cwd: " & "end with '" & expectedDir & "'\n"
  let message = "\n" & actual & expected
  assert getCurrentDir().endsWith(expectedDir), message


ritual "reciteimport":
  task "local dir":
    expectCurrentDir("" / "tests" / "importer")
  tui:
    expectCurrentDir("" / "tests" / "importer")
    label(getCurrentDir(), state)

  recite "other.imported"

  task "after recite dir":
    expectCurrentDir("" / "tests" / "importer")
  tui:
    expectCurrentDir("" / "tests" / "importer")
    label(getCurrentDir(), state)

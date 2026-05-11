{.used.}
import std/[os, strutils]
import ../../src/rituals


proc expectCurrentDir*(expectedDir: string) =
  let actual =   "actual cwd:   " & getCurrentDir() & "\n"
  let expected = "expected cwd: " & "end with '" & expectedDir & "'\n"
  let message = "\n" & actual & expected
  assert getCurrentDir().endsWith(expectedDir), message


ritual "imported":
  task "imported dir":
    expectCurrentDir("" / "tests" / "other")
  tui:
    expectCurrentDir("" / "tests" / "other")
    label(getCurrentDir(), state)

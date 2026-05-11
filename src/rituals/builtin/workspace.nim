import std/[os, sequtils]
import ../dsl


proc findRitualPaths(root: string): seq[string] =
  walkDir(root)
    .toSeq()
    .filterIt(it.kind == pcDir)
    .filterIt(fileExists(it.path / "ritual.nim"))
    .mapIt(it.path)


proc buildImports(paths: seq[string]): string =
  for path in paths:
    result.add "--import:" & path / "ritual.nim" & "\n"


ritual "workspace":
  let ritualPaths = findRitualPaths(callDir)
  let imports = buildImports(ritualPaths)
  let configPath = callDir / "ritual.cfg"

  task "write ritual.cfg":
    writeFile(configPath, imports)

  tui:
    if state == Done:
      label(bold & configPath, state)
    else:
      label(configPath, state)

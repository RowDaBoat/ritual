import std/[os, sequtils]
import ../dsl


proc findRitualPaths(root: string): seq[string] =
  walkDir(root)
    .toSeq()
    .filterIt(it.kind == pcDir)
    .filterIt(fileExists(it.path / "ritual.nim"))
    .mapIt(it.path)


proc buildConfig(paths: seq[string]): string =
  for path in paths:
    result.add "--path:" & path & "\n"


ritual "workspace":
  let ritualPaths = findRitualPaths(callDir)
  let configContent = buildConfig(ritualPaths)
  let configPath = callDir / "ritual.cfg"

  task "write ritual.cfg":
    writeFile(configPath, configContent)

  tui:
    if state == Done:
      label(bold & configPath, state)
    else:
      label(configPath, state)

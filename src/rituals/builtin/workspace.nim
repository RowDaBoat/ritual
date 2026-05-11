import std/[os, sequtils, strutils]
import ../dsl


proc findRitualPaths(root: string): seq[string] =
  walkDir(root)
    .toSeq()
    .filterIt(it.kind == pcDir)
    .filterIt(fileExists(it.path / "ritual.nim"))
    .mapIt(it.path)


proc buildImports(paths: seq[string]): string =
  for path in paths:
    result.add "--import:\"" & path / "ritual.nim" & "\"\n"


proc isRitualImport(line: string): bool =
  line.startsWith("--import:") and line.endsWith("ritual.nim")


proc mergeConfig(configPath: string, imports: string): string =
  if not fileExists(configPath):
    return imports

  let existing = readFile(configPath)
  let preserved = existing
    .splitLines()
    .filterIt(not isRitualImport(it))
    .filterIt(it.strip().len > 0)
    .join("\n")

  if preserved.len > 0:
    return preserved & "\n" & imports
  return imports


ritual "workspace":
  let ritualPaths = findRitualPaths(callDir)
  let imports = buildImports(ritualPaths)
  let configPath = callDir / "nim.cfg"
  let configContent = mergeConfig(configPath, imports)

  task "write nim.cfg":
    writeFile(configPath, configContent)

  tui:
    if state == Done:
      label(bold & configPath, state)
    else:
      label(configPath, state)

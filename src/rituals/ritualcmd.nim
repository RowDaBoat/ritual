import std/[os, osproc, strutils, sequtils, terminal]


proc collectConfigs(): seq[string] =
  var current = getCurrentDir()
  var paths: seq[string]

  while true:
    let configPath = current / "ritual.cfg"
    if fileExists(configPath):
      paths.add configPath

    let parent = parentDir(current)
    if parent == current:
      break

    current = parent

  for i in countdown(paths.high, 0):
    result.add paths[i]


proc readConfigs(paths: seq[string]): string =
  if paths.len == 0:
    return ""

  paths
    .mapIt(readFile(it).splitLines())
    .foldl(a & b)
    .mapIt(it.strip())
    .filterIt(it.len > 0)
    .join(" ")


proc parseArgs(): tuple[dir: string, args: string] =
  result.dir = "."
  var forwarded: seq[string]
  var i = 1

  while i <= paramCount():
    let param = paramStr(i)

    if param.startsWith("--dir:"):
      result.dir = param[6..^1]
    else:
      forwarded.add param

    inc i

  result.args = forwarded.join(" ")


when isMainModule:
  let configs = collectConfigs()
  let configArgs = readConfigs(configs)
  let (dir, args) = parseArgs()
  let allArgs = (configArgs & " " & args).strip()
  let ritualPath = dir / "ritual.nim"

  if not fileExists(ritualPath):
    styledEcho fgRed, "Error: ", resetStyle, "No ritual.nim found in " & dir.absolutePath & "."
    quit(1)

  let command = "nim r --verbosity:0 " & ritualPath & " " & allArgs
  quit(execCmd(command))

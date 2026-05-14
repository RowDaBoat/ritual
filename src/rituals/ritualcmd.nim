import std/[os, osproc, sequtils, strutils, terminal]


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


proc collectConfigs(dir: string): seq[string] =
  var current = dir.absolutePath()

  while true:
    let configPath = current / "ritual.cfg"
    if fileExists(configPath):
      result.add configPath

    let parent = parentDir(current)
    if parent == current:
      break
    current = parent


proc isExcluded(flag: string, excludePath: string): bool =
  flag.startsWith("--import:") and
    excludePath.len > 0 and
    expandFilename(flag.split(":", maxsplit = 1)[1]) == excludePath


proc readConfigFlags(configPaths: seq[string], exclude: string): string =
  let excludePath = if exclude.len > 0: expandFilename(exclude) else: ""

  configPaths
    .mapIt(readFile(it).splitLines())
    .foldl(a & b)
    .mapIt(it.strip())
    .filterIt(it.len > 0 and not it.startsWith("#"))
    .filterIt(not it.isExcluded(excludePath))
    .join(" ")


proc canImportRituals(): bool =
  let (_, exitCode) = execCmdEx("nim check --verbosity:0 --hints:off --eval:\"import rituals\"")
  exitCode == 0

when isMainModule:
  let (dir, args) = parseArgs()
  let configs = collectConfigs(dir)
  let flags = "--verbosity:0 --warnings:off --hints:off"
  let ritualPath = dir / "ritual.nim"

  if fileExists(ritualPath):
    let configFlags = readConfigFlags(configs, ritualPath)
    let command = @["nim r", flags, configFlags, ritualPath, args].join(" ")
    quit(execCmd(command))
  elif canImportRituals():
    let configFlags = readConfigFlags(configs, "")
    let evalFlags = "--eval:\"import rituals\""
    let command = @["nim r", flags, configFlags, evalFlags, "-- ", args].join(" ")
    quit(execCmd(command))
  else:
    styledEcho fgRed, "Error: ", resetStyle, "The 'rituals' package is not installed."
    styledEcho "Add its path via --path in a nim.cfg, or install it with a package manager."
    quit(1)

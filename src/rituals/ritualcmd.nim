import std/[os, osproc, strutils, terminal]


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


proc readConfigFlags(configPaths: seq[string]): string =
  var flags: seq[string]

  for path in configPaths:
    for line in readFile(path).splitLines():
      let trimmed = line.strip()
      if trimmed.len > 0 and not trimmed.startsWith("#"):
        flags.add trimmed

  result = flags.join(" ")


proc canImportRituals(): bool =
  let (_, exitCode) = execCmdEx("nim check --verbosity:0 --hints:off --eval:\"import rituals\"")
  exitCode == 0

when isMainModule:
  let (dir, args) = parseArgs()
  let configs = collectConfigs(dir)
  let configFlags = readConfigFlags(configs)
  let flags = "--verbosity:0 --warnings:off --hints:off"
  let ritualPath = dir / "ritual.nim"

  if fileExists(ritualPath):
    let command = @["nim r", flags, configFlags, ritualPath, args].join(" ")
    quit(execCmd(command))
  elif canImportRituals():
    let evalFlags = "--eval:\"import rituals\""
    let command = @["nim r", flags, configFlags, evalFlags, "-- ", args].join(" ")
    quit(execCmd(command))
  else:
    styledEcho fgRed, "Error: ", resetStyle, "The 'rituals' package is not installed."
    styledEcho "Add its path via --path in a nim.cfg, or install it with a package manager."
    quit(1)

import std/[os, osproc, strutils]


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


proc ritualSource(dir: string): string =
  let ritualPath = dir / "ritual.nim"
 
  if fileExists(ritualPath):
    return ritualPath
 
  return "--eval:\"import rituals\""


when isMainModule:
  let (dir, args) = parseArgs()
  let configs = collectConfigs(dir)
  let configFlags = readConfigFlags(configs)
  let flags = "--verbosity:0 --warnings:off --hints:off"
  let source = ritualSource(dir)
  let command = @["nim r", flags, configFlags, source, args].join(" ")
  quit(execCmd(command))

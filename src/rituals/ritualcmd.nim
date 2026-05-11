import std/[os, osproc, strutils, sequtils, terminal]


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
  let (dir, args) = parseArgs()
  let ritualPath = dir / "ritual.nim"

  if not fileExists(ritualPath):
    styledEcho fgRed, "Error: ", resetStyle, "No ritual.nim found in " & dir.absolutePath & "."
    quit(1)

  let command = "nim r --verbosity:0 " & ritualPath & " " & args
  quit(execCmd(command))

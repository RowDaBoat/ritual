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


when isMainModule:
  let (dir, args) = parseArgs()
  let flags = "--verbosity:0"
  let ritualPath = dir / "ritual.nim"
  let command = @["nim r", flags, ritualPath, args].join(" ")
  quit(execCmd(command))

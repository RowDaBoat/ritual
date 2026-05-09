import std/os
import dsl, tasks


type InstallTarget = enum
  Nimby
  Nimble
  Skip


let ritualBin = "ritual"
let ritualPath = "../../bin/" & ritualBin
let nimbyBinPath = "~/.nimby/nim/bin/"
let nimbleBinPath = "~/.nimble/bin"


ritual "install-ritual":
  nim.compile("installritual.nim", "-o:" & ritualPath)

  var target: InstallTarget
  choose(target, Nimby, "Install location")
  case target
  of Nimby:  copy(ritualPath, nimbyBinPath / "ritual")
  of Nimble: copy(ritualPath, nimbleBinPath / "ritual")
  of Skip:   notice("Skipped installation")

when isMainModule:
  echo "Summoning!"

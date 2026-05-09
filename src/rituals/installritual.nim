import std/os
import dsl, tasks


type InstallTarget = enum
  Nimby
  Nimble
  Skip


let ritualBin = "ritual"
let nimbyBinPath = "~/.nimby/nim/bin"
let nimbleBinPath = "~/.nimble/bin"


ritual "install-ritual":
  nim.compile("installritual.nim", "-o:" & ritualBin)

  var target: InstallTarget
  choose(target, Nimby, "Install location")
  case target
  of Nimby:  move(ritualBin, nimbyBinPath / ritualBin)
  of Nimble: move(ritualBin, nimbleBinPath / ritualBin)
  of Skip:   notice("Skipped installation")

when isMainModule:
  echo "Summoning!"

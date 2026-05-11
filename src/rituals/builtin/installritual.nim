import std/os
import ../[dsl, tasks]


type InstallTarget = enum
  Nimby
  Nimble
  Skip


let ritualBin = "ritual"
let nimbyBinPath =  "~/.nimby/nim/bin".expandTilde
let nimbleBinPath = "~/.nimble/bin".expandTilde


ritual "install-ritual":
  nim.compile("../ritualcmd.nim", "-o:" & ritualBin)

  var target: InstallTarget
  choose(target, Nimby, "Install location")

  case target
  of Nimby:
    mkdir(nimbyBinPath)
    move(ritualBin, nimbyBinPath / ritualBin)
  of Nimble:
    mkdir(nimbleBinPath)
    move(ritualBin, nimbleBinPath / ritualBin)
  of Skip:
    notice("Skipped installation")

import std/os
import dsl, tasks

let ritualBin = "ritual"
let ritualPath = "../../bin/" & ritualBin
let nimbyBinPath = "~/.nimby/bin"
let nimbleBinPath = "~/.nimble/bin"


ritual "install-ritual":
  nim.compile("installritual.nim", "-o:" & ritualPath)

  if dirExists(nimbyBinPath):
    notice("Installing `ritual` in .nimby.")
    copy(ritualPath, nimbyBinPath/"ritual")
  elif dirExists(nimbleBinPath):
    notice("Installing `ritual` in .nimble.")
    copy(ritualPath, nimbyBinPath/"ritual")
  else:
    notice("Couldn't find .nimby nor .nimble installations.")
    notice("Skipping `ritual` installation.")

when isMainModule:
  echo "Summoning!"

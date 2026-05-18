import std/[os, terminal]
import rituals


type InstallTarget = enum
  Nimby
  Nimble
  Skip


let ritualBin = "ritual"
let nimbyBinPath = "~/.nimby/nim/bin".expandTilde
let nimbleBinPath = "~/.nimble/bin".expandTilde


proc renderOptions(options: openArray[string], selected: int) =
  for index, name in options:
    let isSelected = index == selected
    let rune = if isSelected: "\e[38;5;196m●\e[0m" else: "\e[38;5;236m◌\e[0m"
    let color = if isSelected: "\e[38;5;231m" else: "\e[38;5;240m"
    stdout.write "  " & rune & " " & color & name & "\e[0m\n"
  stdout.flushFile()


proc clearOptions(count: int) =
  for i in 0 ..< count:
    stdout.write "\e[1A\e[2K"
  stdout.write "\r"
  stdout.flushFile()


proc promptTarget(): InstallTarget =
  let options = ["Nimby  (~/.nimby/nim/bin)", "Nimble (~/.nimble/bin)", "Skip"]
  var selected = 0

  stdout.write "\e[?25l"
  stdout.write "Install location:\n"
  renderOptions(options, selected)

  while true:
    case getch()
    of '\e':
      if getch() == '[':
        case getch()
        of 'A':
          selected = (selected - 1 + options.len) mod options.len
        of 'B':
          selected = (selected + 1) mod options.len
        else:
          discard
    of '\r', '\n':
      break
    else:
      discard

    clearOptions(options.len)
    renderOptions(options, selected)

  clearOptions(options.len)
  stdout.write "\e[1A\e[2K"
  stdout.write "Install location: " & options[selected] & "\n"
  stdout.write "\e[?25h"
  stdout.flushFile()

  InstallTarget(selected)


let target = promptTarget()


ritual "install-ritual":
  nim.compile("src/rituals/ritualcmd.nim", "-o:" & ritualBin)

  case target
  of Nimby:
    mkdir(nimbyBinPath)
    move(ritualBin, nimbyBinPath / ritualBin)
  of Nimble:
    mkdir(nimbleBinPath)
    move(ritualBin, nimbleBinPath / ritualBin)
  of Skip:
    notice("Skipped installation")


runRitual("rituals.install-ritual")

import std/strutils

const reset*      = "\e[0m"
const eraseLine*  = "\e[2K"
const hideCursor* = "\e[?25l"
const showCursor* = "\e[?25h"
const bold*       = "\e[1m"

template fg*(color: int): string     = "\e[38;5;" & $color & "m"
template bg*(color: int): string     = "\e[48;5;" & $color & "m"
template cursorUp*(n: int): string   = "\e[" & $n & "A"
template cursorDown*(n: int): string = "\e[" & $n & "B"


type Vtui* = object
  drawnLines*: int
  tick*: int


const filledColors = [52, 52, 88, 88, 124, 160, 196, 196, 196, 196, 160, 124, 88, 88, 52, 52, 52, 52]
const emptyRunes = ["·", "·", "∴", "∴", "◌", "◌", "✧", "✧", "·", "·", "∵", "∵", "◌", "◌", "✦", "✦", "·", "·"]
const waveLen = 18


proc drawHeader*(vtui: var Vtui, name: string) =
  stdout.write fg(52) & "╭────────────\n"
  stdout.write fg(52) & "│ " & bold & fg(231) & "⛤ " & fg(160) & "Ritual: " & name & "\n"
  stdout.write fg(52) & "├──────────────────\n"
  stdout.write reset & hideCursor
  stdout.flushFile()


proc drawFooter*(vtui: var Vtui) =
  stdout.write fg(52) & "╰────────────────────────" & "\n"
  stdout.write reset & showCursor
  stdout.flushFile()


proc beginFrame*(vtui: var Vtui) =
  if vtui.drawnLines > 0:
    stdout.write cursorUp(vtui.drawnLines)
  stdout.write "\r"
  vtui.drawnLines = 0


proc endFrame*(vtui: Vtui) =
  stdout.flushFile()


proc drawBar*(
  vtui: var Vtui,
  name: string,
  label: string,
  progress: float,
  maxNameLen: int,
  tick: int
) =
  let barWidth = 30
  let filled = clamp(int(progress * float(barWidth)), 0, barWidth)
  let percentage = progress * 100.0
  let paddedName = align(name, maxNameLen)
  let paddedLabel = " " & label
  var bar = reset & "["

  for i in 0 ..< barWidth:
    let idx = (i + tick div 2) mod waveLen
    let hasChar = 0 < i and i < paddedLabel.len

    if i < filled:
      if hasChar:
        bar.add bg(filledColors[idx]) & fg(231) & $paddedLabel[i]
      else:
        bar.add bg(filledColors[idx]) & " "
    else:
      if hasChar:
        bar.add bg(234) & fg(231) & $paddedLabel[i]
      else:
        bar.add fg(236) & emptyRunes[idx]

    bar.add reset

  bar.add "]"

  let begin = "\r" & eraseLine & fg(52) & "│ " & fg(88)
  let percent = $formatFloat(percentage, ffDecimal, 2)
  stdout.write begin & paddedName & " " & bar & " " & fg(88) & percent & "%" & reset & "\n"
  inc vtui.drawnLines


proc drawLabel*(vtui: var Vtui, name: string, label: string, maxNameLen: int) =
  let paddedName = align(name, maxNameLen)
  let begin = "\r" & eraseLine & fg(52) & "│ " & fg(88)
  stdout.write begin & paddedName & " " & reset & label & "\n"
  inc vtui.drawnLines

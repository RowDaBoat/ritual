import std/[os, osproc, streams, httpclient, strutils]
import output


type Nim* = object
  discard


let nim* = Nim()


template cmd*(command: string, name: string = "cmd") =
  task name:
    let process = startProcess(command, options = {poStdErrToStdOut, poEvalCommand})
    let stream = process.outputStream

    while not stream.atEnd:
      let line = stream.readLine()
      taskLog.write(line & "\n")

    process.close()

  tui:
    if state == Done:
      label(bold & command, state)
    else:
      label(command, state)


template copy*(source: string, destination: string, name: string = "copy") =
  task name:
    copyFile(source, destination)
  tui:
    if state == Done:
      label(source & " → " & bold & destination, state)
    else:
      label(source & " → " & destination, state)


template move*(source: string, destination: string, name: string = "move") =
  task name:
    moveFile(source, destination)
  tui:
    if state == Done:
      label(source & " → " & bold & destination, state)
    else:
      label(source & " → " & destination, state)


template mkdir*(path: string, name: string = "mkdir") =
  task name:
    createDir(path)
  tui:
    label(path, state)


proc removePath(path: string) =
  if dirExists(path):
    removeDir(path)
  elif fileExists(path):
    removeFile(path)


template remove*(pattern: string, name: string = "remove") =
  task name:
    for path in walkPattern(pattern):
      removePath(path)
  tui:
    label(pattern, state)


template download*(
  url: string,
  file: string = "",
  cached: bool = false,
  name: string = "download"
) =
  let downloadProgress = cast[ptr float](allocShared0(sizeof(float)))
  let target = if file == "": url.split('/')[^1] else: file

  task name:
    if cached and fileExists(target):
      downloadProgress[] = 1.0
    else:
      let partial = target & ".download"
      var client = newHttpClient()
      client.onProgressChanged = proc(total, current, speed: BiggestInt) {.closure, gcsafe.} =
        {.cast(gcsafe).}:
          downloadProgress[] = current.float / total.float
      client.downloadFile(url, partial)
      client.close()
      moveFile(partial, target)
      downloadProgress[] = 1.0

  tui:
    if state == Done:
      bar(target, 1.0, state)
    else:
      bar(target, downloadProgress[], state)


template wait*(seconds: float, name: string = "wait") =
  let waitProgress = cast[ptr float](allocShared0(sizeof(float)))
  let waitSteps = int(seconds / 0.016)

  task name:
    for i in 0 ..< waitSteps:
      waitProgress[] = i.float / waitSteps.float
      sleep(16)
    waitProgress[] = 1.0

  tui:
    if state == Done:
      bar(1.0, state)
    else:
      bar(waitProgress[], state)


template compile*(nim: Nim, file: string, flags: string = "", name: string = "nim.compile") =
  cmd("nim c " & flags & " " & file, name)


template run*(nim: Nim, file: string, flags: string = "", name: string = "nim.run") =
  cmd("nim r " & flags & " " & file, name)


template doc*(nim: Nim, file: string, flags: string = "", name: string = "nim.doc") =
  cmd("nim doc " & flags & " " & file, name)


template command*(nim: Nim, arguments: string, name: string = "nim") =
  cmd("nim " & arguments, name)

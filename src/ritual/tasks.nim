import std/[os, osproc, streams, httpclient, strutils]


#[
iterator cmd*(command: string): string =
  let process = startProcess(command, options = {poStdErrToStdOut, poEvalCommand})
  let stream = process.outputStream

  while not stream.atEnd:
    yield stream.readLine()

  process.close()
]#


template cmd*(command: string, name: string = "cmd") =
  #TODO
  discard


template copy*(source: string, destination: string, name: string = "copy") =
  task name:
    copyFile(source, destination)
  tui:
    if state == Done:
      label(source & " → " & bold & destination)
    else:
      label(source & " → " & destination)


template move*(source: string, destination: string, name: string = "move") =
  task name:
    moveFile(source, destination)
  tui:
    let boldCompleted = if state == Done: bold else: ""
    label(source & " → " & boldCompleted & destination)


template mkdir*(path: string, name: string = "mkdir") =
  task name:
    createDir(path)
  tui:
    label(path)


template remove*(path: string, name: string = "remove") =
  task name:
    removeFile(path)
  tui:
    label(path)


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
      bar(target, 1.0)
    else:
      bar(target, downloadProgress[])


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
      bar(1.0)
    else:
      bar(waitProgress[])

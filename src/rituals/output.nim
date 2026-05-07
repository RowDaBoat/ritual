import std/[os, tables, strformat, locks]


const defaultLogDir* = "log"


type LogCounter* = ref object
  lock: Lock
  outputDir*: string
  counts: Table[string, int]


type TaskLog* = ref object
  path: string
  file: File
  opened: bool


proc newLogCounter*(outputDir: string = defaultLogDir): LogCounter =
  result = LogCounter(outputDir: outputDir, counts: initTable[string, int]())
  initLock(result.lock)


proc nextLogPath*(counter: LogCounter, name: string): string =
  acquire(counter.lock)
  let index = counter.counts.getOrDefault(name, 0)
  counter.counts[name] = index + 1
  release(counter.lock)

  if index == 0:
    return counter.outputDir / &"{name}.log"
  counter.outputDir / &"{name}{index}.log"


proc newTaskLog*(path: string): TaskLog =
  TaskLog(path: path, opened: false)


proc ensureOpen(taskLog: TaskLog) =
  if taskLog.opened:
    return

  createDir(parentDir(taskLog.path))
  taskLog.file = open(taskLog.path, fmWrite)
  taskLog.opened = true


proc log*(taskLog: TaskLog, message: string) =
  taskLog.ensureOpen()
  taskLog.file.writeLine(message)
  taskLog.file.flushFile()


proc write*(taskLog: TaskLog, content: string) =
  if content.len == 0:
    return

  taskLog.ensureOpen()
  taskLog.file.write(content)
  taskLog.file.flushFile()


proc close*(taskLog: TaskLog) =
  if taskLog.opened:
    taskLog.file.close()

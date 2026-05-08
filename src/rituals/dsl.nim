import std/os
import std/exitprocs
import std/strformat
import std/strutils
import std/tables
import ritui
import jobs
import workers
import monitor
import output
export ritui, jobs, output


var rituals: Table[string, Job]
var ritualMonitor: ptr Monitor = cast[ptr Monitor](allocShared0(sizeof(Monitor)))


proc sigint() {.noconv.} =
  stdout.write reset & showCursor & "\n"
  stdout.flushFile()
  quit(0)


var ritualExecuted = false


proc executeRitual(name: string, rootJob: Job, scriptDir: string) =
  ritualExecuted = true
  var pool = newWorkerPool()

  setCurrentDir(scriptDir)
  ritualMonitor[] = startMonitor(name, rootJob)
  pool.execute(rootJob)
  pool.shutdown()
  ritualMonitor[].stop()
  deallocShared(ritualMonitor)


proc exitCheck() {.noconv.} =
  if ritualExecuted:
    return

  if paramCount() < 1:
    echo "No ritual to invoke."
  else:
    echo &"Unknown ritual: '{paramStr(1)}'"

  quit(1)


setControlCHook(sigint)
addExitProc(exitCheck)


template ritual*(ritualName: string, body: untyped) =
  block:
    var jobStack: seq[Job]
    var logCounter = newLogCounter()

    template logDir(dir: string) {.used.} =
      logCounter.outputDir = dir

    template task(taskName: string, taskBody: untyped) {.used.} =
      let taskLogPath = logCounter.nextLogPath(taskName)
      let job = run(taskName, nil)

      job.procedure = proc() =
        let taskLog {.inject, used.} = newTaskLog(taskLogPath)

        template log(message: string) {.used.} =
          taskLog.log(message)

        try:
          taskBody
        except Exception as error:
          taskLog.close()
          job.state = Failed
          {.cast(gcsafe).}:
            ritualMonitor[].fail(taskName, error.msg, taskLogPath)
          quit(1)
        taskLog.close()

      jobStack[^1].children.add job

    template tui(tuiBody: untyped) {.used.} =
      let lastJob = jobStack[^1].children[^1]

      lastJob.renderer = proc(
        vtui: var Vtui,
        name: string,
        state {.inject.}: TaskState,
        maxNameLen: int,
        tick {.inject.}: int
      ) {.closure.} =
        template bar(value: float, barState {.inject.}: TaskState = state) {.used.} =
          vtui.drawBar(name, "", value, maxNameLen, tick, barState)

        template bar(label: string, value: float, barState {.inject.}: TaskState = state) {.used.} =
          vtui.drawBar(name, label, value, maxNameLen, tick, barState)

        template label(text: string, labelState {.inject.}: TaskState = state) {.used.} =
          vtui.drawLabel(name, text, maxNameLen, tick, labelState)

        tuiBody

    template parallel(parallelBody: untyped) {.used.} =
      jobStack.add jobs.parallel()
      parallelBody
      let frame = jobStack.pop()
      jobStack[^1].children.add frame

    template sequential(seqBody: untyped) {.used.} =
      jobStack.add jobs.sequential()
      seqBody
      let frame = jobStack.pop()
      jobStack[^1].children.add frame

    template recite(targetName: string) {.used.} =
      jobStack[^1].children.add rituals[targetName]

    jobStack.add jobs.sequential()

    body

    let rootJob = jobStack.pop()
    rituals[ritualName] = rootJob

    if paramCount() >= 1 and paramStr(1) == ritualName:
      let scriptDir = parentDir(instantiationInfo(-1, true).filename)
      executeRitual(ritualName, rootJob, scriptDir)

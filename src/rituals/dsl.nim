import std/os
import std/exitprocs
import std/strformat
import std/terminal
import std/tables
import std/locks
import std/compilesettings
import ritui
import jobs
import workers
import monitor
import output
export ritui, jobs, output


var rituals: Table[string, Job]
var ritualMonitor: ptr Monitor = cast[ptr Monitor](allocShared0(sizeof(Monitor)))
var ritualExecuted = false
var cwdLock*: Lock

cwdLock.initLock()


proc sigint() {.noconv.} =
  stdout.write reset & showCursor & "\n"
  stdout.flushFile()
  quit(0)


proc exitCheck() {.noconv.} =
  if ritualExecuted:
    return

  if paramCount() < 1:
    styledEcho fgRed, "Error: ", resetStyle, "No ritual to invoke."
  else:
    echo &"Unknown ritual: '{paramStr(1)}'"

  quit(1)


setControlCHook(sigint)
addExitProc(exitCheck)


template ritual*(ritualName: string, body: untyped) =
  block:
    let scriptDir = parentDir(instantiationInfo(-1, true).filename)
    let projectDir = parentDir(querySetting(projectFull))
    let packageName = lastPathPart(scriptDir)
    let isPackageRitual = scriptDir == projectDir
    let callDir {.inject, used.} = getCurrentDir()
    var jobStack: seq[Job]
    var logCounter = newLogCounter()
    var pool: WorkerPool = nil
    var lastBarrier: Barrier = nil
    var pendingChild: Job = nil
    var shouldExecute = false

    proc flushPending(pending: var Job) =
      if pending == nil:
        return

      let child = pending
      pending = nil

      jobStack[^1].children.add child

      if shouldExecute and jobStack.len == 1:
        let doneBarrier = newBarrier(1)
        lastBarrier = pool.execute(child, lastBarrier)
        pool.send doneBarrier.release
        doneBarrier.waitSync()

    template sync() {.used.} =
      flushPending(pendingChild)

    template task(taskName: string, taskBody: untyped) {.used.} =
      flushPending(pendingChild)
      let taskLogPath = logCounter.nextLogPath(taskName)
      let job = run(taskName, nil)
      job.scriptDir = scriptDir

      job.procedure = proc() =
        {.cast(gcsafe).}:
          cwdLock.acquire()
          setCurrentDir(job.scriptDir)
          cwdLock.release()
        let taskLog {.inject, used.} = newTaskLog(taskLogPath)

        template log(message: string) {.used.} =
          taskLog.log(message)

        try:
          taskBody
        except Exception as error:
          job.state = Failed
          {.cast(gcsafe).}:
            ritualMonitor[].fail(taskName, error.msg, taskLogPath)
          quit(1)
        finally:
          taskLog.close()

      if jobStack.len == 1:
        pendingChild = job
      else:
        jobStack[^1].children.add job

    template tui(tuiBody: untyped) {.used.} =
      let targetJob =
        if pendingChild != nil:
           pendingChild
        else:
          jobStack[^1].children[^1]

      targetJob.renderer = proc(
        vtui: var Vtui,
        name: string,
        state {.inject.}: TaskState,
        maxNameLen: int,
        tick {.inject.}: int
      ) {.closure.} =
        {.cast(gcsafe).}:
          cwdLock.acquire()
        setCurrentDir(targetJob.scriptDir)

        template bar(value: float, barState {.inject.}: TaskState = state) {.used.} =
          vtui.drawBar(name, "", value, maxNameLen, tick, barState)

        template bar(label: string, value: float, barState {.inject.}: TaskState = state) {.used.} =
          vtui.drawBar(name, label, value, maxNameLen, tick, barState)

        template label(text: string, labelState {.inject.}: TaskState = state) {.used.} =
          vtui.drawLabel(name, text, maxNameLen, tick, labelState)

        template option(rowName: string, text: string, selected: bool, optionState {.inject.}: TaskState = state) {.used.} =
          vtui.drawOption(rowName, text, maxNameLen, selected, tick, optionState)

        tuiBody
        {.cast(gcsafe).}:
          cwdLock.release()

    template parallel(parallelBody: untyped) {.used.} =
      flushPending(pendingChild)
      jobStack.add jobs.parallel()
      parallelBody
      let frame = jobStack.pop()

      if jobStack.len == 1:
        pendingChild = frame
      else:
        jobStack[^1].children.add frame

    template sequential(seqBody: untyped) {.used.} =
      flushPending(pendingChild)
      jobStack.add jobs.sequential()
      seqBody
      let frame = jobStack.pop()

      if jobStack.len == 1:
        pendingChild = frame
      else:
        jobStack[^1].children.add frame

    template recite(targetName: string) {.used.} =
      flushPending(pendingChild)

      if not rituals.hasKey(targetName):
        if shouldExecute:
          let errorMessage = "can't recite unknown ritual: '" & targetName & "'"
          ritualMonitor[].fail(ritualName, errorMessage, "")
          pool.shutdown()
          quit(1)

      if jobStack.len == 1:
        pendingChild = rituals[targetName]
      else:
        jobStack[^1].children.add rituals[targetName]

    jobStack.add jobs.sequential()

    let rootJob = jobStack[0]
    rootJob.scriptDir = scriptDir

    let isBuiltin = packageName == "builtin"
    let registerName = case isPackageRitual or isBuiltin
    of true:  ritualName
    of false: packageName & "." & ritualName
    rituals[registerName] = rootJob

    shouldExecute = paramCount() >= 1 and paramStr(1) == registerName
    if shouldExecute:
      ritualExecuted = true
      pool = newWorkerPool()
      setCurrentDir(scriptDir)
      ritualMonitor[] = startMonitor(registerName, rootJob)

    body

    flushPending(pendingChild)

    if shouldExecute:
      pool.shutdown()
      ritualMonitor[].stop()
      deallocShared(ritualMonitor)

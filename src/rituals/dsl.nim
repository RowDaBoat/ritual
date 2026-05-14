import std/[os, exitprocs, strformat, terminal, tables, locks, compilesettings]
import ritui, jobs, output, workers, monitor
export ritui, jobs, output


var rituals: Table[string, Job]
var ritualMonitor: ptr Monitor = cast[ptr Monitor](allocShared0(sizeof(Monitor)))
var ritualExecuted = false
var plaintextMode = false
var cwdLock*: Lock

cwdLock.initLock()

block:
  for i in 1 .. paramCount():
    if paramStr(i) == "--plaintext":
      plaintextMode = true
      break


proc sigint() {.noconv.} =
  if not plaintextMode:
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
      let job = run(taskName, nil)
      job.scriptDir = scriptDir
      job.logPath = logCounter.nextLogPath(taskName)

      job.procedure = proc() =
        {.cast(gcsafe).}:
          cwdLock.acquire()
          setCurrentDir(job.scriptDir)
          cwdLock.release()
        let taskLog {.inject, used.} = newTaskLog(job.logPath)

        template log(message: string) {.used.} =
          taskLog.log(message)

        try:
          taskBody
        except Exception as error:
          job.state = Failed
          {.cast(gcsafe).}:
            ritualMonitor[].fail(job.name, error.msg, job.logPath)
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

      let resolvedName =
        if '.' in targetName: targetName
        else: packageName & "." & targetName

      if not rituals.hasKey(resolvedName):
        if shouldExecute:
          let errorMessage = "can't recite unknown ritual: '" & resolvedName & "'"
          ritualMonitor[].fail(ritualName, errorMessage, "")
          pool.shutdown()
          quit(1)
      else:
        if jobStack.len == 1:
          pendingChild = rituals[resolvedName]
        else:
          jobStack[^1].children.add rituals[resolvedName]

    jobStack.add jobs.sequential()

    let rootJob = jobStack[0]
    rootJob.scriptDir = scriptDir

    let isBuiltin = packageName == "builtin"
    let qualifiedName = packageName & "." & ritualName
    let registerName = if isBuiltin: ritualName else: qualifiedName
    rituals[registerName] = rootJob

    let invokedName = if paramCount() >= 1: paramStr(1) else: ""
    let executePackageOrBuiltin = invokedName == ritualName and (isPackageRitual or isBuiltin)
    let executeQualified = invokedName == qualifiedName

    if executePackageOrBuiltin or executeQualified:
      ritualExecuted = true
      shouldExecute = true
      pool = newWorkerPool()
      setCurrentDir(scriptDir)
      ritualMonitor[] = startMonitor(ritualName, rootJob, plaintextMode)

    body

    flushPending(pendingChild)

    if shouldExecute:
      pool.shutdown()
      ritualMonitor[].stop()
      deallocShared(ritualMonitor)

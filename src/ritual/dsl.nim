import std/os
import std/exitprocs
import std/strformat
import ritui
import jobs
import workers
import monitor
export ritui, jobs


var ritualExecuted = false

addExitProc(proc() {.noconv.} =
  if ritualExecuted:
    return

  if paramCount() < 1:
    echo "No ritual to run."
  else:
    echo &"Unknown ritual: '{paramStr(1)}'"

  quit(1)
)


template ritual*(ritualName: string, body: untyped) =
  if paramCount() >= 1 and paramStr(1) == ritualName:
    ritualExecuted = true
    let scriptDir = parentDir(instantiationInfo(-1, true).filename)
    setCurrentDir(scriptDir)

    var pool = newWorkerPool()
    var jobStack: seq[Job]

    template task(taskName: string, taskBody: untyped) =
      let job = run(taskName, proc() =
        taskBody
      )
      jobStack[^1].children.add job

    template tui(tuiBody: untyped) =
      let lastJob = jobStack[^1].children[^1]

      lastJob.renderer = proc(
        vtui: var Vtui,
        name: string,
        state {.inject.}: TaskState,
        maxNameLen: int,
        tick {.inject.}: int
      ) {.closure.} =
        template bar(value: float) {.used.} =
          vtui.drawBar(name, "", value, maxNameLen, tick)

        template bar(label: string, value: float) {.used.} =
          vtui.drawBar(name, label, value, maxNameLen, tick)

        template label(text: string) {.used.} =
          vtui.drawLabel(name, text, maxNameLen)

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

    jobStack.add jobs.sequential()

    body

    let rootJob = jobStack.pop()
    var monitor = newMonitor(ritualName, rootJob)

    discard pool.execute(rootJob)
    pool.shutdown()
    monitor.stop()

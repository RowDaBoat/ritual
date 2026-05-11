import std/os
import ritui, jobs


type ShutdownKind* = enum
  Stop
  Fail


type Shutdown* = object
  case kind*: ShutdownKind
  of Stop:
    discard
  of Fail:
    taskName*: string
    errorMessage*: string
    logPath*: string


type MonitorArgs = object
  shutdownChannel: ptr Channel[Shutdown]
  rootJob: Job
  name: string


type Monitor* = object
  thread: Thread[MonitorArgs]
  shutdownChannel: ptr Channel[Shutdown]


proc maxNameLen(job: Job): int =
  case job.kind
  of Run:
    result = job.name.len
  else:
    for child in job.children:
      let childLen = maxNameLen(child)

      if childLen > result:
        result = childLen


proc collectActive(job: Job, active: var seq[Job]) =
  case job.kind
  of Run:
    if job.state != Pending and job.startTick < 0:
      active.add job
  else:
    for child in job.children:
      collectActive(child, active)


proc renderJob(vtui: var Vtui, job: Job, maxLen: int, tick: int) =
  if job.renderer == nil:
    return

  var jobTick = tick - job.startTick
  if job.state == Done:
    jobTick = job.lastTick

  job.renderer(vtui, job.name, job.state, maxLen, jobTick)
  job.lastTick = jobTick


proc printError(signal: Shutdown) =
  stdout.write fg(196) & "Error in task '" & signal.taskName & "': " & signal.errorMessage & reset & "\n"

  if signal.logPath == "" or not fileExists(signal.logPath):
    return

  stdout.write "\n"
  stdout.write readFile(signal.logPath)
  stdout.write "\n"


proc renderFrame(vtui: var Vtui, rootJob: Job, renderOrder: var seq[Job], maxLen: int) =
  var newlyActive: seq[Job]
  collectActive(rootJob, newlyActive)

  for job in newlyActive:
    job.startTick = vtui.tick
    renderOrder.add job

  beginFrame(vtui)

  for job in renderOrder:
    renderJob(vtui, job, maxLen, vtui.tick)

  endFrame(vtui)
  inc vtui.tick


proc loop(args: MonitorArgs) {.thread.} =
  var vtui: Vtui
  vtui.drawHeader(args.name)

  var renderOrder: seq[Job]

  while true:
    let maxLen = maxNameLen(args.rootJob)
    {.cast(gcsafe).}:
      renderFrame(vtui, args.rootJob, renderOrder, maxLen)

    let shutdown = args.shutdownChannel[].tryRecv()
    if shutdown.dataAvailable:
      {.cast(gcsafe).}:
        renderFrame(vtui, args.rootJob, renderOrder, maxLen)

      vtui.drawFooter()
      case shutdown.msg.kind
      of Stop:
        discard
      of Fail:
        printError(shutdown.msg)
      break

    sleep(16)


proc startMonitor*(name: string, rootJob: Job): Monitor =
  result.shutdownChannel = cast[ptr Channel[Shutdown]](allocShared0(sizeof(Channel[Shutdown])))
  result.shutdownChannel[].open()
  createThread(result.thread, loop, MonitorArgs(
    shutdownChannel: result.shutdownChannel,
    rootJob: rootJob,
    name: name
  ))


proc stop*(monitor: var Monitor) =
  monitor.shutdownChannel[].send(Shutdown(kind: Stop))
  joinThread(monitor.thread)
  monitor.shutdownChannel[].close()
  deallocShared(monitor.shutdownChannel)


proc fail*(monitor: var Monitor, taskName: string, errorMessage: string, logPath: string) =
  monitor.shutdownChannel[].send(Shutdown(kind: Fail, taskName: taskName, errorMessage: errorMessage, logPath: logPath))
  joinThread(monitor.thread)
  monitor.shutdownChannel[].close()
  deallocShared(monitor.shutdownChannel)

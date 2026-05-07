import std/os
import ritui
import jobs


type MonitorArgs = object
  stopChannel: ptr Channel[bool]
  rootJob: Job
  name: string

type Monitor* = object
  thread: Thread[MonitorArgs]
  stopChannel: ptr Channel[bool]


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


proc loop(args: MonitorArgs) {.thread.} =
  var vtui: Vtui
  vtui.drawHeader(args.name)

  let maxLen = maxNameLen(args.rootJob)
  var renderOrder: seq[Job]

  while true:
    {.cast(gcsafe).}:
      var newlyActive: seq[Job]
      collectActive(args.rootJob, newlyActive)

      for job in newlyActive:
        job.startTick = vtui.tick
        renderOrder.add job

      beginFrame(vtui)

      for job in renderOrder:
        renderJob(vtui, job, maxLen, vtui.tick)

    endFrame(vtui)
    inc vtui.tick

    if args.stopChannel[].tryRecv().dataAvailable:
      break

    sleep(16)

  vtui.drawFooter()


proc newMonitor*(name: string, rootJob: Job): Monitor =
  result.stopChannel = cast[ptr Channel[bool]](allocShared0(sizeof(Channel[bool])))
  result.stopChannel[].open()
  createThread(result.thread, loop, MonitorArgs(
    stopChannel: result.stopChannel,
    rootJob: rootJob,
    name: name
  ))


proc stop*(monitor: var Monitor) =
  monitor.stopChannel[].send(true)
  joinThread(monitor.thread)
  monitor.stopChannel[].close()
  deallocShared(monitor.stopChannel)

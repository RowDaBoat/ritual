import std/[cpuinfo, locks]


type Barrier* {.acyclic.} = ref object
  lock: Lock
  cond: Cond
  count: int


type TaskKind* = enum
  Work
  Hold
  Release
  Wait
  Shutdown


type Task* = object
  case kind*: TaskKind
  of Work:
    procedure*: proc()
  of Hold, Release, Wait:
    barrier*: Barrier
  of Shutdown:
    discard


type Worker = object
  thread: Thread[ptr Channel[Task]]
  channel: Channel[Task]


type WorkerPool* = ref object
  workers: seq[Worker]
  nextWorker*: int
  procs: seq[proc()]

proc newBarrier*(initialCount: int = 0): Barrier =
  result = Barrier(count: initialCount)
  initLock(result.lock)
  initCond(result.cond)


proc waitSync*(barrier: Barrier) =
  acquire(barrier.lock)
  while barrier.count > 0:
    wait(barrier.cond, barrier.lock)
  release(barrier.lock)


proc hold*(barrier: Barrier): Task =
  Task(kind: Hold, barrier: barrier)


proc release*(barrier: Barrier): Task =
  Task(kind: Release, barrier: barrier)


proc wait*(barrier: Barrier): Task =
  Task(kind: Wait, barrier: barrier)


proc work*(procedure: proc()): Task =
  Task(kind: Work, procedure: procedure)


proc shutdown*(): Task =
  Task(kind: Shutdown)


proc workerLoop(chan: ptr Channel[Task]) {.thread, nimcall.} =
  while true:
    let task = chan[].recv()
    {.cast(gcsafe).}:
      case task.kind
      of Work:
        task.procedure()
      of Hold:
        acquire(task.barrier.lock)
        inc task.barrier.count
        release(task.barrier.lock)
      of Release:
        acquire(task.barrier.lock)
        dec task.barrier.count
        if task.barrier.count == 0:
          broadcast(task.barrier.cond)
        release(task.barrier.lock)
      of Wait:
        acquire(task.barrier.lock)
        while task.barrier.count > 0:
          wait(task.barrier.cond, task.barrier.lock)
        release(task.barrier.lock)
      of Shutdown:
        break


proc newWorkerPool*(processors: int = countProcessors()): WorkerPool =
  result = WorkerPool()
  result.workers = newSeq[Worker](processors)

  for i in 0 ..< processors:
    result.workers[i].channel.open()
    createThread(result.workers[i].thread, workerLoop, addr result.workers[i].channel)


proc send*(pool: WorkerPool, task: Task) =
  if task.kind == Work:
    pool.procs.add task.procedure

  pool.workers[pool.nextWorker].channel.send(task)


proc next*(pool: WorkerPool) =
  pool.nextWorker = (pool.nextWorker + 1) mod pool.workers.len


proc workerCount*(pool: WorkerPool): int =
  pool.workers.len


proc shutdown*(pool: WorkerPool) =
  for i in 0 ..< pool.workers.len:
    pool.workers[i].channel.send(shutdown())

  for i in 0 ..< pool.workers.len:
    joinThread(pool.workers[i].thread)
    pool.workers[i].channel.close()

  pool.procs.setLen(0)

# Ritual
A task runner for Nim behind a TUI with parallel execution and a clean DSL.


## Example
`ritual.nim`:
```nim
import ritual

ritual "build":
  parallel:
    download(
      "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz",
      name = "linux",
      cached = true
    )
    download(
      "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso",
      name = "debian",
      cached = true
    )

  mkdir("output")
  move(
    "linux-6.6.tar.xz",
    "output/linux.tar.xz"
  )
  move(
    "debian-13.4.0-amd64-netinst.iso",
    "output/debian.iso"
  )
```
Run it with:
```sh
nim r ritual.nim build
```


## Installation
Add ritual as a dependency in your `.nimble` file:
```
requires "ritual"
```


## Features
- Parallel and sequential task execution.
- Real-time TUI with animated progress bars and status labels.
- Built-in tasks: `cmd`, `download`, `copy`, `move`, `mkdir`, `remove`, `wait`.
- Nim toolchain tasks: `nim.compile`, `nim.run`, `nim.doc`, `nim.command`.
- Ritual composition via `recite` to invoke rituals from other rituals.
- Custom tasks with `task:` and custom rendering with `tui:`.
- Per-task log output with configurable output directory.
- Error handling with colored failure states and log output on crash.
- Graceful Ctrl+C interrupt handling.


## DSL
- Use the `ritual {name}: {body}` template to define a list of executable tasks.
- Use `parallel: {body}` and `sequential: {body}` to run tasks sequentially or in parallel, default is sequential. Both can be nested to wire the execution.
- Current tasks are: `cmd`, `copy`, `move`, `mkdir`, `remove`, `download`, `wait`, `nim.compile`, `nim.run`, `nim.doc`, `nim.command`.
- Creating a task is done by using `task {name}:`, `tui:`. The `tui` block receives `state`:
  ```nim
  task "compile":
    discard execProcess("nim c src/app.nim")
  tui:
    label("compile app")
  ```


## Controls
The `tui:` template has a few controls available:
- `bar(value)` or `bar(label, value)` draws a progress bar.
- `label(text)` draws a status label.


## Nim tasks
The `nim` object provides tasks for common Nim toolchain commands:
```nim
ritual "build":
  nim.compile "src/app.nim"
  nim.compile "src/lib.nim", flags = "-d:release"
  nim.run "tests/test_all.nim"
  nim.doc "src/app.nim"
  nim.command "check src/app.nim"
```

Each nim task accepts an optional `name` parameter for display and logging.


## Ritual composition
Use `recite` to invoke a previously defined ritual from within another:
```nim
ritual "compile":
  nim.compile "src/app.nim", flags = "-d:release"

ritual "release":
  recite "compile"
  copy("bin/app", "dist/app")
```

The composed ritual's tasks are incorporated into the calling ritual's execution.


## Output management
Each task can produce log output written log files which are created lazily on first write, so tasks that produce no output don't create empty files.

Log files are written to `log/{name}.log`, with an incremental suffix for repeated names (`{name}1.log`, `{name}2.log`, etc.). To change the output directory:
```nim
ritual "build":
  logDir "build-output"
  # ...
```

Inside a `task` block, use `log(message)` to write a line to the task's log file:
```nim
task "setup":
  log("starting setup")
  # ...
```

The `cmd` task automatically forwards both stdout and stderr to its log file.


## Error handling
When a task raises an exception, ritual immediately stops execution. The TUI closes, then the error message and the task's full log output (if any) are printed below.

In the TUI, failed tasks are rendered in red: labels get red text and progress bars show "ERROR" instead of a percentage. The `Failed` state is available in `tui:` blocks for custom rendering.


## Interrupt handling
Pressing Ctrl+C gracefully stops ritual execution, resets the terminal, and restores the cursor.

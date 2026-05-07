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
- Built-in tasks: `download`, `copy`, `move`, `mkdir`, `remove`, `exec`, `wait`.
- Custom tasks with `task:` and custom rendering with `tui:`.


## DSL
- Use the `ritual {name}: {body}` template to define a list of executable tasks
- Use `parallel: {body}` and `sequential: {body}` to run tasks sequentially or in parallel, default is sequential. Both can be nested to wire the execution.
- Current tasks are: `exec`, `copy`, `move`, `mkdir`, `remove`, `download`, `wait`, more will be added later on.
- Creating a task is done by using `task {name}:`, `tui:`. The `tui` block receives `state`:
  ```nim
  task "compile":
    # Command running on its own thread.
    # It should lock until the task is completed.
    discard execProcess("nim c src/app.nim")
  tui:
    # Render the task's tui, receives 'state'.
    # 'state' can be 'Pending', 'Running', 'Done'.
    label("compile app")
  ```


## Controls
The `tui:` template has a few controls available:
- `bar(value)` or `bar(label, value)` draws a progress bar.
- `label(text)` draws a status label.


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

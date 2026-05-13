# Rituals
A task runner for Nim behind a TUI with parallel execution and a clean DSL.


## Example
`ritual.nim`:
```nim
import rituals

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
  move("linux-6.6.tar.xz", "output/linux.tar.xz")
  move("debian-13.4.0-amd64-netinst.iso", "output/debian.iso")
```
If `rituals` is in the dependencies, just run it with:
```sh
nim r ritual.nim build
```


## Installation
### Lean
- Add ritual as a dependency in your project's `.nimble` file:
  ```nim
  requires "git@github.com:RowDaBoat/rituals.git"
  ```
- Resolve the dependency with whatever method you use: `nimby`, `nimble`, or a `--path:` flag.
- Run as before: `nim r ritual.nim {ritual_name}`


### Complete
To install `rituals` completely run:
```sh
nim r --path:/path/to/rituals/src --eval:"import rituals" -- install-ritual
```
Now you can run rituals with just:
```sh
ritual {ritual_name}
```
You can also work with flat workspaces.


## Flat workspaces: `ritual`+`nimby`
`nimby`'s workflow is to have a flat workspace with all dependencies. `rituals` builds on top of that idea, allowing to create complex pipelines by calling rituals from other packages.

Using both allows an approach to dependency management that lies between monorepos and traditional dependencies.

- Creating a workspace:
  ```sh
  mkdir my.workspace && cd my.workspace
  # Clone all dependencies and create a 'nim.cfg' pointing to each one.
  nimby install git@github.com:my/project.git
  # Create a 'ritual.cfg' file that points to each 'ritual.nim' on each dependency.
  ritual workspace
  ```
- Once that is done, the following can be used on `ritual.nim` files:
  ```nim
  ritual "my-ritual":
    recite "otherpackage.other-ritual"
  ```


## Features
- Parallel and sequential task execution.
- Real-time TUI with animated progress bars and status labels.
- Built-in tasks: `cmd`, `download`, `copy`, `move`, `mkdir`, `remove`, `wait`.
- Nim toolchain tasks: `nim.compile`, `nim.run`, `nim.doc`, `nim.command`.
- Ritual composition via `recite` to invoke rituals from the same or other packages.
- Custom tasks with `task:` and custom rendering with `tui:`.
- Per-task log output with configurable output directory.
- Error handling with colored failure states and log output on crash.


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
- `bar(value, state)` or `bar(label, value, state)` draws a progress bar with animated fill and percentage indicator. Takes a float between 0.0 and 1.0.
- `label(text, state)` draws a status label with a state-aware bullet indicator (filled when done, animated when running, hollow on failure).
- `option(name, text, selected, state)` draws an option for the user to choose.


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

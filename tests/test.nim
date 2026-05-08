import std/os
import ../src/rituals

ritual "basic":
  parallel:
    download(
      "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz",
      name = "linux",
      cached = false
    )
    download(
      "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso",
      name = "debian",
      cached = false
    )
    task "sleep":
      sleep(3000)
    tui:
      label("u___u just 3 more seconds...", state)


  mkdir("output")
  move(
    "linux-6.6.tar.xz",
    "output/linux.tar.xz"
  )
  move(
    "debian-13.4.0-amd64-netinst.iso",
    "output/debian.iso"
  )


ritual "simplefail":
  cmd("echo 'This should work.'")
  wait(1.0, name = "working")

  task "broken":
    raise newException(IOError, "Task failed successfully.")
  tui:
    label("should fail", state)

  cmd("echo 'This should never run.'")


ritual "barfail":
  parallel:
    wait(1.0, name = "working")
    task "sleep":
      sleep(1000)
    tui:
      label("u___u just 1 more second...", state)

    sequential:
      wait(2.0, name = "waiting")
      task "broken":
        raise newException(IOError, "Task failed successfully.")
      tui:
        bar(0.5, state)

  cmd("echo 'This should never run.'")


ritual "nimtest":
  nim.compile("test.nim", flags = "--threads:on", name = "compile test")
  nim.command("--version", name = "nim version")


ritual "clean":
  remove("log")
  remove("output")
  remove("test")
  remove("linux-*")
  remove("debian-*")

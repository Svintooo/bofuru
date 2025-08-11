#Requires AutoHotkey v2.0

lib_consoleMsg(msg, wait_for_enter := false) {
  static stdin  := false
  static stdout := false

  ; 1. Allocate a console on first call
  if (!stdout) {
    ; WinAPI call to create a console window
    DllCall("AllocConsole")
    stdin  := FileOpen("*", "r")
    stdout := FileOpen("*", "w")
  }

  ; 2. Write the message to the console
  stdout.WriteLine(msg)
  stdout.Read(0) ; Flush the write buffer.

  ; 3. Wait for Enter
  if wait_for_enter {
    stdout.Write("(press enter to continue...)")
    stdout.Read(0) ; Flush the write buffer.
    stdin.ReadLine()
  }
}

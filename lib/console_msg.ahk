#Requires AutoHotkey v2.0

ConsoleMsg(msg, wait_for_enter := false) {
  static hConsole := false
  static ih

  ; 1. Allocate a console on first call
  if (!hConsole) {
    DllCall("AllocConsole")  ; WinAPI call to create a console window
    hConsole := DllCall("kernel32.dll\GetConsoleWindow", "Ptr")
    ih := InputHook("", "{Enter}{NumpadEnter}")
  }

  ; 2. Write the message to the console
  ;    FileAppend to "*" writes directly to the script’s console
  FileAppend(msg . "`n", "*")

  ; 3. Wait for Enter
  if wait_for_enter {
    FileAppend("(press enter to continue...)" . "`n", "*")
    while true
    {
      ih.Start(), ih.Wait(), ih.Stop()
      hForeground := DllCall("user32.dll\GetForegroundWindow", "Ptr")
      if hConsole = hForeground
        break
    }
  }
}

lib_canWindowBeFullscreened(hWnd, className) {
  ;NOTE: Code has been explicitly written to return as quickly as possible.
  ;      Not all functions are called if an earlier function returns false.
  if ! lib_isWindowClassAllowed(className)
    return false

  if ! lib_havePermissionForWindow(hWnd)
    return false

  return true
}

; Returns false if the script does not have permission to modify the window
lib_havePermissionForWindow(hWnd) {
  try {
    WinMove(,,,, hWnd)
    return true
  } catch {
    return false
  }
}

; Returns false if window class is in the blocklist
lib_isWindowClassAllowed(className) {
  static BLOCKED_CLASSES := Map(
    ; https://learn.microsoft.com/en-gb/windows/win32/winmsg/about-window-classes
    "Button",true,     ; button
    "ComboBox",true,   ; combo box
    "Edit",true,       ; edit control
    "ListBox",true,    ; list box
    "MDIClient",true,  ; MDI client window
    "ScrollBar",true,  ; scroll bar
    "Static",true,     ; static control
    "ComboLBox",true,  ; list box contained in a combo box
    "DDEMLEvent",true, ; DDEML events
    "Message",true,    ; message-only window
    "#32768",true,     ; menu (ex: when you click top left icon in a window title)
    "#32769",true,     ; desktop window
    "#32770",true,     ; dialog box
    "#32771",true,     ; task switch window
    "#32772",true,     ; icon titles

    ; Misc
    "Progman",true,                       ; Desktop - No wallpaper
    "WorkerW",true,                       ; Desktop - With wallpaper
    "PseudoConsoleWindow",true,           ; Win11 cmd.exe
    "ConsoleWindowClass",true,            ; Win11 cmd.exe
    "CASCADIA_HOSTING_WINDOW_CLASS",true, ; Win11 cmd.exe
    "CabinetWClass",true,                 ; Win11 FileExplorer
    "Shell_TrayWnd",true,                 ; Win11 Taskbar
    "Shell_SecondaryTrayWnd",true,        ; Win11 Taskbar
  )

  return ! BLOCKED_CLASSES.Has(className)
}

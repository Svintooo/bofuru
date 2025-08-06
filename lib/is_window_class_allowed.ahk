lib_isWindowClassAllowed(className) {
  ; https://learn.microsoft.com/en-gb/windows/win32/winmsg/about-window-classes?redirectedfrom=MSDN
  BLOCKED_CLASSES := [
    "Button",     ; button
    "ComboBox",   ; combo box
    "Edit",       ; edit control
    "ListBox",    ; list box
    "MDIClient",  ; MDI client window
    "ScrollBar",  ; scroll bar
    "Static",     ; static control
    "ComboLBox",  ; list box contained in a combo box
    "DDEMLEvent",
    "Message",    ; message-only window
    "#32768",     ; menu (ex: when you click top left icon in a window title)
    "#32769",     ; desktop window
    "#32770",     ; dialog box
    "#32771",     ; task switch window
    "#32772",     ; icon titles

    ; Misc
    "Progman",                       ; Desktop - No wallpaper
    "WorkerW",                       ; Desktop - With wallpaper
    "PseudoConsoleWindow",           ; Win11 cmd.exe
    "ConsoleWindowClass",            ; Win11 cmd.exe
    "CASCADIA_HOSTING_WINDOW_CLASS", ; Win11 cmd.exe
    "CabinetWClass",                 ; Win11 FileExplorer
    "Shell_TrayWnd",                 ; Win11 Taskbar
    "Shell_SecondaryTrayWnd",        ; Win11 Taskbar
  ]

  return ! BLOCKED_CLASSES.Contains(className)
}
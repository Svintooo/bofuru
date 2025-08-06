#Requires AutoHotkey v2.0
SetTitleMatchMode "RegEx"

; Wrapper around standard library WinWait()
; https://www.autohotkey.com/docs/v2/lib/WinWait.htm
Bofuru_WinWait(WinTitle, timeout := 0) {
  ; App Windows of these Class types will be ignored
  ; https://learn.microsoft.com/en-gb/windows/win32/winmsg/about-window-classes?redirectedfrom=MSDN
  IGNORED_CLASSES := [
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
    "Progman",  ; Desktop - No wallpaper
    "WorkerW",  ; Desktop - With wallpaper
    "PseudoConsoleWindow",  ; Win11 cmd.exe
    "CabinetWClass",        ; Win11 FileExplorer
  ]
  ; This is the reason why this is set at the beginning of this file: SetTitleMatchMode "RegEx"
  AHK_CLASS_IGNORE := Format("ahk_class ^(?!{})", IGNORED_CLASSES.Collect(str => str "$").Join("|"))

  fullWintitle := WinTitle " " AHK_CLASS_IGNORE

  if timeout {
    winWaitFunc := () => WinWait(fullWintitle, , timeout)
  } else {
    winWaitFunc := () => WinWait(fullWintitle)
  }

  hWnd := winWaitFunc()
  return hWnd
}

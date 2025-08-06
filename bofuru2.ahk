#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\stdlib.ahk
#Include %A_ScriptDir%\lib\console_msg.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\win_wait.ahk
#Include %A_ScriptDir%\lib\is_window_class_allowed.ahk

;; Test retrieving args
;ConsoleMsg(A_Args.Inspect())

;; Test run app and receive PID
;Run("calc.exe", , , &app_pid)
;ConsoleMsg(app_pid)

;; Start
ConsoleMsg("=== BoFuRu2 ===", false)
hWnd := manualWindowSelect()
game_hwnd := lib_WinWait("ahk_id" hWnd, _timeout := 5)
ConsoleMsg("    hwnd: " game_hwnd.Inspect(), false)
ConsoleMsg("winclass: " WinGetClass("ahk_id" game_hwnd), true)


;; Select a window by clicking on it
manualWindowSelect()
{
  ConsoleMsg("Click on game window to make it fullscreen.", false)
  ConsoleMsg("Press Esc to cancel.", false)

  while true
  {
    result := lib_userWindowSelect()
    if ! result.ok {
      ExitApp
    } else if ! lib_isWindowClassAllowed(result.className) {
      ConsoleMsg("Unallowed window: Try again", false)
      Continue ; Redo the while-loop
    } else {
      Break ; Quit the while-loop
    }
  }

  return result.hWnd
}

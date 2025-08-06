#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\lib\stdlib.ahk
#Include %A_ScriptDir%\lib\console_msg.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\bofuru__win_wait.ahk

;; Test retrieving args
;ConsoleMsg(A_Args.Inspect())

;; Test run app and receive PID
;Run("calc.exe", , , &app_pid)
;ConsoleMsg(app_pid)

;; Hehe
ConsoleMsg("START", false)
result := userWindowSelect(5)
if ! result.ok {
  Exit
}
game_hwnd := Bofuru_WinWait("ahk_id" result.hWnd, _timeout := 5)
ConsoleMsg("    game_hwnd: " game_hwnd.Inspect(), false)
ConsoleMsg("game_winclass: " WinGetClass("ahk_id" game_hwnd), true)

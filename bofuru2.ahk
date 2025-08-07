#Requires AutoHotkey v2.0

#Include %A_ScriptDir%\lib\stdlib.ahk
#Include %A_ScriptDir%\lib\console_msg.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\win_wait.ahk
#Include %A_ScriptDir%\lib\is_window_class_allowed.ahk

; Sets how matching is done for the WinTitle parameter used by various
; AHK functions.
SetTitleMatchMode "RegEx"

; Use coordinates relative to the screen instead of relative to the window for
; all AHK functions that sets/retrieves/uses mouse coordinates.
CoordMode "Mouse", "Screen"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sandbox

;; Test retrieving args
;ConsoleMsg(A_Args.Inspect())

;; Test run app and receive PID
;Run("calc.exe", , , &app_pid)
;ConsoleMsg(app_pid)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Start
ConsoleMsg("=== BoFuRu2 ===", _wait_for_enter := false)

;; Parse args
cnfg := parseArgs(A_Args)
ConsoleMsg("INFO: args: " cnfg.Inspect(), _wait_for_enter := false)

;; Run an *.exe
if cnfg.HasOwnProp("launch")
{
  ConsoleMsg("INFO: Launching: " cnfg.launch, _wait_for_enter := false)
  result := launchExe(cnfg.launch)
  if ! result.ok {
    ConsoleMsg("ERROR: Launch failed", _wait_for_enter := true)
    ExitApp
  }
  cnfg.pid := result.pid
  result := unset
  ConsoleMsg("INFO: Launch success, got PID: " cnfg.pid, _wait_for_enter := false)
}

;; Wait for a window to show up
if cnfg.HasOwnProp("ahk_wintitle")
{
  ConsoleMsg("INFO: Waiting for window: " cnfg.ahk_wintitle, _wait_for_enter := false)
  cnfg.hWnd := WinWait(cnfg.ahk_wintitle)
}

;; Wait for a window to show up belonging to PID
if ! cnfg.HasOwnProp("hWnd") && cnfg.HasOwnProp("pid")
{
  ;ConsoleMsg("INFO: Will exit when PID", false)
  ;Event_AppExit() { if not ProcessExist(fscr.app_pid) ExitApp(0) }
  ;SetTimer(Event_AppExit, , 2147483647)

  ConsoleMsg("INFO: Waiting for window beloning to PID", _wait_for_enter := false)
  cnfg.hWnd := false
  while !cnfg.hWnd && ProcessExist(cnfg.pid)
    cnfg.hWnd := WinWait("ahk_pid" cnfg.pid, , _timeout := 1)
  if !cnfg.hWnd
  {
    ConsoleMsg("ERROR: PID disappeared before window was found", _wait_for_enter := true)
    ExitApp
  }
}

;; Let user manually select a window
if ! cnfg.HasOwnProp("hWnd")
{
  ConsoleMsg("INFO: Manual Window selection activated", _wait_for_enter := false)
  ConsoleMsg("INSTRUCTIONS: Click on game window.", _wait_for_enter := false)
  ConsoleMsg("              Press Esc to cancel.", _wait_for_enter := false)
  result := lib_userWindowSelect()
  while result.ok && !lib_isWindowClassAllowed(result.className)
  {
    ConsoleMsg("ERROR: Unallowed window: Try again", _wait_for_enter := false)
    result := lib_userWindowSelect()
  }
  if ! result.ok  ; User cancelled the operation
    ExitApp
  cnfg.hWnd := result.hWnd
  result := unset
}

;; Print window info
cnfg.winClass := WinGetClass("ahk_id" cnfg.hWnd)
cnfg.winTitle := WinGetTitle("ahk_id" cnfg.hWnd)
cnfg.winText  := WinGetText( "ahk_id" cnfg.hWnd).Trim("`r`n ")
cnfg.fullWinTitleQuery := cnfg.winTitle . " ahk_id" cnfg.hWnd . " ahk_class" cnfg.winClass
ConsoleMsg("INFO: Window found" , _wait_for_enter := false)
ConsoleMsg("      title          = " cnfg.winTitle.Inspect(),          _wait_for_enter := false)
ConsoleMsg("      ahk_id         = " cnfg.hWnd,                        _wait_for_enter := false)
ConsoleMsg("      ahk_class      = " cnfg.winClass.Inspect(),          _wait_for_enter := false)
ConsoleMsg("      --ahk-wintitle = " cnfg.fullWinTitleQuery.Inspect(), _wait_for_enter := false)
;ConsoleMsg("      WinText   = " cnfg.winText.Inspect(), _wait_for_enter := false)

;; Bind exit to window close
ConsoleMsg("INFO: Will now automatically exit when window is closed", _wait_for_enter := false)
Event_AppExit() {
  if not WinExist("ahk_id" cnfg.hWnd)
    ExitApp(0)
}
MAX_PRIORITY := 2147483647
SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)

;;
;ConsoleMsg("Press enter to continue...", _wait_for_enter := true)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Parse args
parseArgs(args)
{
  cnfg := {}
  i := 0

  while (i += 1, i <= args.Length)
  {
    ; Get name and value
    if RegExMatch(A_Args[i], "^--(.+?)=(.+)", &match) {
      arg_str := A_Args[i]
      name  := match[1].Trim().StrReplace("-", "_")
      value := match[2].Trim()
    } else if RegExMatch(A_Args[i], "^--(.+)", &match) {
      arg_str := A_Args[i]
      name  := match[1].Trim().StrReplace("-", "_")
      value := true
    } else {
      if A_Args[i] = "--"
        i += 1

      name := "launch"
      value := A_Args.Slice(i)
                     .Collect(arg => (arg ~= "\s" ? '"' arg '"' : arg))
                     .Join(" ")
      i := A_Args.Length  ; Make this loop iteration the last one
    }

    ; Validate name and value
    ;TODO

    ; Store name and value
    cnfg.%name% := value
  }

  return cnfg
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Run an *.exe file
launchExe(launch_string)
{
  ; Run
  try {
    Run(launch_string, , , &app_pid)
    result := { ok: true, pid: app_pid }
  } catch {
    result := { ok: false }
  }

  ; Return 
  return result
}
#Requires AutoHotkey v2.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BoFuru2 - Borderless Fullscreen                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Run games in fullscreen without changing screen resolution.
;;
;; Usage Example:
;;   ```
;;   ```
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\lib\stdlib.ahk
#Include %A_ScriptDir%\lib\console_msg.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\is_window_class_allowed.ahk
#Include %A_ScriptDir%\lib\generate_transparent_pixel.ahk
#Include %A_ScriptDir%\lib\parse_window_style.ahk

; Sets how matching is done for the WinTitle parameter used by various
; AHK functions.
SetTitleMatchMode "RegEx"

; Use coordinates relative to the screen instead of relative to the window for
; all AHK functions that sets/retrieves/uses mouse coordinates.
CoordMode "Mouse", "Screen"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sandbox - My Personal Playground


;; Test retrieving args
;ConsoleMsg(A_Args.Inspect())


;; Test run app and receive PID
;Run("calc.exe", , , &app_pid)
;ConsoleMsg(app_pid)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Intro
ConsoleMsg("###############", _wait_for_enter := false)
ConsoleMsg("#   BoFuRu2   #", _wait_for_enter := false)
ConsoleMsg("###############", _wait_for_enter := false)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Start - Find a Window to make Fullscreen
;ConsoleMsg(""                   , _wait_for_enter := false)
ConsoleMsg("=== Find Window ===", _wait_for_enter := false)


;; Parse args
cnfg := parseArgs(A_Args)
ConsoleMsg("INFO: parsed args: " cnfg.Inspect(), _wait_for_enter := false)


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
  ConsoleMsg("INFO: Waiting for window: " cnfg.ahk_wintitle.Inspect(), _wait_for_enter := false)
  cnfg.hWnd := WinWait(cnfg.ahk_wintitle)
}


;; Wait for a window to show up belonging to PID
if ! cnfg.HasOwnProp("hWnd") && cnfg.HasOwnProp("pid")
{
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
  ConsoleMsg("      - Click on game window", _wait_for_enter := false)
  ConsoleMsg("      - Press Esc to cancel", _wait_for_enter := false)

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
cnfg.winTitle     := WinGetTitle(       "ahk_id" cnfg.hWnd )
cnfg.winClass     := WinGetClass(       "ahk_id" cnfg.hWnd )
cnfg.winText      := WinGetText(        "ahk_id" cnfg.hWnd ).Trim("`r`n ")
cnfg.pid          := WinGetPID(         "ahk_id" cnfg.hWnd )
cnfg.proc_name    := WinGetProcessName( "ahk_id" cnfg.hWnd )
cnfg.ahk_wintitle := cnfg.winTitle . " ahk_class " cnfg.winClass . " ahk_exe " cnfg.proc_name

ConsoleMsg("INFO: Window found" , _wait_for_enter := false)
ConsoleMsg("      PID           = " cnfg.pid,                         _wait_for_enter := false)
ConsoleMsg("      hWnd          = " cnfg.hWnd,                        _wait_for_enter := false)
ConsoleMsg("      Process Name  = " cnfg.proc_name,                   _wait_for_enter := false)
ConsoleMsg("      Title         = " cnfg.winTitle.Inspect(),          _wait_for_enter := false)
ConsoleMsg("      Class         = " cnfg.winClass.Inspect(),          _wait_for_enter := false)
;ConsoleMsg("      Text          = " cnfg.winText.Inspect(),           _wait_for_enter := false)
ConsoleMsg("      --ahk-wintitle=" cnfg.ahk_wintitle.Inspect(),       _wait_for_enter := false)


;; Check if window is allowed
if !lib_isWindowClassAllowed(cnfg.winClass)
{
  ConsoleMsg("ERROR: Unallowed window selected", _wait_for_enter := true)
  ExitApp
}


;; Bind exit to window close
ConsoleMsg("INFO: Bind exit event to window close", _wait_for_enter := false)
Event_AppExit() {
  if not WinExist("ahk_id" cnfg.hWnd)
    ExitApp(0)
}
MAX_PRIORITY := 2147483647
SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Main - Make Window Fullscreen
ConsoleMsg(""                     , _wait_for_enter := false)
ConsoleMsg("=== Modify Window ===", _wait_for_enter := false)


;; Collect Window State
ConsoleMsg("INFO: Collecting current window state", _wait_for_enter := false)


; Get window size/position
WinGetPos(&x, &y, &winWidth, &winHeight, cnfg.hWnd)


; Get window client area width/height
; (this is the area without the window border)
WinGetClientPos(, , &width, &height, cnfg.hWnd)


; Get window style (border)
winStyle   := WinGetStyle(cnfg.hWnd)
winExStyle := WinGetExStyle(cnfg.hWnd)


; Get window menu bar
winMenu := DllCall("User32.dll\GetMenu", "Ptr", cnfg.hWnd, "Ptr")


; Log window state
winStyleStr   := Format("0x{:08X}", winStyle)   . " (" . lib_parseWindowStyle(winStyle)    .Join(" | ") . ")"
winExStyleStr := Format("0x{:08X}", winExStyle) . " (" . lib_parseWindowExStyle(winExStyle).Join(" | ") . ")"
winMenuStr    := Format("0x{:08X}", winMenu)

ConsoleMsg("INFO: Current window state",        _wait_for_enter := false)
ConsoleMsg("      x          = " x,             _wait_for_enter := false)
ConsoleMsg("      y          = " y,             _wait_for_enter := false)
ConsoleMsg("      winWidth   = " winWidth,      _wait_for_enter := false)
ConsoleMsg("      winHeight  = " winHeight,     _wait_for_enter := false)
ConsoleMsg("      width      = " width,         _wait_for_enter := false)
ConsoleMsg("      height     = " height,        _wait_for_enter := false)
ConsoleMsg("      winStyle   = " winStyleStr,   _wait_for_enter := false)
ConsoleMsg("      winExStyle = " winExStyleStr, _wait_for_enter := false)
ConsoleMsg("      winMenu    = " winMenuStr,    _wait_for_enter := false)

winStyleStr := winExStyleStr := winMenuStr := unset


; Store window original state
cnfg.origState := {
  x:x, y:y,
  winWidth:winWidth, winHeight:winHeight,
  width:width, height:height,
  winStyle:winStyle, winExStyle:winExStyle,
  winMenu:winMenu,
}


; Unset temporary vars
x:=y:=winWidth:=winHeight:=width:=height:=winStyle:=winExStyle:=winMenu:=unset


;; Modify Window State
; Remove window menu bar
if cnfg.origState.winMenu
  DllCall("SetMenu", "uint", cnfg.hWnd, "uint", 0)


; Remove styles (border)
winStylesToRemove := 0x00C00000  ; WS_CAPTION    (title bar)
                   | 0x00800000  ; WS_BORDER     (visible border)
                   | 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" winStylesToRemove, cnfg.hWnd)  ; Note the minus (-) sign


; Restore the window client area width/height
; (these gets modified when styles are removed)
WinMove(, , cnfg.origState.width, cnfg.origState.height, cnfg.hWnd)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Functions and Classes

;; Parse args
parseArgs(args)
{
  cnfg := {}
  i := 0

  while (i += 1, i <= args.Length)
  {
    ; Get name and value
    if RegExMatch(A_Args[i], "^--(.+?)=(.+)", &match) {

      name  := match[1].Trim().StrReplace("-", "_")
      value := match[2].Trim()

    } else if RegExMatch(A_Args[i], "^--(.+)", &match) {

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

    ; Modify value
    if value = "true"
      value := true

    if value = "false"
      value := false

    ; Store name and value
    cnfg.%name% := value
  }

  ; Return
  return cnfg
}


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

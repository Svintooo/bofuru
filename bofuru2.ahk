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
ConsoleMsg("      --ahk-wintitle="  cnfg.ahk_wintitle.Inspect(),      _wait_for_enter := false)


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
cnfg.origState := CollectWindowState(cnfg.hWnd)
ConsolePrintWindowState(cnfg.origState, "Original window state")


;; Modify Window State
; Remove window menu bar
ConsoleMsg("INFO: Remove window menu bar (if one exists)", _wait_for_enter := false)
if cnfg.origState.winMenu
  DllCall("SetMenu", "uint", cnfg.hWnd, "uint", 0)

; Remove styles (border)
ConsoleMsg("INFO: Remove window styles (border, title bar, etc)", _wait_for_enter := false)
newWinStyle := 0x80000000  ; WS_POPUP (no border, no titlebar)
             | 0x10000000  ; WS_VISIBLE
try
  WinSetStyle(newWinStyle, "ahk_id" cnfg.hWnd)
catch as e
  ConsolePrintException(e)

; Remove extended styles (NOTE: may not be needed)
ConsoleMsg("INFO: Remove window extended styles", _wait_for_enter := false)
removeWinExStyle := 0x00000001 ; WS_EX_DLGMODALFRAME (double border)
                  | 0x00000100 ; WS_EX_WINDOWEDGE    (raised border edges)
                  | 0x00000200 ; WS_EX_CLIENTEDGE    (sunken border edges)
                  | 0x00020000 ; WS_EX_STATICEDGE    (three-dimensional border)
                  | 0x00000400 ; WS_EX_CONTEXTHELP   (title bar question mark)
                  | 0x00000080 ; WS_EX_TOOLWINDOW    (floating toolbar window type: shorter title bar, smaller title bar font, no ALT+TAB)
try
  WinSetExStyle("-" removeWinExStyle, "ahk_id" cnfg.hWnd)   ; The minus (-) removes the styles from the current window styles
catch as e
  ConsolePrintException(e)

; Restore the window client area width/height
; (these gets distorted when styles are removed)
ConsoleMsg("INFO: Restore window width/height that got distorted when removing styles", _wait_for_enter := false)
WinMove(, , cnfg.origState.width, cnfg.origState.height, cnfg.hWnd)

; Print new window state
ConsolePrintWindowState(cnfg.hWnd, "New window state")


;; Restore Window State (testing)


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


;; Collect Window state
CollectWindowState(hWnd)
{
  ; Get window size/position
  WinGetPos(&x, &y, &winWidth, &winHeight, hWnd)

  ; Get window client area width/height
  ; (this is the area without the window border)
  WinGetClientPos(, , &width, &height, hWnd)

  ; Get window style (border)
  winStyle   := WinGetStyle(hWnd)
  winExStyle := WinGetExStyle(hWnd)

  ; Get window menu bar
  winMenu := DllCall("User32.dll\GetMenu", "Ptr", hWnd, "Ptr")

  winState := {
    hWnd:hWnd,
    x:x, y:y,
    winWidth:winWidth, winHeight:winHeight,
    width:width, height:height,
    winStyle:winStyle, winExStyle:winExStyle,
    winMenu:winMenu,
  }

  return winState
}


;; Print window state to console
ConsolePrintWindowState(hWnd_or_winState, message)
{
  if hWnd_or_winState is Number
    winState := CollectWindowState(hWnd_or_winState)
  else
    winState := hWnd_or_winState

  winStyleStr   := Format("0x{:08X}", winState.winStyle)   . " (" . lib_parseWindowStyle(winState.winStyle)    .Join(" | ") . ")"
  winExStyleStr := Format("0x{:08X}", winState.winExStyle) . " (" . lib_parseWindowExStyle(winState.winExStyle).Join(" | ") . ")"
  winMenuStr    := Format("0x{:08X}", winState.winMenu)

  ConsoleMsg("INFO: " message,                         _wait_for_enter := false)
  ConsoleMsg("      x          = " winState.x,         _wait_for_enter := false)
  ConsoleMsg("      y          = " winState.y,         _wait_for_enter := false)
  ConsoleMsg("      winWidth   = " winState.winWidth,  _wait_for_enter := false)
  ConsoleMsg("      winHeight  = " winState.winHeight, _wait_for_enter := false)
  ConsoleMsg("      width      = " winState.width,     _wait_for_enter := false)
  ConsoleMsg("      height     = " winState.height,    _wait_for_enter := false)
  ConsoleMsg("      winStyle   = " winStyleStr,        _wait_for_enter := false)
  ConsoleMsg("      winExStyle = " winExStyleStr,      _wait_for_enter := false)
  ConsoleMsg("      winMenu    = " winMenuStr,         _wait_for_enter := false)
}


;; Print exception to console
ConsolePrintException(e)
{
  ConsoleMsg(Format("UNKNOWN: {1} threw error of type {2}", e.What.Inspect(), Type(e)), false)
  ConsoleMsg(Format("         msg: {1}", e.Message.Inspect()), false)
  ConsoleMsg(Format("         xtra: {1}", e.Extra.Inspect()), false)
}

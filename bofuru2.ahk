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
#Include %A_ScriptDir%\lib\calc_win_fullscreen.ahk

; Sets how matching is done for the WinTitle parameter used by various
; AHK functions.
SetTitleMatchMode "RegEx"

; Use coordinates relative to the screen instead of relative to the window for
; all AHK functions that sets/retrieves/uses mouse coordinates.
CoordMode "Mouse", "Screen"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Intro
ConsoleMsg("#########################", _wait_enter := false)
ConsoleMsg("#     === BoFuRu ===    #", _wait_enter := false)
ConsoleMsg("# Borderless Fullscreen #", _wait_enter := false)
ConsoleMsg("#########################", _wait_enter := false)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Start - Find a Window to make Fullscreen
ConsoleMsg(""                   , _wait_enter := false)
ConsoleMsg("=== Find Window ===", _wait_enter := false)


;; Parse args
cnfg := parseArgs(A_Args)
ConsoleMsg("INFO: parsed args: " cnfg.Inspect(), _wait_enter := false)


;; Run an *.exe
if cnfg.HasOwnProp("launch")
{
  ConsoleMsg("INFO: Launching: " cnfg.launch, _wait_enter := false)
  result := launchExe(cnfg.launch)

  if ! result.ok {
    ConsoleMsg("ERROR: Launch failed", _wait_enter := true)
    ExitApp
  }

  cnfg.pid := result.pid
  result := unset
  ConsoleMsg("INFO: Launch success, got PID: " cnfg.pid, _wait_enter := false)
}


;; Wait for a window to show up
if cnfg.HasOwnProp("ahk_wintitle")
{
  ConsoleMsg("INFO: Waiting for window: " cnfg.ahk_wintitle.Inspect(), _wait_enter := false)
  cnfg.hWnd := WinWait(cnfg.ahk_wintitle)
}


;; Wait for a window to show up belonging to PID
if ! cnfg.HasOwnProp("hWnd") && cnfg.HasOwnProp("pid")
{
  ConsoleMsg("INFO: Waiting for window beloning to PID", _wait_enter := false)
  cnfg.hWnd := false

  while !cnfg.hWnd && ProcessExist(cnfg.pid)
    cnfg.hWnd := WinWait("ahk_pid" cnfg.pid, , _timeout := 1)

  if !cnfg.hWnd
  {
    ConsoleMsg("ERROR: PID disappeared before window was found", _wait_enter := true)
    ExitApp
  }
}


;; Let user manually select a window
if ! cnfg.HasOwnProp("hWnd")
{
  ConsoleMsg("INFO: Manual Window selection activated", _wait_enter := false)
  ConsoleMsg("      - Click on game window", _wait_enter := false)
  ConsoleMsg("      - Press Esc to cancel", _wait_enter := false)

  result := lib_userWindowSelect()
  while result.ok && !lib_isWindowClassAllowed(result.className)
  {
    ConsoleMsg("ERROR: Unallowed window: Try again", _wait_enter := false)
    result := lib_userWindowSelect()
  }

  if ! result.ok  ; User cancelled the operation
    ExitApp

  cnfg.hWnd := result.hWnd
  result := unset
}


;; Fetch window info
cnfg.winTitle     := WinGetTitle(       "ahk_id" cnfg.hWnd )
cnfg.winClass     := WinGetClass(       "ahk_id" cnfg.hWnd )
cnfg.winText      := WinGetText(        "ahk_id" cnfg.hWnd ).Trim("`r`n ")
cnfg.pid          := WinGetPID(         "ahk_id" cnfg.hWnd )
cnfg.proc_name    := WinGetProcessName( "ahk_id" cnfg.hWnd )
cnfg.ahk_wintitle := cnfg.winTitle . " ahk_class " cnfg.winClass . " ahk_exe " cnfg.proc_name


;; Print window info
ConsoleMsg("INFO: Window found" , _wait_enter := false)
ConsoleMsg("      PID           = " cnfg.pid,                         _wait_enter := false)
ConsoleMsg("      hWnd          = " cnfg.hWnd,                        _wait_enter := false)
ConsoleMsg("      Process Name  = " cnfg.proc_name,                   _wait_enter := false)
ConsoleMsg("      Title         = " cnfg.winTitle.Inspect(),          _wait_enter := false)
ConsoleMsg("      Class         = " cnfg.winClass.Inspect(),          _wait_enter := false)
;ConsoleMsg("      Text          = " cnfg.winText.Inspect(),           _wait_enter := false)
ConsoleMsg("      --ahk-wintitle="  cnfg.ahk_wintitle.Inspect(),      _wait_enter := false)


;; Check if window is allowed
if !lib_isWindowClassAllowed(cnfg.winClass)
{
  ConsoleMsg("ERROR: Unallowed window selected", _wait_enter := true)
  ExitApp
}


;; Exit BoFuRu if the game window is closed
ConsoleMsg("INFO: Bind exit event to window close", _wait_enter := false)
Event_AppExit() {
  if not WinExist("ahk_id" cnfg.hWnd)
    ExitApp(0)
}
MAX_PRIORITY := 2147483647
SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Main - Make Window Fullscreen
ConsoleMsg(""                     , _wait_enter := false)
ConsoleMsg("=== Modify Window ===", _wait_enter := false)


;; Collect Window State
ConsoleMsg("INFO: Collecting current window state", _wait_enter := false)
cnfg.origState := CollectWindowState(cnfg.hWnd)
ConsolePrintWindowState(cnfg.origState, "Original window state")


;; Restore window state on exit
ConsoleMsg("Register OnExit callback to restore window state on exit", _wait_enter := false)
OnExit (*) => restoreWindowState(cnfg.hWnd, cnfg.origState)


;; Remove window border
; Remove window menu bar
ConsoleMsg("INFO: Remove window menu bar (if one exists)", _wait_enter := false)
if cnfg.origState.winMenu
  DllCall("SetMenu", "uint", cnfg.hWnd, "uint", 0)

; Remove styles (border)
ConsoleMsg("INFO: Remove window styles (border, title bar, etc)", _wait_enter := false)
newWinStyle := 0x80000000  ; WS_POPUP (no border, no titlebar)
             | 0x10000000  ; WS_VISIBLE
try
  WinSetStyle(newWinStyle, "ahk_id" cnfg.hWnd)
catch as e
  ConsolePrintException(e)

; Remove extended styles (NOTE: may not be needed)
ConsoleMsg("INFO: Remove window extended styles", _wait_enter := false)
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

; Restore the correct window client area width/height
; (these gets distorted when the border is removed)
ConsoleMsg("INFO: Restore window width/height that got distorted when removing styles", _wait_enter := false)
WinMove(, , cnfg.origState.width, cnfg.origState.height, cnfg.hWnd)


;; Resize and center window
fscr := lib_calcWinFullscreen(cnfg.hWnd, _monitor := false, _noTaskbar := false, _dotByDot := false)
WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, cnfg.hWnd)


;; Create black background
; Generate pixel
result := lib_GenerateTransparentPixel()
if !result.ok {
  ConsoleMsg("ERROR: Failed generating transparent image: " result.reason, _wait_enter := false)
  ExitApp
}
pixel := result.data
result := unset

; Create black background
bkgr := Gui("+ToolWindow -Caption -Border +AlwaysOnTop")
bkgr.BackColor := "Black"
WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures be both clickable,
                              ; and have other elements placed on top of them.
bkgr.clickArea := bkgr.Add("Picture", WS_CLIPSIBLINGS, pixel)
bkgr.clickArea.Move(0,0,fscr.monitor.w,fscr.monitor.h)
bkgr.clickArea.OnEvent("Click",       (*) => WinActivate(cnfg.hWnd))
bkgr.clickArea.OnEvent("DoubleClick", (*) => WinActivate(cnfg.hWnd))
bkgr.Show("x{} y{} w{} h{}".f(fscr.monitor.x, fscr.monitor.y, fscr.monitor.w, fscr.monitor.h))
polygonStr := Format(
  "  0-0   {1}-0   {1}-{2}   0-{2}   0-0 "
  "{3}-{5} {4}-{5} {4}-{6} {3}-{6} {3}-{5}",
  fscr.monitor.w, fscr.monitor.h,
  fscr.window.x-fscr.monitor.x, fscr.window.x-fscr.monitor.x+fscr.window.w,
  fscr.window.y-fscr.monitor.y, fscr.window.y-fscr.monitor.y+fscr.window.h
)
WinSetRegion(polygonStr, bkgr.hwnd)


;; Print new window state without border
ConsolePrintWindowState(cnfg.hWnd, "New window state")



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program End - Wait until window or script exits
ConsoleMsg(""            , _wait_enter := false)
ConsoleMsg("=== DONE ===", _wait_enter := false)

ConsoleMsg("Your app should now be in fullscreen.", false)
;; ConsoleMsg("Press enter to quit fullscreen and exit BoFuRu.", true)
;; ExitApp



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Functions and Classes

ConsoleMsg(msg, wait_enter)
{
  return lib_consoleMsg(msg, wait_enter)
}


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
    x:x, y:y,
    winWidth:winWidth, winHeight:winHeight,
    width:width, height:height,
    winStyle:winStyle, winExStyle:winExStyle,
    winMenu:winMenu,
  }

  return winState
}


;; Restore window state
restoreWindowState(hWnd, winState)
{
  ; Set window menu bar
  if winState.winMenu
    winMenu := DllCall("User32.dll\SetMenu", "Ptr", hWnd, "Ptr", winState.winMenu)

  ; Set window style
  WinSetStyle(winState.winStyle, "ahk_id" hWnd)
  WinSetExStyle(winState.winExStyle, "ahk_id" hWnd)

  ; Get window size/position
  WinMove(winState.x, winState.y, winState.winWidth, winState.winHeight, "ahk_id" hWnd)
}


;; Print window state to console
ConsolePrintWindowState(hWnd_or_winState, message)
{
  if hWnd_or_winState is Number
    winState := CollectWindowState(hWnd_or_winState)
  else
    winState := hWnd_or_winState

  winStyleStr   := "0x{:08X} ({})".f(winState.winStyle,   lib_parseWindowStyle(winState.winStyle)    .Join(" | "))
  winExStyleStr := "0x{:08X} ({})".f(winState.winExStyle, lib_parseWindowExStyle(winState.winExStyle).Join(" | "))
  winMenuStr    := "0x{:08X}".f(winState.winMenu)

  ConsoleMsg("INFO: {}".f(message),                         _wait_enter := false)
  ConsoleMsg("      x          = {}".f(winState.x),         _wait_enter := false)
  ConsoleMsg("      y          = {}".f(winState.y),         _wait_enter := false)
  ConsoleMsg("      winWidth   = {}".f(winState.winWidth),  _wait_enter := false)
  ConsoleMsg("      winHeight  = {}".f(winState.winHeight), _wait_enter := false)
  ConsoleMsg("      width      = {}".f(winState.width),     _wait_enter := false)
  ConsoleMsg("      height     = {}".f(winState.height),    _wait_enter := false)
  ConsoleMsg("      winStyle   = {}".f(winStyleStr),        _wait_enter := false)
  ConsoleMsg("      winExStyle = {}".f(winExStyleStr),      _wait_enter := false)
  ConsoleMsg("      winMenu    = {}".f(winMenuStr),         _wait_enter := false)
}


;; Print exception to console
ConsolePrintException(e)
{
  ConsoleMsg("UNKNOWN: {1} threw error of type {2}".f(e.What.Inspect(), Type(e)), false)
  ConsoleMsg("         msg: {1}".f(e.Message.Inspect()), false)
  ConsoleMsg("         xtra: {1}".f(e.Extra.Inspect()), false)
}

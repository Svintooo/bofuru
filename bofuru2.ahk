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
#Include %A_ScriptDir%\lib\can_window_be_fullscreened.ahk
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
ConsoleMsg "#########################"
ConsoleMsg "#     === BoFuRu ===    #"
ConsoleMsg "# Borderless Fullscreen #"
ConsoleMsg "#########################"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Start - Find a Window to make Fullscreen
ConsoleMsg ""
ConsoleMsg "=== Find Window ==="


;; Parse args
cnfg := parseArgs(A_Args)
ConsoleMsg "INFO: parsed args: {}".f(cnfg.Inspect())


;; Run an *.exe
if cnfg.HasOwnProp("launch")
{
  ConsoleMsg("INFO: Launching: " cnfg.launch)
  result := launchExe(cnfg.launch)

  if ! result.ok {
    ConsoleMsg("ERROR: Launch failed", _wait_enter := true)
    ExitApp
  }

  cnfg.pid := result.pid
  result := unset
  ConsoleMsg("INFO: Launch success, got PID: " cnfg.pid)
}


;; Wait for a window to show up
if cnfg.HasOwnProp("ahk_wintitle")
{
  ConsoleMsg "INFO: Waiting for window: {}".f(cnfg.ahk_wintitle.Inspect())
  cnfg.hWnd := WinWait(cnfg.ahk_wintitle)
}


;; Wait for a window to show up belonging to PID
if ! cnfg.HasOwnProp("hWnd") && cnfg.HasOwnProp("pid")
{
  ConsoleMsg "INFO: Waiting for window beloning to PID"
  cnfg.hWnd := false

  while !cnfg.hWnd && ProcessExist(cnfg.pid)
    cnfg.hWnd := WinWait("ahk_pid" cnfg.pid, , _timeout := 1)

  if !cnfg.hWnd
  {
    ConsoleMsg "ERROR: PID disappeared before window was found", _wait_enter := true
    ExitApp
  }
}


;; Let user manually select a window
if ! cnfg.HasOwnProp("hWnd")
{
  ConsoleMsg "INFO: Manual Window selection activated"
  ConsoleMsg "      - Click on game window"
  ConsoleMsg "      - Press Esc to cancel"

  result := lib_userWindowSelect()
  while result.ok && !lib_canWindowBeFullscreened(result.hWnd, result.className)
  {
    ConsoleMsg "ERROR: This window is unsupported: Try again"
    result := lib_userWindowSelect()
  }

  if ! result.ok && result.reason = "user cancel" {
    ; User cancelled the operation
    ExitApp
  } else if ! result.ok {
    ConsoleMsg "ERROR: {}".f(result.reason), _wait_enter := true
    ExitApp
  }

  cnfg.hWnd := result.hWnd
  result := unset
}


;; Fetch window info
cnfg.winTitle     := WinGetTitle(       "ahk_id" cnfg.hWnd )
cnfg.winClass     := WinGetClass(       "ahk_id" cnfg.hWnd )
cnfg.winText      := WinGetText(        "ahk_id" cnfg.hWnd ).Trim("`r`n ")
cnfg.pid          := WinGetPID(         "ahk_id" cnfg.hWnd )
cnfg.proc_name    := WinGetProcessName( "ahk_id" cnfg.hWnd )
cnfg.ahk_wintitle := "{} ahk_class {} ahk_exe {}".f(cnfg.winTitle, cnfg.winClass, cnfg.proc_name)


;; Print window info
ConsoleMsg "INFO: Window found"
ConsoleMsg "      PID           = {}".f(cnfg.pid)
ConsoleMsg "      hWnd          = {}".f(cnfg.hWnd)
ConsoleMsg "      Process Name  = {}".f(cnfg.proc_name)
ConsoleMsg "      Title         = {}".f(cnfg.winTitle.Inspect())
ConsoleMsg "      Class         = {}".f(cnfg.winClass.Inspect())
;ConsoleMsg "      Text          = {}".f(cnfg.winText.Inspect())
ConsoleMsg "      --ahk-wintitle={}".f(cnfg.ahk_wintitle.Inspect())


;; Check if window is allowed
if !lib_canWindowBeFullscreened(cnfg.hWnd, cnfg.winClass)
{
  ConsoleMsg("ERROR: Unsupported window selected", _wait_enter := true)
  ExitApp
}


;; Exit BoFuRu if the game window is closed
ConsoleMsg("INFO: Bind exit event to window close")
Event_AppExit() {
  if not WinExist("ahk_id" cnfg.hWnd)
    ExitApp(0)
}
MAX_PRIORITY := 2147483647
SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Main - Make Window Fullscreen
ConsoleMsg ""
ConsoleMsg "=== Modify Window ==="


;; Focus the window
ConsoleMsg "INFO: Put the game window in focus"
WinActivate(cnfg.hWnd)


;; Collect Window State
ConsoleMsg "INFO: Collecting current window state"
cnfg.origState := CollectWindowState(cnfg.hWnd)
ConsolePrintWindowState(cnfg.origState, "Original window state")


;; Restore window state on exit
ConsoleMsg "INFO: Register OnExit callback to restore window state on exit"
OnExit (*) => restoreWindowState(cnfg.hWnd, cnfg.origState)


;; Remove window border
; Remove window menu bar
ConsoleMsg "INFO: Remove window menu bar (if one exists)"
if cnfg.origState.winMenu
  DllCall("SetMenu", "uint", cnfg.hWnd, "uint", 0)

; Remove styles (border)
ConsoleMsg "INFO: Remove window styles (border, title bar, etc)"
newWinStyle := 0x80000000  ; WS_POPUP (no border, no titlebar)
             | 0x10000000  ; WS_VISIBLE
try
  WinSetStyle(newWinStyle, "ahk_id" cnfg.hWnd)
catch as e
  ConsolePrintException(e)

; Remove extended styles (NOTE: may not be needed)
ConsoleMsg "INFO: Remove window extended styles"
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
ConsoleMsg "INFO: Restore window aspect ratio that got distorted when removing styles"
WinMove(, , cnfg.origState.width, cnfg.origState.height, cnfg.hWnd)


;; Resize and center window
ConsoleMsg "INFO: Resize window"
fscr := lib_calcFullscreenArgs(cnfg.hWnd, _monitor := false, _winSize := "fit", _taskbar := "hide")
if ! fscr.ok {
  ConsoleMsg "ERROR: {}".f(fscr.reason)
  ExitApp
}
WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, cnfg.hWnd)


;; Create black background
; Generate pixel
ConsoleMsg "INFO: Generate transparent pixel"
result := lib_GenerateTransparentPixel()
if !result.ok {
  ConsoleMsg "ERROR: Failed generating transparent image: {}".f(result.reason)
  ExitApp
}
pixel := result.data
result := unset

; Create black background
ConsoleMsg "INFO: Create background overlay"
bkgr := Gui("+ToolWindow -Caption -Border +AlwaysOnTop")
bkgr.BackColor := "Black"
WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures be both clickable,
                              ; and have other elements placed on top of them.
bkgr.clickArea := bkgr.Add("Picture", WS_CLIPSIBLINGS, pixel)
bkgr.clickArea.Move(0,0,fscr.screen.w,fscr.screen.h)
bkgr.clickArea.OnEvent("Click",       (*) => WinActivate(cnfg.hWnd))
bkgr.clickArea.OnEvent("DoubleClick", (*) => WinActivate(cnfg.hWnd))
bkgr.Show("x{} y{} w{} h{}".f(fscr.screen.x, fscr.screen.y, fscr.screen.w, fscr.screen.h))
polygonStr := Format(
  "  0-0   {1}-0   {1}-{2}   0-{2}   0-0 "
  "{3}-{5} {4}-{5} {4}-{6} {3}-{6} {3}-{5}",
  fscr.screen.w, fscr.screen.h,
  fscr.window.x-fscr.screen.x, fscr.window.x-fscr.screen.x+fscr.window.w,
  fscr.window.y-fscr.screen.y, fscr.window.y-fscr.screen.y+fscr.window.h
)
WinSetRegion(polygonStr, bkgr.hwnd)


;; Toggle AlwaysOnTop on window focus switch
; NOTE: This is probably the most bug prone, racey code in this codebase.
;       MS Windows will automatically hide the taskbar if a single window is
;       both in focus AND cover exactly a single monitor (this is, to my
;       knowledge, how fullscreen in MS Windows actually works).
;         This is usually not the case here. The game window is as big as
;       possible while keeping its aspect ratio, and the rest of the monitor
;       is covered by a black overlay that is not in focus.
;         To mimic fullscreen the code here will react to the game window
;       getting and losing focus and toggle ALwaysOnTop accordingly (since
;       AlwaysOnTop will let the game window be drawn over the taskbar).
;         But as mentioned, this is racey and are prone to:
;       1) show the taskbar even while the game is in focus,
;       2) not show other windows when switching focus to them.
;         To fix this the code has basically been hacked and tested until
;       it seems to work good enough.

; Tell MS Windows to notify us of events for all windows
ConsoleMsg("INFO: Bind focus change event to toggle AlwaysOnTop")
if DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
{
  MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
  OnMessage(MsgNum, ShellMessage)
}

; This is now run when any event happens in MS Windows on any window
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  static HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; React on events about switching focus to another window
  if wParam = HSHELL_WINDOWACTIVATED
  || wParam = HSHELL_RUDEAPPACTIVATED {
    if lParam = cnfg.hWnd {
      ; Game Window got focus: Set AlwaysOnTop
      ;ConsoleMsg "DEBUG: lParam={} wParam={}".f("game", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      WinSetAlwaysOnTop(true, cnfg.hWnd)
      WinSetAlwaysOnTop(true, bkgr.hWnd)
      ; RACE CONDITION HACK: Do everything again (ugly hack)
      ;   MS Windows sometimes paints the taskbar above the Game Window even if
      ;   we set AlwaysOnTop. Setting AlwaysOnTop again after a short sleep
      ;   seems to fix the issue.
      sleep 200  ; Milliseconds
      WinSetAlwaysOnTop(true, cnfg.hWnd)
      WinSetAlwaysOnTop(true, bkgr.hWnd)
    } else if lParam = 0 {
      ; DO NOTHING
      ;   Focus was changed to the Windows taskbar, the overlay
      ;   we created around the Game Window, or something unknown.
      ;ConsoleMsg "DEBUG: lParam={} wParam={}".f("null", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
    } else {
      ; Another Window got focus: Turn off AlwaysOnTop
      ;ConsoleMsg "DEBUG: lParam={} wParam={}".f(lParam, wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      WinSetAlwaysOnTop(false, cnfg.hWnd)
      WinSetAlwaysOnTop(false, bkgr.hWnd)
      try {
        ; RACE CONDITION FIX: Move focused window to the top
        ;   MS Windows tried to to this already, but the Game Window probably
        ;   was still in AlwaysOnTop mode.
        WinMoveTop(lParam)
      } catch {
        ; RACE CONDITION FAIL
        ;   This happens if focus is changed to a window we do not have
        ;   permission to modify (windows with elevated permissions,
        ;   running as administrator).
      }
    }
  }
}


;; Print new window state
ConsolePrintWindowState(cnfg.hWnd, "New window state")



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program End - Wait until window or script exits
ConsoleMsg ""
ConsoleMsg "=== DONE ==="

ConsoleMsg "Your game should now be in fullscreen."
;; ConsoleMsg("Press enter to quit fullscreen and exit BoFuRu.", _wait_enter := true)
;; ExitApp



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Functions and Classes

ConsoleMsg(msg, wait_enter := false)
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
  ; Remove AlwaysOnTop
  WinSetAlwaysOnTop(false, hWnd)

  ; Set window menu bar
  if winState.winMenu
    winMenu := DllCall("User32.dll\SetMenu", "Ptr", hWnd, "Ptr", winState.winMenu)

  ; Set window style
  try
    WinSetStyle(winState.winStyle, "ahk_id" hWnd)
  catch as e
    ConsolePrintException(e)

  ; Set window ex style
  try
    WinSetExStyle(winState.winExStyle, "ahk_id" hWnd)
  catch as e
    ConsolePrintException(e)

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

  ConsoleMsg "INFO: {}".f(message)
  ConsoleMsg "      x          = {}".f(winState.x)
  ConsoleMsg "      y          = {}".f(winState.y)
  ConsoleMsg "      winWidth   = {}".f(winState.winWidth)
  ConsoleMsg "      winHeight  = {}".f(winState.winHeight)
  ConsoleMsg "      width      = {}".f(winState.width)
  ConsoleMsg "      height     = {}".f(winState.height)
  ConsoleMsg "      winStyle   = {}".f(winStyleStr)
  ConsoleMsg "      winExStyle = {}".f(winExStyleStr)
  ConsoleMsg "      winMenu    = {}".f(winMenuStr)
}


;; Print exception to console
ConsolePrintException(e)
{
  ConsoleMsg "UNKNOWN: {} threw error of type {}".f(e.What.Inspect(), Type(e))
  ConsoleMsg "         msg: {}".f(e.Message.Inspect())
  ConsoleMsg "         xtra: {}".f(e.Extra.Inspect())
}

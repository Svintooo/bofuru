#Requires AutoHotkey v2.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BoFuru2 - Windowed Borderless Fullscreen                                  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Run games in fullscreen without changing screen resolution.
;;
;; Usage Example:
;;   ```
;;   ```
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\lib\stdlib.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\can_window_be_fullscreened.ahk
#Include %A_ScriptDir%\lib\generate_transparent_pixel.ahk
#Include %A_ScriptDir%\lib\parse_window_style.ahk
#Include %A_ScriptDir%\lib\calc_fullscreen_args.ahk

; Sets how matching is done for the WinTitle parameter used by various
; AHK functions.
SetTitleMatchMode "RegEx"

; Use coordinates relative to the screen instead of relative to the window for
; all AHK functions that sets/retrieves/uses mouse coordinates.
CoordMode "Mouse", "Screen"

; Print more debug info to console
DEBUG := false



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Gui Window
{
  ; NOTE: Each GuiControl can be given a NAME.
  ;       NAME is set with option: "vNAME"
  ;       A GuiControl can then be accessed with code: mainGui["NAME"]

  ; NOTE: A radio button with option "Group" starts a new group of radio buttons.
  ;       Each radio button created afterwards belong to the same group.

  ; Window
  mainGui := Gui("+Border +Caption +MinimizeBox -MaximizeBox +MinSize +MaxSize -Resize +SysMenu +Theme"
                , _winTitle := "BoFuRu")
  mainGui.SetFont("S12")  ; Font Size
  mainGui.OnEvent("Close", (*) => ExitApp())  ; Stop script on window close
  mainGui.spacing     := 0  ; Vertical spacing between Gui Controls (inside a group of Gui Controls)
  mainGui.defaultOpts := "w1000 Y+{} ".f(mainGui.spacing)

  ; Console
  mainGui.AddEdit(mainGui.defaultOpts "vConsole h300 +Multi +Wrap +ReadOnly +WantCtrlA -WantReturn -WantTab -HScroll +VScroll +Ccccccc +Background0c0c0c")
  mainGui["Console"].setFont(, "Consolas")  ; Monospace font

  ; Buttons
  mainGui.AddButton(mainGui.defaultOpts "vButtonWinSelect",           "Select Window")
  mainGui.AddButton(mainGui.defaultOpts "vButtonFullscreen Disabled", "Toggle Fullscreen")
  mainGui.AddButton(mainGui.defaultOpts "VButtonExe        Disabled", "Select Exe")
  mainGui.AddButton(mainGui.defaultOpts "VButtonRun        Disabled", "Run Exe")

  ; Settings - Monitors
  mainGui.AddText("vTextMonitor", "Monitor")
  mainGui.AddRadio(mainGui.defaultOpts "vRadioMonitor{} Group".f("auto"), String("Auto"))
  loop MonitorGetCount()
  {
    mainGui.AddRadio(mainGui.defaultOpts "vRadioMonitor{}".f(A_Index), String(A_Index))
  }
  mainGui["RadioMonitor" "auto"].Value := true  ; Radio button is checked by default
  groupOpt := unset

  ; Settings - Window Size
  mainGui.AddText("vTextWindowSize", "Window Size")
  for WinSizeOpt in ["fit", "pixel-perfect", "stretch", "original"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    WinSizeOpt_HumanReadable := WinSizeOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
                                          .StrReplace("-"," ")
    mainGui.AddRadio(mainGui.defaultOpts "vRadioWinSize{} {}".f(WinSizeOpt.StrReplace("-","_"),groupOpt), WinSizeOpt_HumanReadable)
  }
  mainGui["RadioWinSize" "fit"].Value := true  ; Radio button is checked by default
  groupOpt := WinSizeOpt_HumanReadable := unset

  ; Settings - Taskbar
  mainGui.AddText("vTextTaskbar", "Taskbar")
  for TaskbarOpt in ["hide", "show", "show2", "show3"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    TaskbarOpt_HumanReadable := TaskbarOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
    mainGui.AddRadio(mainGui.defaultOpts "vRadioTaskBar{}".f(TaskbarOpt), TaskbarOpt_HumanReadable)
  }
  mainGui["RadioTaskBar" "hide"].Value := true  ; Radio button is checked by default
  groupOpt := TaskbarOpt_HumanReadable := unset

  ; Quit Button
  mainGui.AddButton(mainGui.defaultOpts "vButtonQuit", "Quit")
  mainGui["ButtonQuit"].OnEvent("Click", (*) => WinClose(mainGui.hWnd))

  ; Show the window
  mainGui.Show()
  DllCall("User32.dll\HideCaret", "Ptr", mainGui["Console"].Hwnd)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Intro
{
  ConsoleMsg "##################################"
  ConsoleMsg "#       ===== BoFuRu =====       #"
  ConsoleMsg "# Windowed Borderless Fullscreen #"
  ConsoleMsg "##################################"
  ConsoleMsg , _options := "AfterSpacing1"
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start
{
  ;; Create script config
  ; Settings in this object will control everything.
  ; Any code modifying config should trigger a redraw of fullscreen (if fullscreen is active)
  cnfg := {}


  ;; Parse args
  args := parseArgs(A_Args)
  if DEBUG
    ConsoleMsg "DEBUG: Parsed args: {}".f(args.Inspect())

  ; Known args
  DEBUG        := args.HasOwnProp("debug")   ? args.DeleteProp("debug"  ).value : DEBUG,
  cnfg.monitor := args.HasOwnProp("monitor") ? args.DeleteProp("monitor").value : false,
  cnfg.winsize := args.HasOwnProp("winsize") ? args.DeleteProp("winsize").value : "fit",
  cnfg.taskbar := args.HasOwnProp("taskbar") ? args.DeleteProp("taskbar").value : "hide"
  cnfg.launch  := args.HasOwnProp("launch")  ? args.DeleteProp("launch" ).value : ""
  cnfg.ahk_wintitle := args.HasOwnProp("ahk_wintitle") ? args.DeleteProp("ahk_wintitle").value : ""

  ; Unknown args
  if !args.IsEmpty()
  {
    for , argObj in args.OwnProps()
      ConsoleMsg "WARN : Unknown arg: {}".f(argObj.argStr)
  }


  ;; Run an *.exe
  if cnfg.launch
  {
    ConsoleMsg("INFO : Launching: " cnfg.launch)
    result := launchExe(cnfg.launch)

    if ! result.ok {
      ConsoleMsg "ERROR: Launch failed"
      return
    }

    cnfg.pid := result.pid
    result := unset
    if DEBUG
      ConsoleMsg "DEBUG: Launch success, got PID: " cnfg.pid
  }


  ;; Wait for a window to show up
  if cnfg.ahk_wintitle
  {
    ConsoleMsg "INFO : Waiting for window: {}".f(cnfg.ahk_wintitle.Inspect())
    cnfg.hWnd := WinWait(cnfg.ahk_wintitle)
  }


  ;; Wait for a window to show up belonging to PID
  if ! cnfg.HasOwnProp("hWnd") && cnfg.HasOwnProp("pid")
  {
    ConsoleMsg "INFO : Waiting for window belonging to PID"
    cnfg.hWnd := false

    while !cnfg.hWnd && ProcessExist(cnfg.pid)
      cnfg.hWnd := WinWait("ahk_pid" cnfg.pid, , _timeout := 1)

    if !cnfg.hWnd
    {
      ConsoleMsg "ERROR: PID disappeared before window was found"
      return
    }
  }


  ;; Let user manually select a window
  if ! cnfg.HasOwnProp("hWnd")
  {
    ConsoleMsg , _options := "BeforeSpacing1"
    ConsoleMsg "INFO : Manual Window selection activated"
    ConsoleMsg "       - Click on game window"
    ConsoleMsg "       - Press Esc to cancel"
    ConsoleMsg , _options := "AfterSpacing1"

    result := lib_userWindowSelect()
    while result.ok && !lib_canWindowBeFullscreened(result.hWnd, result.className)
    {
      ConsoleMsg "ERROR: This window is unsupported: Try again"
      result := lib_userWindowSelect()
    }

    if ! result.ok && result.reason = "user cancel" {
      ; User cancelled the operation
      WinActivate(mainGui.hWnd)  ; Focus the Gui
      return
    } else if ! result.ok {
      ConsoleMsg "ERROR: {}".f(result.reason)
      return
    }

    cnfg.hWnd := result.hWnd
    result := unset
  }


  ;; Synchronize script with the game window
  synchronizeWithWindow(cnfg.hWnd, &cnfg)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Main - Make Window Fullscreen
{
  ;; Create background overlay - Generate transparent pixel
  ; Needed to make the overlay allow both mouse clicks and buttons
  if DEBUG
    ConsoleMsg "DEBUG: Generate transparent pixel"
  result := lib_GenerateTransparentPixel()
  if !result.ok {
    ConsoleMsg "ERROR: Failed generating transparent pixel: {}".f(result.reason)
    ExitApp
  }
  pixel := result.data
  result := unset


  ;; Create background overlay - Create overlay window
  if DEBUG
    ConsoleMsg "DEBUG: Create background overlay (hidden for now)"
  bkgr := Gui("+ToolWindow -Caption -Border +AlwaysOnTop")
  bkgr.BackColor := "black"

  ; Create internal window control element (meant to covers the whole overlay)
  WS_CLIPSIBLINGS := 0x04000000  ; This will let pictures be both clickable,
                                 ; and have other elements placed on top of them.
  bkgr.clickArea := bkgr.Add("Picture", WS_CLIPSIBLINGS, pixel)

  ; Make mouse clicks on overlay restore focus to game window
  bkgr.clickArea.OnEvent("Click",       (*) => WinActivate(cnfg.hWnd))
  bkgr.clickArea.OnEvent("DoubleClick", (*) => WinActivate(cnfg.hWnd))


  ;; Detect focus change to any window
  ; Tell MS Windows to notify us of events for all windows
  if DEBUG
    ConsoleMsg "DEBUG: Bind focus change event to toggle AlwaysOnTop"

  if DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
  {
    MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    OnMessage(MsgNum, ShellMessage)
  }


  ;; Focus the window
  if DEBUG
    ConsoleMsg "DEBUG: Put the game window in focus"

  WinActivate(cnfg.hWnd)


  ;; Collect Window State
  if DEBUG
    ConsoleMsg "DEBUG: Collecting current window state"

  cnfg.origState := CollectWindowState(cnfg.hWnd)

  if DEBUG
    ConsolePrintWindowState(cnfg.origState, "Original window state")


  ;; Restore window state on exit
  if DEBUG
    ConsoleMsg "DEBUG: Register OnExit callback to restore window state on exit"

  OnExit (*) => restoreWindowState(cnfg.hWnd, cnfg.origState)


  ;; Remove Window Border
  ConsoleMsg "INFO : Remove window styles (border, menu, title bar, etc)"
  removeWindowBorder(cnfg.hWnd)

  ; Get new window state
  cnfg.noBorderState := CollectWindowState(cnfg.hWnd)
  if DEBUG
    ConsolePrintWindowState(cnfg.noBorderState, "No-border window state")

  ; Warn if window lost its aspect ratio
  if cnfg.noBorderState.width  != cnfg.origState.innerWidth
  || cnfg.noBorderState.height != cnfg.origState.innerHeight
  {
    ConsoleMsg , _options := "BeforeSpacing1"
    ConsoleMsg "WARN : Window refuses to keep its proportions (aspect ratio) after the border was removed."
    ConsoleMsg "WARN : You may experience distorted graphics and slightly off mouse clicks."
    ConsoleMsg , _options := "AfterSpacing1"
  }


  ;; Make Window Fullscreen
  ConsoleMsg "INFO : Activate Window Fullscreen"
  makeWindowFullscreen()
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End - Wait until window or script exits
{
  ConsoleMsg "DONE : Your game should now be in fullscreen."
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program Functions and Classes

;; Print to console
ConsoleMsg(message?, options := "")
{
  global mainGui
  static firstTime := true
  static spacing := 0
  beforeSpacing  := 0
  afterSpacing   := 0

  ; Get new spacing (read: empty lines)
  if RegExMatch(options, "i)(?:^| )b(?:efore)?s(?:pacing)? *(\w+)", &match)
    beforeSpacing := Integer(match[1])

  if RegExMatch(options, "i)(?:^| )a(?:fter)?s(?:pacing)? *(\w+)", &match)
    afterSpacing := Integer(match[1])

  ; Print spacing to console
  loop Max(spacing, beforeSpacing)
    mainGui["Console"].Value .= "`n"
  spacing := 0

  ; Store spacing to next invocation
  spacing += afterSpacing

  ; Print message
  if IsSet(message) {
    if ! firstTime
      mainGui["Console"].Value .= "`n"
    mainGui["Console"].Value .= message
  }

  ; Set firstTime
  if firstTime {
    firstTime := false
  }

  ; Scroll to bottom
  DllCall("User32.dll\SendMessage", "Ptr", mainGui["Console"].hWnd
                                  , "UInt",0x115  ; WM_VSCROLL
                                  , "Ptr", 7      ; SB_BOTTOM
                                  , "Ptr", 0)
}


;; Parse args
parseArgs(args)
{
  parsedArgs := {}
  i := 0

  while (i += 1, i <= args.Length)
  {
    ; Get name and value
    if RegExMatch(args[i], "^(--(.+?)=(.+))", &match) {

      arg   := match[1].Trim()
      name  := match[2].Trim().StrReplace("-", "_")
      value := match[3].Trim()

    } else if RegExMatch(args[i], "^(--(.+))", &match) {

      arg   := match[1].Trim()
      name  := match[2].Trim().StrReplace("-", "_")
      value := true

    } else if RegExMatch(args[i], "^(--no-(.+))", &match) {

      arg   := match[1].Trim()
      name  := match[2].Trim().StrReplace("-", "_")
      value := false

    } else {

      if args[i] = "--"
        i += 1

      arg   := ""
      name  := "launch"
      value := args.Slice(i)
                   .Collect(str => (str ~= "\s" ? '"' str '"' : str))
                   .Join(" ")

      i := args.Length  ; Make this loop iteration the last one

    }

    ; Store name and value
    parsedArgs.%name% := { argStr:arg, value:value }
  }

  ; Return
  return parsedArgs
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


;; Collect window info
CollectWindowInfo(hWnd, &cnfg)
{
  cnfg.winTitle     := WinGetTitle(       "ahk_id" hWnd )
  cnfg.winClass     := WinGetClass(       "ahk_id" hWnd )
  cnfg.winText      := WinGetText(        "ahk_id" hWnd ).Trim("`r`n ")
  cnfg.pid          := WinGetPID(         "ahk_id" hWnd )
  cnfg.procName     := WinGetProcessName( "ahk_id" hWnd )
  cnfg.ahk_wintitle := "{} ahk_class {} ahk_exe {}".f(cnfg.winTitle, cnfg.winClass, cnfg.procName)
}


;; Collect Window state
CollectWindowState(hWnd)
{
  ; Get window size/position
  WinGetPos(&x, &y, &width, &height, hWnd)

  ; Get window client area width/height
  ; (this is the area without the window border)
  WinGetClientPos(, , &innerWidth, &innerHeight, hWnd)

  ; Get window style (border)
  winStyle   := WinGetStyle(hWnd)
  winExStyle := WinGetExStyle(hWnd)

  ; Get window menu bar
  winMenu := DllCall("User32.dll\GetMenu", "Ptr", hWnd, "Ptr")

  winState := {
    x:x, y:y,
    width:width, height:height,
    innerWidth:innerWidth, innerHeight:innerHeight,
    winStyle:winStyle, winExStyle:winExStyle,
    winMenu:winMenu,
  }

  return winState
}


;; Print window info
ConsolePrintWindowInfo(cnfg)
{
  ConsoleMsg , _options := "BeforeSpacing1"
  ConsoleMsg "INFO : Window info"
  if DEBUG {
  ConsoleMsg "       PID           = {}".f(cnfg.pid)   ;Note: Indent cheating ;)
  ConsoleMsg "       hWnd          = {}".f(cnfg.hWnd)  ;Note: Indent cheating ;)
  }
  ConsoleMsg "       Process Name  = {}".f(cnfg.procName.Inspect())
  ConsoleMsg "       Title         = {}".f(cnfg.winTitle.Inspect())
  ConsoleMsg "       Class         = {}".f(cnfg.winClass.Inspect())
  if DEBUG {
  ConsoleMsg "       Text          = {}".f(cnfg.winText.Inspect())  ;Note: Indent cheating ;)
  }
  ConsoleMsg "       --ahk-wintitle={}".f(cnfg.ahk_wintitle.Inspect())
  ConsoleMsg , _options := "AfterSpacing1"
}


;; Print window state
ConsolePrintWindowState(hWnd_or_winState, message)
{
  if hWnd_or_winState is Number
    winState := CollectWindowState(hWnd_or_winState)
  else
    winState := hWnd_or_winState

  winStyleStr   := "0x{:08X} ({})".f(winState.winStyle,   lib_parseWindowStyle(winState.winStyle)    .Join(" | "))
  winExStyleStr := "0x{:08X} ({})".f(winState.winExStyle, lib_parseWindowExStyle(winState.winExStyle).Join(" | "))
  winMenuStr    := "0x{:08X}".f(winState.winMenu)

  ConsoleMsg , _options := "BeforeSpacing1"
  ConsoleMsg "DEBUG: {}".f(message)
  ConsoleMsg "       x           = {}".f(winState.x)
  ConsoleMsg "       y           = {}".f(winState.y)
  ConsoleMsg "       width       = {}".f(winState.width)
  ConsoleMsg "       height      = {}".f(winState.height)
  ConsoleMsg "       innerWidth  = {}".f(winState.innerWidth)
  ConsoleMsg "       innerHeight = {}".f(winState.innerHeight)
  ConsoleMsg "       winStyle    = {}".f(winStyleStr)
  ConsoleMsg "       winExStyle  = {}".f(winExStyleStr)
  ConsoleMsg "       winMenu     = {}".f(winMenuStr)
  ConsoleMsg , _options := "AfterSpacing1"
}


;; Print exception
ConsolePrintException(e)
{
  ConsoleMsg , _options := "BeforeSpacing1"
  ConsoleMsg "UNKNOWN: {} threw error of type {}".f(e.What.Inspect(), Type(e))
  ConsoleMsg "         msg: {}".f(e.Message.Inspect())
  ConsoleMsg "         xtra: {}".f(e.Extra.Inspect())
  ConsoleMsg , _options := "AfterSpacing1"
}


;; Remove window border
removeWindowBorder(hWnd)
{
  global DEBUG

  if cnfg.origState.winMenu
    DllCall("SetMenu", "uint", cnfg.hWnd, "uint", 0)

  ; Remove styles (border)
  newWinStyle := 0x80000000  ; WS_POPUP (no border, no titlebar)
               | 0x10000000  ; WS_VISIBLE
  try
    WinSetStyle(newWinStyle, "ahk_id" cnfg.hWnd)
  catch as e
    if DEBUG
      ConsolePrintException(e)

  ; Remove extended styles (NOTE: may not be needed)
  removeWinExStyle := 0x00000001 ; WS_EX_DLGMODALFRAME (double border)
                    | 0x00000100 ; WS_EX_WINDOWEDGE    (raised border edges)
                    | 0x00000200 ; WS_EX_CLIENTEDGE    (sunken border edges)
                    | 0x00020000 ; WS_EX_STATICEDGE    (three-dimensional border)
                    | 0x00000400 ; WS_EX_CONTEXTHELP   (title bar question mark)
                    | 0x00000080 ; WS_EX_TOOLWINDOW    (floating toolbar window type: shorter title bar, smaller title bar font, no ALT+TAB)
  try
    WinSetExStyle("-" removeWinExStyle, "ahk_id" cnfg.hWnd)   ; The minus (-) removes the styles from the current window styles
  catch as e
    if DEBUG
      ConsolePrintException(e)

  ; Restore the correct window client area width/height
  ; (these gets distorted when the border is removed)
  WinMove(, , cnfg.origState.innerWidth, cnfg.origState.innerHeight, cnfg.hWnd)
  sleep 100  ; TODO: Wait for window resize to finish before continuing
}


;; Restore window state (this includes the border)
restoreWindowState(hWnd, winState)
{
  ; Remove AlwaysOnTop
  try
    WinSetAlwaysOnTop(false, hWnd)
  catch {
    ;
  }

  ; Set window menu bar
  try
    if winState.winMenu
      winMenu := DllCall("User32.dll\SetMenu", "Ptr", hWnd, "Ptr", winState.winMenu)
  catch {
    ;
  }

  ; Set window style
  try
    WinSetStyle(winState.winStyle, "ahk_id" hWnd)
  catch {
    ;
  }

  ; Set window extended style
  try
    WinSetExStyle(winState.winExStyle, "ahk_id" hWnd)
  catch {
    ;
  }

  ; Set window size/position
  try
    WinMove(winState.x, winState.y, winState.width, winState.height, "ahk_id" hWnd)
  catch {
    ;
  }
}


;; Synchronize the script with the game window
; - Collects necessary information
; - Makes sure the window can be made fullscreen
; - Creates a hook that quits the script if the game window closes
synchronizeWithWindow(hWnd, &cnfg)
{
  ; Collect window info
  CollectWindowInfo(hWnd, &cnfg)

  ; Print window info
  ConsolePrintWindowInfo(cnfg)

  ; Check if window is allowed
  if !lib_canWindowBeFullscreened(cnfg.hWnd, cnfg.winClass)
  {
    ConsoleMsg "ERROR: Unsupported window selected"
    return
  }

  ; Exit BoFuRu if the game window is closed
  if DEBUG
    ConsoleMsg "DEBUG: Bind exit event to window close"
  Event_AppExit() {
    if not WinExist("ahk_id" cnfg.hWnd)
      ExitApp(0)
  }
  MAX_PRIORITY := 2147483647
  SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)
}


;; Activate FULLSCREEN
; All other code only exist to help use this function.
; - Changes window size and position to make it fullscreen.
; - global var `cnfg` decides how the fullscreen will be made.
; - global var `fscr` will be created.
; - global var `bkgr` will be modified.
makeWindowFullscreen()
{
  global cnfg  ; Global config
  global fscr  ; Fullscreen config
  global bkgr  ; Background overlay window

  ;; Calculate window fullscreen properties
  if DEBUG
    ConsoleMsg "DEBUG: Calculate window fullscreen properties"

  fscr := lib_calcFullscreenArgs(cnfg.noBorderState,
                                 _monitor := cnfg.monitor,
                                 _winSize := cnfg.winsize,
                                 _taskbar := cnfg.taskbar)

  if ! fscr.ok {
    restoreWindowState(cnfg.hWnd, cnfg.origState)
    ConsoleMsg "ERROR: {}".f(fscr.reason)
    return
  }


  ;; Resize and reposition window
  if DEBUG
    ConsoleMsg "DEBUG: Resize and reposition window"

  WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, cnfg.hWnd)
  sleep 1  ; Millisecond
  newWinState := CollectWindowState(cnfg.hWnd)

  ; If window did not get the intended size, reposition window using its current size
  if newWinState.width != fscr.window.w || newWinState.height != fscr.window.h
  {
    fscr := lib_calcFullscreenArgs(newWinState,
                                  _monitor := cnfg.monitor,
                                  _winSize := "keep",
                                  _taskbar := cnfg.taskbar)

    if ! fscr.ok {
      restoreWindowState(cnfg.hWnd, cnfg.origState)
      ConsoleMsg "ERROR: {}".f(fscr.reason)
      return
    }

    WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, cnfg.hWnd)
  }

  newWinState := unset


  ;; Modify background overlay
  if ! fscr.needsBackgroundOverlay
  {
    bkgr.Hide()
  }
  else
  {
    ; Resize the click area
    bkgr.clickArea.Move(0, 0, fscr.overlay.w, fscr.overlay.h)

    ; Resize overlay (also make it visible if it was hidden before)
    bkgr.Show("x{} y{} w{} h{}".f(fscr.overlay.x, fscr.overlay.y, fscr.overlay.w, fscr.overlay.h))

    ; Cut a hole in the overlay for the game window to be seen
    ; NOTE: Coordinates are relative to the overlay, not the desktop area
    polygonStr := Format(
      "  0-0   {1}-0   {1}-{2}   0-{2}   0-0 "
      "{3}-{4} {5}-{4} {5}-{6} {3}-{6} {3}-{4}",
      fscr.overlay.w,                                 ;{1} Overlay Area: width
      fscr.overlay.h,                                 ;{2} Overlay Area: height
      fscr.window.x - fscr.overlay.x,                 ;{3} Game Window: x coordinate (left)
      fscr.window.y - fscr.overlay.y,                 ;{4} Game Window: y coordinate (top)
      fscr.window.x - fscr.overlay.x + fscr.window.w, ;{5} Game Window: x coordinate (right)
      fscr.window.y - fscr.overlay.y + fscr.window.h, ;{6} Game Window: y coordinate (bottom)
    )
    WinSetRegion(polygonStr, bkgr.hwnd)
  }


  if ! fscr.needsAlwaysOnTop
  {
    ; Disable game window always on top
    if DEBUG
      ConsoleMsg "DEBUG: Disable AlwaysOnTop on game window"

    WinSetAlwaysOnTop(false, cnfg.hWnd)
    WinSetAlwaysOnTop(false, bkgr.hWnd)
  }
  else
  {
    ; Make game window always on top
    if DEBUG
      ConsoleMsg "DEBUG: Set AlwaysOnTop on game window"

    WinSetAlwaysOnTop(true, cnfg.hWnd)
    WinSetAlwaysOnTop(true, bkgr.hWnd)
  }


  ;; Print new window state
  if DEBUG
    ConsolePrintWindowState(cnfg.hWnd, "New window state")
}


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
;       1) showing the taskbar even while the game is in focus,
;       2) not showing other windows when switching focus to them.
;         To fix this the code has basically been hacked and tested until
;       it seems to work good enough.

; Function is run when any event happens in MS Windows on any window
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  global cnfg  ; Global config
  global fscr  ; Fullscreen config
  global bkgr  ; Background overlay window

  static HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Do nothing if AlwaysOnTop is not needed
  if !IsSet(fscr) || !fscr.needsAlwaysOnTop
    return

  ; React on events about switching focus to another window
  if wParam = HSHELL_WINDOWACTIVATED
  || wParam = HSHELL_RUDEAPPACTIVATED {

    if lParam = cnfg.hWnd {

      ; Game Window got focus: Set AlwaysOnTop
      if DEBUG
        ConsoleMsg "DEBUG: lParam={} wParam={}".f("game", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(true, cnfg.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(true, bkgr.hWnd)
      catch {
        ;
      }
      ; RACE CONDITION HACK: Do everything again (ugly hack)
      ;   MS Windows sometimes paints the taskbar above the Game Window even if
      ;   we set AlwaysOnTop. Setting AlwaysOnTop again after a short sleep
      ;   seems to fix the issue.
      sleep 200  ; Milliseconds
      try
        WinSetAlwaysOnTop(true, cnfg.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(true, bkgr.hWnd)
      catch {
        ;
      }

    } else if lParam = 0 {

      ; DO NOTHING
      ;   Focus was changed to the Windows taskbar, the overlay
      ;   we created around the Game Window, or something unknown.
      if DEBUG
        ConsoleMsg "DEBUG: lParam={} wParam={}".f("null", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")

    } else {

      ; Another Window got focus: Turn off AlwaysOnTop
      if DEBUG
        ConsoleMsg "DEBUG: lParam={} wParam={}".f(lParam, wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(false, cnfg.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(false, bkgr.hWnd)
      catch {
        ;
      }
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

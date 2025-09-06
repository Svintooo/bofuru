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
#Include %A_ScriptDir%\lib\logger.ahk
#Include %A_ScriptDir%\lib\user_window_select.ahk
#Include %A_ScriptDir%\lib\can_window_be_fullscreened.ahk
#Include %A_ScriptDir%\lib\generate_transparent_pixel.ahk
#Include %A_ScriptDir%\lib\parse_window_style.ahk
#Include %A_ScriptDir%\lib\calc_fullscreen_args.ahk

; Make WinTitle (arg used by AHK functions) do regex instead of string matching.
SetTitleMatchMode "RegEx"

; Make all mouse coordinates relative to the desktop area.
; (the default is relative to the window position under the mouse pointer)
CoordMode "Mouse", "Screen"

; Print debug info to log
DEBUG := false



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Define All Global Variables
{
  ;; These are properly defined later in the script
  mainGui := 0  ; Main window
  bgGui   := 0  ; Background Overlay window (visible around the game during fullscreen)
  conLog  := 0  ; Console Logger (prints text to a console in mainGui)

  ;; Settings (only modified by the user)
  settings := { monitor: 0,      ; Selected computer monitor
                resize:  "",     ; Window resize method during fullscreen
                taskbar: false,  ; Show MS Windows Taskbar during fullscreen
                launch:  "" }    ; (optional) Start game using this launch string

  ;; Game info
  game := { hWnd:       0,  ; Window ID (a.k.a. Handler Window)
            proc_ID:    0,  ; Process ID (PID)
            proc_name: "",  ; Process Name
            win_title: "",  ; Window Title
            win_class: "",  ; Window Class
            win_text:  ""}  ; Window Text

  ;; Window Mode
  window_mode := { window:     {x:0, y:0, w:0, h:0},  ; Position/dimention of window
                   ;clientArea: {x:0, y:0, w:0, h:0},  ; Position/dimention of window client area
                   menu:       0x00000000,            ; Window menu
                   style:      0x00000000,            ; Window style
                   exStyle:    0x00000000, }          ; Window extended style

  ;; Fullscreen Mode
  fullscreen_mode := { status_ok:        false,                 ; Is fullscreen possible?
                       status_reason:    "",
                       window:           {x:0, y:0, w:0, h:0},  ; Position/dimention of window
                       monitor:          {x:0, y:0, w:0, h:0},  ; Position/dimention of computer monitor
                       screen:           {x:0, y:0, w:0, h:0},  ; Position/dimention of desktop area
                       background:       {x:0, y:0, w:0, h:0},  ; Position/dimention of background overlay
                       needsBackground:  false,
                       needsAlwaysOnTop: false }                ; If AlwaysOnTop is needed on window and background

  ;;TODO: Prevent additional properties
  ; Object.Seal(settings)
  ; Object.Seal(game)
  ; Object.Seal(window_mode)
  ; Object.Seal(fullscreen_mode)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Window: Main Gui
{
  ; NOTE: Each GuiControl can be given a NAME.
  ;       NAME is set with option: "vNAME"
  ;       A GuiControl can then be accessed with: mainGui["NAME"]

  ; NOTE: A radio button with option "Group" starts a new group of radio buttons.
  ;       Each radio button created afterwards belong to the same group.

  ; Window
  mainGui := Gui("+Border +Caption +MinimizeBox -MaximizeBox +MinSize +MaxSize -Resize +SysMenu +Theme"
                , _winTitle := "BoFuRu")
  mainGui.SetFont("S12")  ; Font Size
  mainGui.OnEvent("Close", (*) => ExitApp())  ; Stop script on window close
  mainGui.spacing := 0  ; Vertical spacing between Gui Controls (inside a group of Gui Controls)

  ; Console
  mainGui.AddEdit("vConsole w1000 h300 +Multi +Wrap +ReadOnly +WantCtrlA -WantReturn -WantTab -HScroll +VScroll +Ccccccc +Background0c0c0c")
  mainGui["Console"].setFont(, "Consolas")  ; Monospace font
  mainGui["Console"].getPos(, , &consoleWidth, )
  mainGui.defaultOpts := "w{} Y+{} ".f(consoleWidth, mainGui.spacing)
  consoleWidth := unset

  ; Buttons
  mainGui.AddButton(mainGui.defaultOpts "vButton_WinSelect",           "Select Window")
  mainGui.AddButton(mainGui.defaultOpts "vButton_Fullscreen Disabled", "Toggle Fullscreen")
  mainGui.AddButton(mainGui.defaultOpts "VButton_Exe        Disabled", "Select Exe")
  mainGui.AddButton(mainGui.defaultOpts "VButton_Run        Disabled", "Run Exe")

  ; Settings - Monitors
  mainGui.AddText("vText_Monitor", "Monitor")
  mainGui.AddRadio(mainGui.defaultOpts "vRadio_Monitor_{} Group".f("auto"), String("Auto"))
  loop MonitorGetCount()
  {
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_Monitor_{}".f(A_Index), String(A_Index))
  }
  mainGui["Radio_Monitor_" "auto"].Value := true  ; Radio button is checked by default
  groupOpt := unset

  ; Settings - Window Size
  mainGui.AddText("vText_WindowSize", "Window Size")
  for WinSizeOpt in ["fit", "pixel-perfect", "stretch", "original"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    WinSizeOpt_HumanReadable := WinSizeOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
                                          .StrReplace("-"," ")
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_WinSize_{} {}".f(WinSizeOpt.StrReplace("-","_"),groupOpt), WinSizeOpt_HumanReadable)
  }
  mainGui["Radio_WinSize_" "fit"].Value := true  ; Radio button is checked by default
  groupOpt := WinSizeOpt_HumanReadable := unset

  ; Settings - Taskbar
  mainGui.AddText("vText_Taskbar", "Taskbar")
  for TaskbarOpt in ["hide", "show", "show2", "show3"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    TaskbarOpt_HumanReadable := TaskbarOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_TaskBar_{}".f(TaskbarOpt), TaskbarOpt_HumanReadable)
  }
  mainGui["Radio_TaskBar_" "hide"].Value := true  ; Radio button is checked by default
  groupOpt := TaskbarOpt_HumanReadable := unset

  ; Quit Button
  mainGui.AddButton(mainGui.defaultOpts "vButton_Quit", "Quit")
  mainGui["Button_Quit"].OnEvent("Click", (*) => WinClose(mainGui.hWnd))

  ; Show the window
  mainGui.Show()
  DllCall("User32.dll\HideCaret", "Ptr", mainGui["Console"].Hwnd)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Logging
{
  ; Console Logger
  conLog := lib_Logger(
    ; Define log writer function
    (message) => (
      ; Write message to Console
      mainGui["Console"].Value .= message,

      ; Scroll Console to bottom after weach write
      DllCall(
        "User32.dll\SendMessage",
        "Ptr", mainGui["Console"].hWnd,
        "UInt",0x115,  ; WM_VSCROLL
        "Ptr", 7,      ; SB_BOTTOM
        "Ptr", 0
      )
    ),

    ; Define available log methods
    Map(
      ; Method   LeadingMsg
      ; ------   ----------
      "debug"  , "DEBUG: ",
      "info"   , "INFO : ",
      "warn"   , "WARN : ",
      "error"  , "ERROR: ",
      "unknown", "UNKNOWN: ",
      "raw"    , ""
    )
  )
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Log Welcome Message
{
  conLog.raw "##################################", "NoNewLine"
  conLog.raw "#       ===== BoFuRu =====       #"
  conLog.raw "# Windowed Borderless Fullscreen #"
  conLog.raw "##################################", "MinimumEmptyLinesAfter 1"
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Window: Background Overlay
{
  ;; Generate transparent pixel
  ; Needed to make the overlay allow both mouse clicks and buttons
  if DEBUG
    conLog.debug "Generate transparent pixel"

  result := lib_GenerateTransparentPixel()

  if !result.ok {
    conLog.error "Failed generating transparent pixel: {}".f(result.reason)
    return
  }

  pixel := result.data
  result := unset


  ;; Create window
  if DEBUG
    conLog.debug "Create background overlay (hidden for now)"

  bgGui := Gui("+ToolWindow -Caption -Border +AlwaysOnTop")
  bgGui.BackColor := "black"

  ; Create internal window control (will always cover the whole overlay)
  WS_CLIPSIBLINGS := 0x04000000  ; This will let pictures be both clickable,
                                 ; and have other elements placed on top of them.
  bgGui.AddPicture("vClickArea {}".f(WS_CLIPSIBLINGS), pixel)

  ; Make mouse clicks on overlay restore focus to game window
  bgGui["ClickArea"].OnEvent("Click",       (*) => WinActivate(settings.hWnd))
  bgGui["ClickArea"].OnEvent("DoubleClick", (*) => WinActivate(settings.hWnd))


  ;; Clean up
  pixel := unset
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Misc
{
  ;; Detect focus change to any window
  ; Tell MS Windows to notify us of events for all windows.
  ; - ShellMessage(): Function which receives the events.
  if DEBUG
    conLog.debug "Bind focus change event to toggle AlwaysOnTop"

  if DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
  {
    MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    OnMessage(MsgNum, ShellMessage)
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start - Global Config and Argument Parsing
{
  ;; Fetch command line arguments
  args := parseArgs(A_Args)
  if DEBUG
    conLog.debug "Parsed args: {}".f(args.Inspect())


  ;; Create global config
  ; Settings in this object will control everything.
  ; Any code modifying config should trigger a redraw of fullscreen (if fullscreen is active).
  settings := {}

  ; Set config parameters
  DEBUG        := args.HasOwnProp("debug")   ? args.DeleteProp("debug"  ).value : DEBUG,
  settings.monitor := args.HasOwnProp("monitor") ? args.DeleteProp("monitor").value : false,
  settings.winsize := args.HasOwnProp("winsize") ? args.DeleteProp("winsize").value : "fit",
  settings.taskbar := args.HasOwnProp("taskbar") ? args.DeleteProp("taskbar").value : "hide"
  settings.launch  := args.HasOwnProp("launch")  ? args.DeleteProp("launch" ).value : ""
  settings.ahk_wintitle := args.HasOwnProp("ahk_wintitle") ? args.DeleteProp("ahk_wintitle").value : ""
  settings.hWnd    := 0
  settings.pid     := 0


  ;; Handle unknown args
  if !args.IsEmpty()
  {
    for , argObj in args.OwnProps()
      conLog.warn "Unknown arg: {}".f(argObj.argStr)
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start - Launch game and Find game window
{
  ;; Run an *.exe
  if settings.launch
  {
    conLog.info "Launching: {}".f(settings.launch)
    result := launchExe(settings.launch)

    if ! result.ok {
      conLog.error "Launch failed"
      return
    }

    settings.pid := result.pid
    result := unset
    if DEBUG
      conLog.debug "Launch success, got PID: " settings.pid
  }


  ;; Find Window
  if settings.ahk_wintitle
  {
    conLog.info "Waiting for window: {}".f(settings.ahk_wintitle.Inspect())
    settings.hWnd := WinWait(settings.ahk_wintitle)
  }
  else if settings.pid
  {
    manualWindowSelection(&conLog)
  }


  ;; Make game window fullscreen
  ; If a game window has been found.
  if settings.hWnd
  {
    synchronizeWithWindow(settings.hWnd, &settings, &conLog)

    conLog.info "Activate Window Fullscreen"
    activateFullscreen(&conLog)
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Functions

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

      arg   := args.Slice(i).Inspect()
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
collectWindowInfo(hWnd, &config)
{
  config.winTitle     := WinGetTitle(       "ahk_id" hWnd )
  config.winClass     := WinGetClass(       "ahk_id" hWnd )
  config.winText      := WinGetText(        "ahk_id" hWnd ).Trim("`r`n ")
  config.pid          := WinGetPID(         "ahk_id" hWnd )
  config.procName     := WinGetProcessName( "ahk_id" hWnd )
  config.ahk_wintitle := "{} ahk_class {} ahk_exe {}".f(config.winTitle, config.winClass, config.procName)
}


;; Collect Window state
collectWindowState(hWnd)
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
logWindowInfo(config, &logg)
{
  logg.info , _options := "MinimumEmptyLinesBefore 1"
  logg.info   "Window info"
  if DEBUG {
    logg.info "- PID           = {}".f(config.pid)
    logg.info "- hWnd          = {}".f(config.hWnd)
  }
  logg.info   "- Process Name  = {}".f(config.procName.Inspect())
  logg.info   "- Title         = {}".f(config.winTitle.Inspect())
  logg.info   "- Class         = {}".f(config.winClass.Inspect())
  if DEBUG {
    logg.info "- Text          = {}".f(config.winText.Inspect())
  }
  logg.info   "- --ahk-wintitle={}".f(config.ahk_wintitle.Inspect())
  logg.info , _options := "MinimumEmptyLinesAfter 1"
}


;; Print window state
logWindowState(hWnd_or_winState, message, &logg)
{
  if hWnd_or_winState is Number
    winState := collectWindowState(hWnd_or_winState)
  else
    winState := hWnd_or_winState

  winStyleStr   := "0x{:08X} ({})".f(winState.winStyle,   lib_parseWindowStyle(winState.winStyle)    .Join(" | "))
  winExStyleStr := "0x{:08X} ({})".f(winState.winExStyle, lib_parseWindowExStyle(winState.winExStyle).Join(" | "))
  winMenuStr    := "0x{:08X}".f(winState.winMenu)

  logg.debug , _options := "MinimumEmptyLinesBefore 1"
  logg.debug "{}".f(message)
  logg.debug "- x           = {}".f(winState.x)
  logg.debug "- y           = {}".f(winState.y)
  logg.debug "- width       = {}".f(winState.width)
  logg.debug "- height      = {}".f(winState.height)
  logg.debug "- innerWidth  = {}".f(winState.innerWidth)
  logg.debug "- innerHeight = {}".f(winState.innerHeight)
  logg.debug "- winStyle    = {}".f(winStyleStr)
  logg.debug "- winExStyle  = {}".f(winExStyleStr)
  logg.debug "- winMenu     = {}".f(winMenuStr)
  logg.debug , _options := "MinimumEmptyLinesAfter 1"
}


;; Print exception
logException(e, &logg)
{
  logg.unknown , _options := "MinimumEmptyLinesBefore 1"
  logg.unknown "{} threw error of type {}".f(e.What.Inspect(), Type(e))
  logg.unknown "- msg: {}".f(e.Message.Inspect())
  logg.unknown "- xtra: {}".f(e.Extra.Inspect())
  logg.unknown , _options := "MinimumEmptyLinesAfter 1"
}


;; Remove window border
removeWindowBorder(hWnd, &logg)
{
  global DEBUG

  if settings.origState.winMenu
    DllCall("SetMenu", "uint", settings.hWnd, "uint", 0)

  ; Remove styles (border)
  newWinStyle := 0x80000000  ; WS_POPUP (no border, no titlebar)
               | 0x10000000  ; WS_VISIBLE
  try
    WinSetStyle(newWinStyle, "ahk_id" settings.hWnd)
  catch as e
    if DEBUG
      logException(e, &logg)

  ; Remove extended styles (NOTE: may not be needed)
  removeWinExStyle := 0x00000001 ; WS_EX_DLGMODALFRAME (double border)
                    | 0x00000100 ; WS_EX_WINDOWEDGE    (raised border edges)
                    | 0x00000200 ; WS_EX_CLIENTEDGE    (sunken border edges)
                    | 0x00020000 ; WS_EX_STATICEDGE    (three-dimensional border)
                    | 0x00000400 ; WS_EX_CONTEXTHELP   (title bar question mark)
                    | 0x00000080 ; WS_EX_TOOLWINDOW    (floating toolbar window type: shorter title bar, smaller title bar font, no ALT+TAB)
  try
    WinSetExStyle("-" removeWinExStyle, "ahk_id" settings.hWnd)   ; The minus (-) removes the styles from the current window styles
  catch as e
    if DEBUG
      logException(e, &logg)

  ; Restore the correct window client area width/height
  ; (these gets distorted when the border is removed)
  WinMove(, , settings.origState.innerWidth, settings.origState.innerHeight, settings.hWnd)
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
synchronizeWithWindow(hWnd, &config, &logg)
{
  ;; Collect window info
  collectWindowInfo(hWnd, &config)


  ;; Print window info
  logWindowInfo(config, &logg)


  ;; Check if window is allowed
  if !lib_canWindowBeFullscreened(config.hWnd, config.winClass)
  {
    logg.error "Unsupported window selected"
    return
  }


  ;; Exit script if the game window is closed
  if DEBUG
    logg.debug "Bind exit event to window close"

  Event_AppExit() {
    if not WinExist("ahk_id" config.hWnd)
      ExitApp(0)
  }

  MAX_PRIORITY := 2147483647
  SetTimer(Event_AppExit, , _prio := MAX_PRIORITY)


  ;; Focus the window
  if DEBUG
    logg.debug "Put the game window in focus"

  WinActivate(config.hWnd)


  ;; Collect Window State
  if DEBUG
    logg.debug "Collecting current window state"

  config.origState := collectWindowState(config.hWnd)

  if DEBUG
    logWindowState(config.origState, "Window state (original)", &logg)


  ;; Restore window state on exit
  if DEBUG
    logg.debug "Register OnExit callback to restore window state on exit"

  OnExit (*) => restoreWindowState(config.hWnd, config.origState)
}


;; Manual window selection
; Let user click on the window that shall be made fullscreen.
manualWindowSelection(&logg)
{
  global mainGui
  global settings  ; Global config

  logg.info , _options := "MinimumEmptyLinesBefore 1"
  logg.info "Manual Window selection ACTIVATED"
  logg.info "- Click on game window"
  logg.info "- Press Esc to cancel"
  logg.info , _options := "MinimumEmptyLinesAfter 1"

  result := lib_userWindowSelect()
  while result.ok && !lib_canWindowBeFullscreened(result.hWnd, result.className)
  {
    logg.error "This window is unsupported: Try again"
    result := lib_userWindowSelect()
  }

  if ! result.ok {
    if result.reason = "user cancel"
      logg.info "Manual Window selection CANCELLED", _options := "MinimumEmptyLinesAfter 1"
    else
      logg.error "{}".f(result.reason)

    WinActivate(mainGui.hWnd)  ; Focus the Gui
  } else {
    logg.info "Manual Window selection SUCCEEDED", _options := "MinimumEmptyLinesAfter 1"
    settings.hWnd := result.hWnd
  }
}


;; Activate FULLSCREEN
; All other code only exist to help use this function.
; - Changes window size and position to make it fullscreen.
; - global var `settings` decides how the fullscreen will be made.
; - global var `fscr` will be created.
; - global var `bgGui` will be modified.
activateFullscreen(&logg)
{
  global settings  ; Global config
  global fscr      ; Fullscreen config
  global bgGui     ; Background overlay window

  ;; Remove Window Border
  logg.info "Remove window styles (border, menu, title bar, etc)"
  removeWindowBorder(settings.hWnd, &logg)


  ;; Get new window state
  settings.noBorderState := collectWindowState(settings.hWnd)
  if DEBUG
    logWindowState(settings.noBorderState, "Window state (no border)", &logg)


  ;; Warn if window lost its aspect ratio
  if settings.noBorderState.width  != settings.origState.innerWidth
  || settings.noBorderState.height != settings.origState.innerHeight
  {
    logg.warn , _options := "MinimumEmptyLinesBefore 1"
    logg.warn "Window refuses to keep its proportions (aspect ratio) after the border was removed."
    logg.warn "You may experience distorted graphics and slightly off mouse clicks."
    logg.warn , _options := "MinimumEmptyLinesAfter 1"
  }


  ;; Calculate window fullscreen properties
  if DEBUG
    logg.debug "Calculate window fullscreen properties"

  fscr := lib_calcFullscreenArgs(settings.noBorderState,
                                 _monitor := settings.monitor,
                                 _winSize := settings.winsize,
                                 _taskbar := settings.taskbar)

  if ! fscr.ok {
    restoreWindowState(settings.hWnd, settings.origState)
    logg.error "{}".f(fscr.reason)
    return
  }


  ;; Resize and reposition window
  if DEBUG
    logg.debug "Resize and reposition window"

  WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, settings.hWnd)
  sleep 1  ; Millisecond
  newWinState := collectWindowState(settings.hWnd)

  ; If window did not get the intended size, reposition window using its current size
  if newWinState.width != fscr.window.w || newWinState.height != fscr.window.h
  {
    fscr := lib_calcFullscreenArgs(newWinState,
                                  _monitor := settings.monitor,
                                  _winSize := "keep",
                                  _taskbar := settings.taskbar)

    if ! fscr.ok {
      restoreWindowState(settings.hWnd, settings.origState)
      logg.error "{}".f(fscr.reason)
      return
    }

    WinMove(fscr.window.x, fscr.window.y, fscr.window.w, fscr.window.h, settings.hWnd)
  }

  newWinState := unset


  ;; Modify background overlay
  if ! fscr.needsBackgroundOverlay
  {
    bgGui.Hide()
  }
  else
  {
    ; Resize the click area
    bgGui["ClickArea"].Move(0, 0, fscr.overlay.w, fscr.overlay.h)

    ; Resize overlay (also make it visible if it was hidden before)
    bgGui.Show("x{} y{} w{} h{}".f(fscr.overlay.x, fscr.overlay.y, fscr.overlay.w, fscr.overlay.h))

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
    WinSetRegion(polygonStr, bgGui.hwnd)
  }


  ;; AlwaysOnTop
  if ! fscr.needsAlwaysOnTop
  {
    ; Disable game window always on top
    if DEBUG
      logg.debug "Disable AlwaysOnTop on game window"

    WinSetAlwaysOnTop(false, settings.hWnd)
    WinSetAlwaysOnTop(false, bgGui.hWnd)
  }
  else
  {
    ; Make game window always on top
    if DEBUG
      logg.debug "Set AlwaysOnTop on game window"

    WinSetAlwaysOnTop(true, settings.hWnd)
    WinSetAlwaysOnTop(true, bgGui.hWnd)
  }


  ;; Print new window state
  if DEBUG
    logWindowState(settings.hWnd, "Window state (fullscreen)", &logg)


  ;; End message
  logg.info "Your game should now be in fullscreen"
}


;; Deactivate FULLSCREEN
deactivateFullscreen()
{
  global settings  ; Global config
  global fscr      ; Fullscreen config
  global bgGui     ; Background overlay window

  bgGui.Hide()
  restoreWindowState(settings.hWnd, settings.origState)
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
  global settings  ; Global config
  global fscr      ; Fullscreen config
  global bgGui     ; Background overlay window

  static HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Do nothing if AlwaysOnTop is not needed
  if !IsSet(fscr) || !fscr.needsAlwaysOnTop
    return

  ; React on events about switching focus to another window
  if wParam = HSHELL_WINDOWACTIVATED
  || wParam = HSHELL_RUDEAPPACTIVATED {

    if lParam = settings.hWnd {

      ; Game Window got focus: Set AlwaysOnTop
      if DEBUG
        conLog.debug "lParam={} wParam={}".f("game", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(true, settings.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(true, bgGui.hWnd)
      catch {
        ;
      }
      ; RACE CONDITION HACK: Do everything again (ugly hack)
      ;   MS Windows sometimes paints the taskbar above the Game Window even if
      ;   we set AlwaysOnTop. Setting AlwaysOnTop again after a short sleep
      ;   seems to fix the issue.
      sleep 200  ; Milliseconds
      try
        WinSetAlwaysOnTop(true, settings.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(true, bgGui.hWnd)
      catch {
        ;
      }

    } else if lParam = 0 {

      ; DO NOTHING
      ;   Focus was changed to the Windows taskbar, the overlay
      ;   we created around the Game Window, or something unknown.
      if DEBUG
        conLog.debug "lParam={} wParam={}".f("null", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")

    } else {

      ; Another Window got focus: Turn off AlwaysOnTop
      if DEBUG
        conLog.debug "lParam={} wParam={}".f(lParam, wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(false, settings.hWnd)
      catch {
        ;
      }
      try
        WinSetAlwaysOnTop(false, bgGui.hWnd)
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

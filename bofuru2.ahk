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



;;    █████████  ████           █████               ████
;;   ███░░░░░███░░███          ░░███               ░░███
;;  ███     ░░░  ░███   ██████  ░███████   ██████   ░███   █████
;; ░███          ░███  ███░░███ ░███░░███ ░░░░░███  ░███  ███░░
;; ░███    █████ ░███ ░███ ░███ ░███ ░███  ███████  ░███ ░░█████
;; ░░███  ░░███  ░███ ░███ ░███ ░███ ░███ ███░░███  ░███  ░░░░███
;;  ░░█████████  █████░░██████  ████████ ░░████████ █████ ██████
;;   ░░░░░░░░░  ░░░░░  ░░░░░░  ░░░░░░░░   ░░░░░░░░ ░░░░░ ░░░░░░

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Globals - Main Gui
; Creates the global var `mainGui` (the Gui window of this script).
{
  ; NOTE: Each GuiControl can be given a NAME.
  ;       NAME is set with option: "vNAME"
  ;       A GuiControl can then be accessed with: mainGui["NAME"]

  ; NOTE: A radio button with option "Group" starts a new group of radio buttons.
  ;       Each radio button created afterwards belong to the same group.

  ;; Window
  mainGui := Gui("+Border +Caption +MinimizeBox -MaximizeBox +MinSize +MaxSize -Resize +SysMenu +Theme"
                , _winTitle := "BoFuRu")
  mainGui.SetFont("S11")  ; Font Size
  mainGui.OnEvent("Close", (*) => ExitApp())  ; Stop script on window close
  mainGui.spacing  := 0  ; Vertical spacing between Gui Controls (inside a group of Gui Controls)
  ; Add support for disabling the whole Gui
  mainGui.disabled := false
  mainGui.disable  := mainGui_disable
  mainGui.enable   := mainGui_enable
  mainGui_disable(this) {
    this.disabled := true
    for guiCtrl in this
      if guiCtrl.name != "Console" && guiCtrl.name != "Button_Quit"
        guiCtrl.Opt("+Disabled")
  }
  mainGui_enable(this) {
    this.disabled := false
    for guiCtrl in this
      guiCtrl.Opt("-Disabled")
  }


  ;; Console
  mainGui.AddEdit("vConsole w1000 h300 +Multi +Wrap +ReadOnly -TabStop +WantCtrlA -WantReturn -WantTab -HScroll +VScroll +Ccccccc +Background0c0c0c")
  mainGui["Console"].setFont(, "Consolas")  ; Monospace font
  ; Set default options for all Gui Controls
  mainGui["Console"].getPos(, , &consoleWidth, )
  mainGui.defaultOpts := "w{} Y+{} ".f(consoleWidth, mainGui.spacing)
  consoleWidth := unset  ; Cleanup


  ;; Buttons
  mainGui.AddButton(mainGui.defaultOpts "vButton_WinSelect",           "Select Window")
  mainGui.AddButton(mainGui.defaultOpts "vButton_Fullscreen Disabled", "Toggle Fullscreen")
  mainGui.AddButton(mainGui.defaultOpts "vButton_Exe",                 "Select Exe")
  mainGui.AddButton(mainGui.defaultOpts "vButton_Run        Disabled", "Launch Exe")
  mainGui.AddButton(mainGui.defaultOpts "vButton_CreateLnk  Disabled", "Create Shortcut")


  ;; Text Edit Fields
  mainGui.AddEdit(mainGui.defaultOpts "vEdit_WinTitle")
  mainGui.AddEdit(mainGui.defaultOpts "vEdit_WinClass")
  mainGui.AddEdit(mainGui.defaultOpts "vEdit_ProcName")
  mainGui.AddEdit(mainGui.defaultOpts "vEdit_Launch")


  ;; Radio Buttons: Computer Monitor
  mainGui.AddText("vText_Monitor", "Monitor")
  mainGui.AddRadio(mainGui.defaultOpts "vRadio_Monitor_0 Group", "Auto")
  loop MonitorGetCount()
  {
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_Monitor_{}".f(A_Index), String(A_Index))
  }
  mainGui["Radio_Monitor_0"].Value := true  ; This Radio button is checked by default
  ; Set/Get methods
  mainGui.DefineProp("monitor_value", { Set: mainGui_Monitor_Set_Func, Get: mainGui_Monitor_Get_Func })
  mainGui_Monitor_Set_Func(this, value) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_Monitor_([0-9]+)", &match)
        guiCtrl.Value := (Integer(match[1]) == Integer(value))
    return
  }
  mainGui_Monitor_Get_Func(this) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_Monitor_([0-9]+)", &match)
        if guiCtrl.Value
          return Integer(match[1])
    return 0  ; Fallback return value (this should never happen)
  }


  ;; Radio Buttons: Window Resize Method
  mainGui.AddText("vText_WindowResize", "Window Reize")
  for WinResizeOpt in ["fit", "pixel-perfect", "stretch", "original"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    WinResizeOpt_HumanReadable := WinResizeOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
                                              .StrReplace("-"," ")
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_WinResize_{} {}".f(WinResizeOpt,groupOpt), WinResizeOpt_HumanReadable)
  }
  groupOpt := WinResizeOpt_HumanReadable := unset  ; Cleanup
  mainGui["Radio_WinResize_fit"].Value := true     ; This Radio button is checked by default
  ; Set/Get methods
  mainGui.DefineProp("resize_value", { Set: mainGui_Resize_Set_Func, Get: mainGui_Resize_Get_Func })
  mainGui_Resize_Set_Func(this, value) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_WinResize_([-a-z]+)", &match)
        guiCtrl.Value := (match[1] == value)
    return
  }
  mainGui_Resize_Get_Func(this) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_WinResize_([-a-z]+)", &match)
        if guiCtrl.Value
          return match[1]
    return "fit"  ; Fallback return value (this should never happen)
  }


  ;; Radio Buttons: Taskbar Show/Hide
  mainGui.AddText("vText_Taskbar", "Taskbar")
  for TaskbarOpt in ["hide", "show", "show2", "show3"]
  {
    groupOpt := ((A_Index = 1) ? "Group" : "")
    TaskbarOpt_HumanReadable := TaskbarOpt.RegExReplace("\w+","$t{0}")  ; Capitalize (title case)
    mainGui.AddRadio(mainGui.defaultOpts "vRadio_TaskBar_{}".f(TaskbarOpt), TaskbarOpt_HumanReadable)
  }
  groupOpt := TaskbarOpt_HumanReadable := unset  ; Cleanup
  mainGui["Radio_TaskBar_hide"].Value := true    ; This Radio button is checked by default
  ; Set/Get methods
  mainGui.DefineProp("taskbar_value", { Set: mainGui_Taskbar_Set_Func, Get: mainGui_Taskbar_Get_Func })
  mainGui_Taskbar_Set_Func(this, value) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_TaskBar_([-a-z]+)", &match)
        guiCtrl.Value := (match[1] == value)
    return
  }
  mainGui_Taskbar_Get_Func(this) {
    for guiCtrl in this
      if RegExMatch(guiCtrl.name, "^Radio_TaskBar_([-a-z]+)", &match)
        if guiCtrl.Value
          return match[1]
    return "hide"  ; Fallback return value (this should never happen)
  }


  ;; Checkboxes
  mainGui.AddText("vText_Misc", "Misc")
  mainGui.AddCheckBox(mainGui.defaultOpts "vCheckBox_QuitTogether", "Quit together with game")


  ;; Quit Button
  mainGui.AddButton(mainGui.defaultOpts "vButton_Quit", "Quit")
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Globals - Console Logging
; Creates global var `conLog` (console logging framework)
{
  ; Console Logger
  conLog := lib_Logger(

    ; Define log writer function
    (message) => (
      ; Write message to Console
      mainGui["Console"].Value .= message,

      ; Scroll Console to bottom after each write
      DllCall("User32.dll\SendMessage"
        , "Ptr"  , mainGui["Console"].hWnd
        , "UInt" , 0x115  ; WM_VSCROLL
        , "Ptr"  , 7      ; SB_BOTTOM
        , "Ptr"  , 0
      )

      ; Move console text cursor to bottom
      DllCall("User32.dll\SendMessage"
        , "Ptr" , mainGui["Console"].hWnd
        , "UInt", 0x0B1  ; EM_SETSEL
        , "Ptr" , StrLen(mainGui["Console"].Value)
        , "Ptr" , StrLen(mainGui["Console"].Value)
      ),

      ; Hide text cursor
      DllCall("User32.dll\HideCaret", "Ptr", mainGui["Console"].Hwnd)
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
;; Log - Welcome Message
{
  conLog.raw "##################################", "NoNewLine"
  conLog.raw "#       ===== BoFuRu =====       #"
  conLog.raw "# Windowed Borderless Fullscreen #"
  conLog.raw "##################################", "MinimumEmptyLinesAfter 1"
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Globals - Data Objects
; Creates global vars to store/retrive settings for this script.
; NOTE: Some of the properties do not store data. They instead set/get data from `mainGui`.
{
  ;; User Settings
  ; Only modified by user, either through CLI args or throught the mainGui.
  settings := {}
  settings.DefineProp "monitor",        ; Computer monitor to fullscreen on
                    { Set: (this, newValue) => ( mainGui.monitor_value := newValue, retriggerFullscreen() )
                    , Get: (this)           => ( mainGui.monitor_value ) }
  settings.DefineProp "resize",         ; Window resize method
                    { Set: (this, newValue) => ( mainGui.resize_value  := newValue, retriggerFullscreen() )
                    , Get: (this)           => ( mainGui.resize_value ) }
  settings.DefineProp "taskbar",        ; How to show/hide the MS Windows Taskbar during fullscreen
                    { Set: (this, newValue) => ( mainGui.taskbar_value := newValue, retriggerFullscreen() )
                    , Get: (this)           => ( mainGui.taskbar_value ) }
  settings.DefineProp "launch",         ; (OPTIONAL) Start game using this launch string
                    { Set: (this, newValue) => ( mainGui["Edit_ProcName"].Value := newValue )
                    , Get: (this)           => ( mainGui["Edit_ProcName"].Value ) }
  settings.DefineProp "quit_together",  ; If this script should quit when the game is closed
                    { Set: (this, newValue) => ( mainGui["CheckBox_QuitTogether"].Value := newValue )
                    , Get: (this)           => ( mainGui["CheckBox_QuitTogether"].Value ) }


  ;; Game Window Info
  ; Data needed to find the game window.
  game := {}
  game.DefineProp "hWnd"     , { Value: 0 }  ; Window ID (a.k.a. Handler Window)
  game.DefineProp "proc_ID"  , { Value: 0 }  ; Process ID (PID)
  game.DefineProp "proc_name",               ; Process Name
                { Set: (this, newValue) => mainGui["Edit_ProcName"].Value := newValue
                , Get: (this)           => mainGui["Edit_ProcName"].Value }
  game.DefineProp "win_title",               ; Window Title
                { Set: (this, newValue) => mainGui["Edit_WinTitle"].Value := newValue
                , Get: (this)           => mainGui["Edit_WinTitle"].Value }
  game.DefineProp "win_class",               ; Window Class
                { Set: (this, newValue) => mainGui["Edit_WinClass"].Value := newValue
                , Get: (this)           => mainGui["Edit_WinClass"].Value }


  ;; Window Mode
  ; Data needed to put the game into window mode.
  window_mode := { x:0, y:0, w:0, h:0,     ; Window area
                   menu:    0x00000000,    ; Window menu
                   style:   0x00000000,    ; Window style (border)
                   exStyle: 0x00000000, }  ; Window extended style


  ;; Fullscreen Mode
  ; Data needed to put the game into fullscreen mode.
  fullscreen_mode := { x:0, y:0, w:0, h:0,         ; Window area without borders (while still in window mode)
                       needsBackground:  false,    ; If background overlay is needed
                       needsAlwaysOnTop: false,    ; If AlwaysOnTop is needed on game and background
                       active:           false, }  ; If fullscreen mode is currently active


  ;; Seal all global data objects
  ; This is a hack that prevents new properties to be created by the following
  ; kind of code: `global_var.new_prop := value
  ; This should prevent using the wrong property names by mistake.
  ObjSealFunc(*) {
    throw Error("New properties not allowed")
  }
  settings       .Base := { __Set: ObjSealFunc }
  game           .Base := { __Set: ObjSealFunc }
  window_mode    .Base := { __Set: ObjSealFunc }
  fullscreen_mode.Base := { __Set: ObjSealFunc }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Globals - Background Overlay
; Creates global var `bgGui` (background overlay window)
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
  bgGui["ClickArea"].OnEvent("Click",       (*) => WinActivate(game.hWnd))
  bgGui["ClickArea"].OnEvent("DoubleClick", (*) => WinActivate(game.hWnd))


  ;; Clean up
  pixel := unset
}



;;   █████████            █████
;;  ███░░░░░███          ░░███
;; ░███    ░░░   ██████  ███████   █████ ████ ████████
;; ░░█████████  ███░░███░░░███░   ░░███ ░███ ░░███░░███
;;  ░░░░░░░░███░███████   ░███     ░███ ░███  ░███ ░███
;;  ███    ░███░███░░░    ░███ ███ ░███ ░███  ░███ ░███
;; ░░█████████ ░░██████   ░░█████  ░░████████ ░███████
;;  ░░░░░░░░░   ░░░░░░     ░░░░░    ░░░░░░░░  ░███░░░
;;                                            ░███
;;                                            █████
;;                                           ░░░░░

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Main Gui: Show
{
  ;; Show the mainGui window
  mainGui.Show()

  ;; Set which Gui Control has focus by default
  mainGui["Button_WinSelect"].Focus()
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Main Gui: Toggle Enable/Disable of Gui Controls
{
  Event_GuiControls_ToggleEnabled(*) {
    global settings, game, mainGui

    if mainGui.disabled
      return

    mainGui["Button_Fullscreen"].Enabled := WinExist(game.hWnd)
    mainGui["Button_Run"       ].Enabled := settings.launch.IsPresent()
    mainGui["Button_CreateLnk" ].Enabled := mainGui["Button_Fullscreen"].Enabled
                                         && mainGui["Button_Run"       ].Enabled

    mainGui["Edit_WinTitle"].Enabled := not WinExist(game.hWnd)
    mainGui["Edit_WinClass"].Enabled := not WinExist(game.hWnd)
    mainGui["Edit_ProcName"].Enabled := not WinExist(game.hWnd)
    ;mainGui["Edit_Launch"  ].Enabled :=
  }

  SetTimer(Event_GuiControls_ToggleEnabled)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Main Gui: Button Actions
{
  mainGui["Button_WinSelect" ].OnEvent("Click", Button_WinSelect_Func)
  mainGui["Button_Fullscreen"].OnEvent("Click", Button_Fullscreen_Func)
  mainGui["Button_Exe"       ].OnEvent("Click", Button_Exe_Func)
  mainGui["Button_Run"       ].OnEvent("Click", Button_Run_Func)
  mainGui["Button_CreateLnk" ].OnEvent("Click", Button_CreateLnk_Func)
  mainGui["Button_Quit"      ].OnEvent("Click", (*) => WinClose(mainGui.hWnd))

  Button_WinSelect_Func(*) {
    global game, mainGui, conLog
    game_hWnd := manualWindowSelection(mainGui, conLog)
    if game_hWnd
      setGameWindow(game_hWnd, &game, conLog)
  }

  Button_Fullscreen_Func(*) {
    global settings, game, window_mode, fullscreen_mode, bgGui, conLog
    if checkFullscreenActive(game.hWnd, fullscreen_mode) {
      deactivateFullscreen(game.hWnd, bgGui, &window_mode, &fullscreen_mode, conLog)
    } else {
      prepareFullscreen(game.hWnd, &window_mode, &fullscreen_mode, conLog)
      activateFullscreen(game.hWnd, &fullscreen_mode, settings, window_mode, bgGui, conLog)
    }
  }

  Button_Exe_Func(*) {
    global settings
    file_must_exist := 0x00000001
    selectedFile := FileSelect(file_must_exist, , "Select Game - " A_ScriptName, "Application (*.exe; *.lnk)")
    if ! selectedFile
      return
    if InStr(selectedFile, " ")
      selectedFile := '"' selectedFile '"'
    settings.launch := selectedFile
  }

  Button_Run_Func(*) {
    global settings
    if settings.launch
      launchExe(settings.launch)
  }

  Button_CreateLnk_Func(*) {
    global settings
    prompt_to_create_new_file := 0x00000008
    newShortcutFile := FileSelect("S" prompt_to_create_new_file, , "Create Shortcut - " A_ScriptName)
    if ! newShortcutFile
      return
    if ! RegExMatch(newShortcutFile, "\.lnk$")
      newShortcutFile := newShortcutFile ".lnk"
    if SubStr(settings.launch, 1, 1) = '"' {
      target := '"' settings.launch.SubStr(2).Split('"')[1] '"'
      args   := settings.launch.SubStr(target.Length()+1)
    } else {
      target := settings.launch.Split(" ")[1]
      args   := settings.launch.SubStr(target.Length()+1)
    }
    FileCreateShortcut(target, newShortcutFile, , args)
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup - Main Gui: Setting Actions
{
  ;; Radio button Actions
  for radio_ctrl in mainGui {
    if RegExMatch(radio_ctrl.Name, "^(Radio_Monitor_|Radio_WinResize_|Radio_TaskBar_)")
      radio_ctrl.OnEvent("Click", (*) => ( retriggerFullscreen() ))
  }


  ;; Checkboxes Actions
  ;NOTE: The checkboxes do not need actions.
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
    msgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
    OnMessage(MsgNum, ShellMessage)
  }
  ;TODO: Add error handling here if RegisterShellHookWindow fails
  msgNum := unset


  ;; Restore game window state on exit
  if DEBUG
    conLog.debug "Register OnExit callback to restore game window on exit"

  ExitFunc(*) {
    global window_mode, fullscreen_mode

    if checkFullscreenActive(game.hWnd, fullscreen_mode)
      deactivateFullscreen(game.hWnd, bgGui, &window_mode, &fullscreen_mode, conLog)
  }
  OnExit ExitFunc


  ;; React when game window is closed
  if DEBUG
    conLog.debug "React to event when the game is closed"

  Event_GameExit() {
    global settings, game, window_mode, fullscreen_mode

    if game.hWnd && not WinExist(game.hWnd) {
      game.hWnd := 0

      if settings.quit_together
        ExitApp(0)
      else
        deactivateFullscreen(game.hWnd, bgGui, &window_mode, &fullscreen_mode, conLog)
    }
  }

  MAX_PRIORITY := 2147483647
  SetTimer(Event_GameExit, , _prio := MAX_PRIORITY)
}



;;   █████████   █████                         █████
;;  ███░░░░░███ ░░███                         ░░███
;; ░███    ░░░  ███████    ██████   ████████  ███████
;; ░░█████████ ░░░███░    ░░░░░███ ░░███░░███░░░███░
;;  ░░░░░░░░███  ░███      ███████  ░███ ░░░   ░███
;;  ███    ░███  ░███ ███ ███░░███  ░███       ░███ ███
;; ░░█████████   ░░█████ ░░████████ █████      ░░█████
;;  ░░░░░░░░░     ░░░░░   ░░░░░░░░ ░░░░░        ░░░░░

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start - Global Config and Argument Parsing
{
  ;; Fetch command line arguments
  args := parseArgs(A_Args)


  ;; DEBUG
  DEBUG := args.HasOwnProp("debug") ? args.debug : DEBUG

  if DEBUG
    conLog.debug "Parsed args: {}".f(args.Inspect())

  if args.HasOwnProp("debug")
    args.DeleteProp("debug")


  ;; Configure this script
  ; settings
  settings.monitor := args.HasOwnProp("monitor") ? args.DeleteProp("monitor").value : false
  settings.resize  := args.HasOwnProp("resize" ) ? args.DeleteProp("resize" ).value : "fit"
  settings.taskbar := args.HasOwnProp("taskbar") ? args.DeleteProp("taskbar").value : "hide"
  settings.launch  := args.HasOwnProp("launch" ) ? args.DeleteProp("launch" ).value : ""
  ; settings.quit_together: If not configured explicitly, then will be autoconfigured later in the code
  quit_together_autoconfigure := args.HasOwnProp("quit_together") ? false : true
  settings.quit_together := args.HasOwnProp("quit_together") ? args.DeleteProp("quit_together").value : false

  ; game
  game.win_title := args.HasOwnProp("wintitle") ? args.DeleteProp("wintitle").value : ""
  game.win_class := args.HasOwnProp("winclass") ? args.DeleteProp("winclass").value : ""
  game.proc_name := args.HasOwnProp("winexe"  ) ? args.DeleteProp("winexe"  ).value : ""


  ;; Handle unknown args
  if !args.IsEmpty()
    for , argObj in args.OwnProps()
      conLog.warn "Unknown arg: {}".f(argObj.argStr)


  ;; Cleanup
  args     := unset
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

    game.proc_ID := result.pid

    if DEBUG
      conLog.debug "Launch success, got PID: " game.proc_ID

    result := unset
  }


  ;; Find Window
  game_hWnd := 0
  ahk_wintitle := []

  if game.win_title
    ahk_wintitle.Push(game.win_title)
  if game.win_class
    ahk_wintitle.Push("ahk_class " game.win_class)
  if game.proc_name
    ahk_wintitle.Push("ahk_exe " game.proc_name)
  if game.hWnd
    ahk_wintitle.Push("ahk_id " game.hWnd)

  if ! ahk_wintitle.IsEmpty()
  {
    ahk_wintitle := ahk_wintitle.Join(" ")

    conLog.info "Waiting for window: {}".f(ahk_wintitle.Inspect()), "MinimumEmptyLinesBefore 1"

    mainGui.disable()

    game_hWnd := WinWait(ahk_wintitle)

    mainGui.enable()
  }
  else if game.proc_ID
  {
    game_hWnd := manualWindowSelection(mainGui, conLog)
  }

  ahk_wintitle := unset


  ;; Make game window fullscreen
  ; If a game window has been found.
  if game_hWnd
  {
    ;; Set which window to use for fullscreen
    result := setGameWindow(game_hWnd, &game, conLog)
    if !result
      return

    ;; Prepare window for fullscreen
    prepareFullscreen(game_hWnd, &window_mode, &fullscreen_mode, conLog)

    ;; Make window fullscreen
    activateFullscreen(game_hWnd, &fullscreen_mode, settings, window_mode, bgGui, conLog)

    ;; Hide mainGui and focus the game window
    mainGui.Minimize()
    WinActivate(game_hWnd)

    ;; End message
    conLog.info "Your game should now be in fullscreen"
  }


  ;; Autoconfigure: settings.quit_together
  if quit_together_autoconfigure {
    settings.quit_together := checkFullscreenActive(game.hWnd, fullscreen_mode)
    quit_together_autoconfigure := unset
  }


  ;; Cleanup
  game_hWnd := unset
}



;;  ██████████                       ████             ███
;; ░░███░░░░░█                      ░░███            ░░░
;;  ░███  █ ░  █████ █████ ████████  ░███   ██████   ████  ████████
;;  ░██████   ░░███ ░░███ ░░███░░███ ░███  ░░░░░███ ░░███ ░░███░░███
;;  ░███░░█    ░░░█████░   ░███ ░███ ░███   ███████  ░███  ░███ ░███
;;  ░███ ░   █  ███░░░███  ░███ ░███ ░███  ███░░███  ░███  ░███ ░███
;;  ██████████ █████ █████ ░███████  █████░░████████ █████ ████ █████
;; ░░░░░░░░░░ ░░░░░ ░░░░░  ░███░░░  ░░░░░  ░░░░░░░░ ░░░░░ ░░░░ ░░░░░
;;                         ░███
;;                         █████
;;                        ░░░░░

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Explain - the internal State Machine                                      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                           ;;
;; States:                                                                   ;;
;; - [NoGame] No Game Selected                                               ;;
;; - [Window] Window Mode                                                    ;;
;; - [Transi] Transition to Fullscreen                                       ;;
;; - [Fulscr] Fullscreen Mode                                                ;;
;;                                                                           ;;
;; Edges:                                                                    ;;
;; - NoGame->Window: setGameWindow()       # Select a game                   ;;
;; - Window->Transi: prepareFullscreen()   # Go fullscreen (step 1 of 2)     ;;
;; - Transi->Fulscr: activateFullscreen()  # Go fullsceeen (step 2 of 2)     ;;
;; - Fulscr->Window: deactivateFullscreen()# Go window mode                  ;;
;;                                                                           ;;
;; Loop Edges:                                                               ;;
;; - Window->Window: setGameWindow()       # Selecting another game          ;;
;; - Fulscr->Fulscr: activateFullscreen()  # Settings changed dur fullscreen ;;
;;                                                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;  ███████████                                 █████     ███
;; ░░███░░░░░░█                                ░░███     ░░░
;;  ░███   █ ░  █████ ████ ████████    ██████  ███████   ████   ██████  ████████    █████
;;  ░███████   ░░███ ░███ ░░███░░███  ███░░███░░░███░   ░░███  ███░░███░░███░░███  ███░░
;;  ░███░░░█    ░███ ░███  ░███ ░███ ░███ ░░░   ░███     ░███ ░███ ░███ ░███ ░███ ░░█████
;;  ░███  ░     ░███ ░███  ░███ ░███ ░███  ███  ░███ ███ ░███ ░███ ░███ ░███ ░███  ░░░░███
;;  █████       ░░████████ ████ █████░░██████   ░░█████  █████░░██████  ████ █████ ██████
;; ░░░░░         ░░░░░░░░ ░░░░ ░░░░░  ░░░░░░     ░░░░░  ░░░░░  ░░░░░░  ░░░░ ░░░░░ ░░░░░░

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
collectWindowInfo(hWnd, &gameWindow)
{
  gameWindow.hWnd      := hWnd
  gameWindow.win_title := WinGetTitle(       "ahk_id" hWnd )
  gameWindow.win_class := WinGetClass(       "ahk_id" hWnd )
  gameWindow.proc_ID   := WinGetPID(         "ahk_id" hWnd )
  gameWindow.proc_name := WinGetProcessName( "ahk_id" hWnd )
}


;; Print window info
logWindowInfo(gameWindow, logg)
{
  logg.info , _options := "MinimumEmptyLinesBefore 1"
  logg.info   "Window info"
  if DEBUG {
    logg.info "- PID           = {}".f(gameWindow.proc_ID)
    logg.info "- hWnd          = {}".f(gameWindow.hWnd)
  }
  logg.info   "- Process Name  = {}".f(gameWindow.proc_name.Inspect())
  logg.info   "- Title         = {}".f(gameWindow.win_title.Inspect())
  logg.info   "- Class         = {}".f(gameWindow.win_class.Inspect())
  logg.info , _options := "MinimumEmptyLinesAfter 1"
}


;; Collect Window state
collectWindowState(hWnd)
{
  ; Get window size/position
  WinGetPos(&x, &y, &width, &height, hWnd)

  ; Get window client area width/height
  ; (this is the area without the window border)
  WinGetClientPos(&clientX, &clientY, &clientWidth, &clientHeight, hWnd)

  ; Get window style (border)
  winStyle   := WinGetStyle(hWnd)
  winExStyle := WinGetExStyle(hWnd)

  ; Get window menu bar
  winMenu := DllCall("User32.dll\GetMenu", "Ptr", hWnd, "Ptr")

  winState := {
    x:x, y:y, w:width, h:height,
    clientArea: { x:clientX, y:clientY, w:clientWidth, h:clientHeight },
    menu:       winMenu,
    style:      winStyle,
    exStyle:    winExStyle,
  }

  return winState
}


;; Print window state
logWindowState(hWnd_or_winState, message, logg)
{
  if hWnd_or_winState is Number
    winState := collectWindowState(hWnd_or_winState)
  else
    winState := hWnd_or_winState

  winStyleStr   := "0x{:08X} ({})".f(winState.style,   lib_parseWindowStyle(winState.style)    .Join(" | "))
  winExStyleStr := "0x{:08X} ({})".f(winState.exStyle, lib_parseWindowExStyle(winState.exStyle).Join(" | "))
  winMenuStr    := "0x{:08X}".f(winState.menu)
  windowArea    := {x:winState.x, y:winState.y, w:winState.w, h:winState.h}

  logg.debug , _options := "MinimumEmptyLinesBefore 1"
  logg.debug   "{}".f(message)
  logg.debug   "- window     = {}".f(windowArea.Inspect())
  if winstate.HasOwnProp("clientArea")
    logg.debug "- clientArea = {}".f(winState.clientArea.Inspect())
  logg.debug   "- menu       = {}".f(winMenuStr)
  logg.debug   "- style      = {}".f(winStyleStr)
  logg.debug   "- exStyle    = {}".f(winExStyleStr)
  logg.debug , _options := "MinimumEmptyLinesAfter 1"
}


;; Print exception
logException(e, logg)
{
  logg.unknown , _options := "MinimumEmptyLinesBefore 1"
  logg.unknown "{} threw error of type {}".f(e.What.Inspect(), Type(e))
  logg.unknown "- msg: {}".f(e.Message.Inspect())
  logg.unknown "- xtra: {}".f(e.Extra.Inspect())
  logg.unknown , _options := "MinimumEmptyLinesAfter 1"
}


;; Manual window selection
; Let user click on the window that shall be made fullscreen.
manualWindowSelection(mainWindow, logg)
{
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
      logg.info "Manual Window selection CANCELLED", _options := "MinimumEmptyLinesBefore 1 MinimumEmptyLinesAfter 1"
    else
      logg.error "{}".f(result.reason)

    WinActivate(mainWindow.hWnd)  ; Focus the Gui

    return false
  } else {
    logg.info "Manual Window selection SUCCEEDED", _options := "MinimumEmptyLinesBefore 1 MinimumEmptyLinesAfter 1"
    return result.hWnd
  }
}


;; Stores which window to use for fullscreen
; - Check if window is allowed to be made fullscreen
; - Collect and store window query info in var gameWindow
setGameWindow(hWnd, &gameWindow, logg)
{
  ; Check if window is allowed to be made fullscreen
  if !lib_canWindowBeFullscreened(hWnd, WinGetClass(hWnd)) {

    logg.error "Unsupported window selected"
    result := false

  } else {

    result := true

    ; Collect window query info
    collectWindowInfo(hWnd, &gameWindow)

    ; Print window query info
    logWindowInfo(gameWindow, logg)

  }

  ; Return
  return result
}


;; Modify window state (this includes the border)
; Done using best effort: Any failure is ignored
modifyWindowState(hWnd, newWindowState, logg)
{
  ;; Helper function
  ; Run code, catch exception, ignore errors
  runCatch(func, name?) {
    try {
      func.Call()
    } catch as e {
      if IsSet(name)
        logg.warn "{} failed (this may not be a problem)".f(name)
      if DEBUG
        logException(e, logg)
    }
  }

  ;; Check if window exist
  if !WinExist(hWnd)
    return

  ;; Set window menu bar
  runCatch ()=>DllCall("User32.dll\SetMenu", "Ptr", hWnd, "Ptr", newWindowState.menu)
         , "Modify window Menu bar"

  ;; Set window style
  runCatch ()=>WinSetStyle(newWindowState.style, "ahk_id" hWnd)
         , "Modify window border (style)"

  ;; Set window extended style
  runCatch ()=>WinSetExStyle(newWindowState.exStyle, "ahk_id" hWnd)
         , "Modify window extended style"

  ;; Set window size/position
  runCatch ()=>WinMove(newWindowState.x, newWindowState.y, newWindowState.w, newWindowState.h, "ahk_id" hWnd)
         , "Modify window size/position"

  ;; Return
  return
}


;; Prepare for fullscreen
; - Store original window state in var windowMode
; - Remove all styles and border from game window
; - Store new window state in var fullscreenMode
prepareFullscreen(hWnd, &windowMode, &fullscreenMode, logg)
{
  global DEBUG

  ;; Logg that fullscreen will now be activated
  logg.info "Activate Window Fullscreen"

  ;; Configure Window Mode
  if DEBUG
    logg.debug "Collecting current window state"

  winState           := collectWindowState(hWnd)
  windowMode.x       := winState.x
  windowMode.y       := winState.y
  windowMode.w       := winState.w
  windowMode.h       := winState.h
  windowMode.menu    := winState.menu
  windowMode.style   := winState.style
  windowMode.exStyle := winState.exStyle

  if DEBUG
    logWindowState(windowMode, "Window state (original)", logg)


  ;; Remove all window decorations
  logg.info "Remove window decorations (border, menu, title bar, etc)"

  newWinState := {
    ; New window area
    x: winState.clientArea.x,
    y: winState.clientArea.y,
    w: winState.clientArea.w,
    h: winState.clientArea.h,

    ; Remove window menu
    menu:    0x00000000,

    ; Set new window styles
    style:   0x80000000  ; WS_POPUP (no border, no titlebar)
           | 0x10000000, ; WS_VISIBLE

    ; Remove some window extended styles
    exStyle: "-{}".f(    ; Prepend minus (-) to remove exStyles from current exStyles
             0x00000001  ; WS_EX_DLGMODALFRAME (double border)
           | 0x00000100  ; WS_EX_WINDOWEDGE    (raised border edges)
           | 0x00000200  ; WS_EX_CLIENTEDGE    (sunken border edges)
           | 0x00020000  ; WS_EX_STATICEDGE    (three-dimensional border)
           | 0x00000400  ; WS_EX_CONTEXTHELP   (title bar question mark)
           | 0x00000080) ; WS_EX_TOOLWINDOW    (floating toolbar window type: shorter title bar, smaller title bar font, no ALT+TAB)
  }

  modifyWindowState(hWnd, newWinState, logg)
  sleep 100  ; TODO: Properly wait for window resize to finish before continuing


  ;; Give new window state to fullscreen_mode to base fullscreen calculations on
  noBorderState := collectWindowState(hWnd)
  if DEBUG
    logWindowState(noBorderState, "Window state (no border)", logg)

  fullscreenMode.x := noBorderState.x
  fullscreenMode.y := noBorderState.y
  fullscreenMode.w := noBorderState.w
  fullscreenMode.h := noBorderState.h


  ;; Warn if window failed to get its client area restored
  if noBorderState.w != winState.clientArea.w
  || noBorderState.h != winState.clientArea.h
  {
    logg.warn , _options := "MinimumEmptyLinesBefore 1"
    logg.warn "Window refuses to keep its proportions (aspect ratio) after the border was removed."
    logg.warn "You may experience distorted graphics and mouse clicks that slightly miss their mark."
    logg.warn , _options := "MinimumEmptyLinesAfter 1"
  }
}


;; Activate FULLSCREEN
; All other code only exist to help use this function.
; - Changes window size and position to make it fullscreen.
activateFullscreen(game_hWnd, &fullscreenMode, config, windowMode, bgWindow, logg)
{
  ;; Define fullscreenMode helpers

  ; Update function
  func_updatefullscreenMode := (state) => (
    fullscreenMode.needsBackground  := state.needsBackground,
    fullscreenMode.needsAlwaysOnTop := state.needsAlwaysOnTop
  )

  ; Error fallback function
  func_fullscreen_abort := () => (
    logg.error("{}".f(fscr.reason)),
    modifyWindowState(game_hWnd, windowMode, logg),
    bgWindow.Hide()
  )

  ; Shortform access variables
  winArea  := "windowArea"      ; fscr.windowArea     = fscr.%winArea%
  bgArea   := "backgroundArea"  ; fscr.backgroundArea = fscr.%bgArea%


  ;; Calculate Fullscreen Mode
  if DEBUG
    logg.debug "Configure fullscreen mode"

  fscr := lib_calcFullscreenArgs(fullscreenMode,
                                 _monitor := config.monitor,
                                 _winSize := config.resize,
                                 _taskbar := config.taskbar)

  if DEBUG
    logg.debug "fscr = {}".f(fscr.Inspect())

  if ! fscr.ok {
    ; Restore window mode and return
    func_fullscreen_abort()
    return false
  }

  func_updatefullscreenMode(fscr)


  ;; Resize and reposition window
  if DEBUG
    logg.debug "Resize and reposition window"

  WinMove(fscr.%winArea%.x, fscr.%winArea%.y, fscr.%winArea%.w, fscr.%winArea%.h, game_hWnd)
  sleep 1  ; Millisecond
  newWinState := collectWindowState(game_hWnd)

  if DEBUG
    logWindowState(newWinState, "Window State (resize)", logg)

  ; If window did not get the intended size, reposition window using its current size
  if newWinState.w != fscr.%winArea%.w || newWinState.h != fscr.%winArea%.h
  {
    if DEBUG
      logg.debug "Resize and reposition window (take 2)"

    fscr := lib_calcFullscreenArgs(newWinState,
                                   _monitor := config.monitor,
                                   _winSize := "keep",
                                   _taskbar := config.taskbar)
    if DEBUG
      logg.debug "fscr = {}".f(fscr.Inspect())

    if ! fscr.ok {
      ; Restore window mode and return
      func_fullscreen_abort()
      return false
    }

    func_updatefullscreenMode(fscr)

    WinMove(fscr.%winArea%.x, fscr.%winArea%.y, fscr.%winArea%.w, fscr.%winArea%.h, game_hWnd)

    if DEBUG
      logWindowState(newWinState, "Window State (resize 2)", logg)
  }


  ;; Modify background overlay
  if ! fullscreenMode.needsBackground
  {
    bgWindow.Hide()
  }
  else
  {
    ; Resize the click area
    bgWindow["ClickArea"].Move(0, 0, fscr.%bgArea%.w, fscr.%bgArea%.h)

    ; Resize background (also make it visible if it was hidden before)
    bgWindow.Show("x{} y{} w{} h{}".f(fscr.%bgArea%.x, fscr.%bgArea%.y, fscr.%bgArea%.w, fscr.%bgArea%.h))

    ; Cut a hole in the background for the game window to be seen
    ; NOTE: Coordinates are relative to the background area, not the desktop area
    polygonStr := Format(
      "  0-0   {1}-0   {1}-{2}   0-{2}   0-0 " .
      "{3}-{4} {5}-{4} {5}-{6} {3}-{6} {3}-{4}",
      fscr.%bgArea%.w,                                       ;{1} Background Area: width
      fscr.%bgArea%.h,                                       ;{2} Background Area: height
      fscr.%winArea%.x - fscr.%bgArea%.x,                    ;{3} Game Window: x coordinate (left)
      fscr.%winArea%.y - fscr.%bgArea%.y,                    ;{4} Game Window: y coordinate (top)
      fscr.%winArea%.x - fscr.%bgArea%.x + fscr.%winArea%.w, ;{5} Game Window: x coordinate (right)
      fscr.%winArea%.y - fscr.%bgArea%.y + fscr.%winArea%.h, ;{6} Game Window: y coordinate (bottom)
    )
    WinSetRegion(polygonStr, bgWindow.hwnd)
  }


  ;; AlwaysOnTop
  if ! fullscreenMode.needsAlwaysOnTop
  {
    ; Disable game window always on top
    if DEBUG
      logg.debug "Disable AlwaysOnTop on game window"

    WinSetAlwaysOnTop(false, game_hWnd)
    WinSetAlwaysOnTop(false, bgWindow.hWnd)
  }
  else
  {
    ; Make game window always on top
    if DEBUG
      logg.debug "Set AlwaysOnTop on game window"

    WinSetAlwaysOnTop(true, game_hWnd)
    WinSetAlwaysOnTop(true, bgWindow.hWnd)
  }


  ;; Print new window state
  if DEBUG
    logWindowState(game_hWnd, "Window state (fullscreen)", logg)


  ;; Set that fullscreen mode is active
  fullscreenMode.active := true


  ;; Return
  return true
}


;; Deactivate FULLSCREEN
deactivateFullscreen(game_hWnd, bgWindow, &windowMode, &fullscreenMode, logg)
{
  ;; Set that fullscreen mode is not active
  fullscreenMode.active := false

  ;; Hide the background overlay
  bgWindow.Hide()

  if WinExist(game_hWnd)
  {
    ;; Remove AlwaysOnTop
    WinSetAlwaysOnTop(false, game_hWnd)

    ;; Change game back to window mode
    modifyWindowState(game_hWnd, windowMode, logg)
  }

  ;; Zero all window/fullscreen props
  ; Prevent reusing old values by mistake.
  ; (maybe not needed, but it feels right)
  ; IMPORTANT: Run this after changing game back to window mode.
  for propName in windowMode.OwnProps()
    windowMode.%propName% := 0
  for propName in fullscreenMode.OwnProps()
    fullscreenMode.%propName% := 0

  ;; Return
  return true
}


;; Retrigger FULLSCREEN
; Run this if user has changed any fullscreen settings.
retriggerFullscreen()
{
  global bgGui, conLog
  global settings, game, window_mode, fullscreen_mode

  if checkFullscreenActive(game.hWnd, fullscreen_mode)
    activateFullscreen(game.hWnd, &fullscreen_mode, settings, window_mode, bgGui, conLog)
}


;; Check if game is in Fullscreen Mode
checkFullscreenActive(game_hWnd, fullscreenMode)
{
  return game_hWnd && WinExist(game_hWnd) && fullscreenMode.active
}


;; Toggle AlwaysOnTop on window focus switch
; This is needed to properly hide Windows taskbar during fullscreen.
; Function is run when any event happens in MS Windows on any window.
;
; NOTE: This is probably the most bug-prone, racey code in this codebase.
;       In MS Windows, fullscreen usually works by a window just being both
;       1) perfectly covering one monitor, and 2) is in focus (is the active
;       window). Windows will then automatically hide the taskbar.
;         This is usually not the case with a game made fullscreen by this
;       script. The game window will usually not have the right shape to
;       perfectly cover one monitor. The uncovered area is instead covered by
;       the background overlay, which is a window that is (note->) NOT in
;       focus.
;         To hide the taskbar we use this function to enable AlwaysOnTop on
;       the game when needed, since AlwaysOnTop on a window will make it render
;       above the taskbar (thereby hiding it).
;         But as mentioned, this is racey and are prone to:
;       1) showing the taskbar even while the game is in focus,
;       2) not showing other windows when switching focus to them (Alt+Tab).
;         To fix this the code has basically been hacked on, and tested, until
;       it seems to work "good enough".
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  global settings         ; Global config
  global game             ; Game Window
  global fullscreen_mode  ; Fullscreen config
  global bgGui            ; Background overlay window

  static HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Do nothing if AlwaysOnTop is not needed
  if ! fullscreen_mode.needsAlwaysOnTop
    return

  ; React on events about switching focus to another window
  if wParam = HSHELL_WINDOWACTIVATED
  || wParam = HSHELL_RUDEAPPACTIVATED {

    if lParam = game.hWnd {

      ; Game Window got focus: Set AlwaysOnTop
      if DEBUG
        conLog.debug "lParam={} wParam={}".f("game", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(true, game.hWnd)
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
        WinSetAlwaysOnTop(true, game.hWnd)
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
      ;   Focus was changed to either the Windows taskbar,
      ;   the background overlay, or something unknown.
      if DEBUG
        conLog.debug "lParam={} wParam={}".f("null", wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")

    } else {

      ; Another Window got focus: Turn off AlwaysOnTop
      if DEBUG
        conLog.debug "lParam={} wParam={}".f(lParam, wParam = HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED")
      try
        WinSetAlwaysOnTop(false, game.hWnd)
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

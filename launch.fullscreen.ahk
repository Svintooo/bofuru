#Requires AutoHotkey v2.0
#WinActivateForce
;#NoTrayIcon

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Borderless Fullscreen Launcher                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                               ;;
;; Runs `launch_string` in simulated fullscreen. ;;
;;                                               ;;
;; Usage Example:                                ;;
;;   ```                                         ;;
;;   launch_string := "some\app.exe"             ;;
;;   #include "path\to\launch.fullscreen.ahk"    ;;
;;   ```                                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;TODOS
;; - For each game, custom pictures for use as bars (left/right or up/down of game window)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; This Script Dir
script_dir := RegexReplace(A_LineFile, "[\\/][^\\/]*$", "")

;TODO: Generate pixel in code instead of loading from file
pixel := script_dir . "\resourses\pixel.ico"  ; Transparent Pixel

if not IsSet(launch_string)
{
  MsgBox("Variable launch_string not defined.", , 0x30)
  ExitApp(1)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Playground
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if False
{
  ; Code experimentation here
  ExitApp(0)
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetActiveMonitorSize()
{
  monitor := 0

  ; Coordinates - Method 1
  ;CoordMode("Mouse", "Screen")
  ;MouseGetPos(&x, &y)  ; Get x y coordinates of mouse pointer

  ; Coordinates - Method 2
  active_hwnd := WinExist("A")  ; Get the window that is currently in focus
  WinGetPos(&x, &y, , , active_hwnd)  ; Get x y coordinates of window upper left corner

  ; Find the monitor that contains the x y coordinates
  Loop MonitorGetCount()
  {
    MonitorGet(A_Index, &mon_x1, &mon_y1, &mon_x2, &mon_y2)
    if (mon_x1 <= x and x <= mon_x2 and mon_y1 <= y and y <= mon_y2)
    {
      monitor := {
          x1: mon_x1, y1: mon_y1,
          x2: mon_x2, y2: mon_y2
        }
      Break
    }
  }
  
  ; If monitor not found, use primary monitor
  if not monitor
  {
    MonitorGet(MonitorGetPrimary(), &mon_x1, &mon_y1, &mon_x2, &mon_y2)
    monitor := {
        x1: mon_x1, y1: mon_y1,
        x2: mon_x2, y2: mon_y2
      }
  }

  Return {
    x: monitor.x1,
    y: monitor.y1,
    width:  (monitor.x2 - monitor.x1),
    height: (monitor.y2 - monitor.y1),
  }
}

CalculateCorrectWindowsSizePos(app_hwnd)
{
  WinGetPos(, , &app_width, &app_height, app_hwnd)
  screen_size := GetActiveMonitorSize()

  if (screen_size.width / screen_size.height) > (app_width / app_height)
  {
    win_width := (screen_size.height / app_height) * app_width
    win_height := screen_size.height
    win_x := screen_size.x + ((screen_size.width - win_width) / 2)
    win_y := screen_size.y

    barBL_x := screen_size.x
    barBL_y := screen_size.y
    barBL_width := win_x - screen_size.x
    barBL_height := screen_size.height

    barTR_x := win_x + win_width
    barTR_y := screen_size.y
    barTR_width := screen_size.width - barBL_width - win_width
    barTR_height := screen_size.height
  }
  else
  {
    win_width := screen_size.width
    win_height := (screen_size.width / app_width) * app_height
    win_x := screen_size.x
    win_y := screen_size.y + ((screen_size.height - win_height) / 2)

    barTR_x := screen_size.x
    barTR_y := screen_size.y
    barTR_width := screen_size.width
    barTR_height := win_y - screen_size.y

    barBL_x := screen_size.x
    barBL_y := win_y + win_height
    barBL_width := screen_size.width
    barBL_height := screen_size.height - barTR_height - win_height
  }

  Return {
    app_size: {
      x: win_x,
      y: win_y,
      width: win_width,
      height: win_height,
    },
    bar_bl_size: {
      x: barBL_x,
      y: barBL_y,
      width: barBL_width,
      height: barBL_height,
    },
    bar_tr_size: {
      x: barTR_x,
      y: barTR_y,
      width: barTR_width,
      height: barTR_height,
    },
  }
}

CalculateXButtonSize(bar_width, bar_height)
{
  xb_width := 30 ;TODO: Make constant
  xb_height := 30 ;TODO: Make constant
  xb_spacing := 0 ;TODO: Make constant
  Return {
    x: bar_width - xb_width - xb_spacing,
    y: xb_spacing,
    width: xb_width,
    height: xb_height,
  }
}

ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
{
  win_sizes := CalculateCorrectWindowsSizePos(app_hwnd)

  app_size := win_sizes.app_size
  barBL_size := win_sizes.bar_bl_size
  barTR_size := win_sizes.bar_tr_size

  WinMove(app_size.x, app_size.y, app_size.width, app_size.height, app_hwnd)
  barBL.Move(barBL_size.x, barBL_size.y, barBL_size.width, barBL_size.height)
  barTR.Move(barTR_size.x, barTR_size.y, barTR_size.width, barTR_size.height)
  RepositionXButton(xBtn)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Execution START
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Run
; Start app
Run(launch_string, , , &app_pid)
if not app_hwnd := WinWait("ahk_pid " app_pid, , 5)  ; Get app window id (hwnd)
{
  if ProcessExist(app_pid)
    ProcessClose(app_pid)
  ExitApp(0)
}
;WinWaitClose(app_hwnd)
;ExitApp(0)

; Create black bars
barBL := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Bottom Left
barTR := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Top Right
barBL.BackColor := "Black"
barTR.BackColor := "Black"
barBL.Show("W0 H0")  ; Initially hidden by setting width/height to 0
barTR.Show("W0 H0")  ; Initially hidden by setting width/height to 0
barBL.OnEvent("Size", EventBarBLSize)
barTR.OnEvent("Size", EventBarTRSize)
EventBarBLSize(*)
{
  clickArea_reposition(barBL_clickArea) ;pixel
}
EventBarTRSize(*)
{
  clickArea_reposition(barTR_clickArea) ;pixel
  RepositionXButton(xBtn)
}

; Create exit button
xBtn := barTR.Add("Button", "Default", "X")
xBtn.OnEvent("Click", EventXButtonClick)
EventXButtonClick(*)
{
  WinClose(app_hwnd)
}
RepositionXButton(xBtn)
{
  xBtn.Gui.GetPos(, , &bar_width, &bar_height)
  xBtn_size := CalculateXButtonSize(bar_width, bar_height)
  xBtn.Move(xBtn_size.x, xBtn_size.y, xBtn_size.width, xBtn_size.height)
}

; Make mouse clicks on the bars return focus to the app
WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures be both clickable,
                              ; and have other elements placed on top of them.
barBL_clickArea := barBL.Add("Picture", WS_CLIPSIBLINGS, pixel)
barTR_clickArea := barTR.Add("Picture", WS_CLIPSIBLINGS, pixel)
barBL_clickArea.OnEvent("Click", event_clickArea_click)
barTR_clickArea.OnEvent("Click", event_clickArea_click)
barBL_clickArea.OnEvent("DoubleClick", event_clickArea_click)
barTR_clickArea.OnEvent("DoubleClick", event_clickArea_click)
event_clickArea_click(*)
{
  WinActivate(app_hwnd)  ; Hand focus back to the app
}
clickArea_reposition(clickArea)
{
  ; Stretch the pixel to fit the whole bar
  clickArea.Gui.GetClientPos(,,&w,&h)
  clickArea.move(0,0,w,h)
}

; Make app borderless
WinGetClientPos(, , &app_width, &app_height, app_hwnd)  ; Get width/height before removing border
DllCall("SetMenu", "uint", app_hwnd, "uint", 0)  ; Remove menu bar
win_styles := 0x00C00000  ; WS_CAPTION    (title bar)
            | 0x00800000  ; WS_BORDER     (visible border)
            | 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" win_styles, app_hwnd)  ; Remove styles
WinMove(, , app_width, app_height, app_hwnd)  ; Restore width/height

; Activate fullscreen
ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
barBL.Opt("+AlwaysOnTop")
barTR.Opt("+AlwaysOnTop")
WinSetAlwaysOnTop(True, app_hwnd)
WinMoveTop(barBL.Hwnd)
WinMoveTop(barTR.Hwnd)
WinMoveTop(app_hwnd)
WinActivate(app_hwnd)  ; Focus the app window


;; Misc Event Handlers

; Exit when App has quit
SetTimer EventWindowClose
EventWindowClose()
{
  ;if not ProcessExist(app_pid)
  if not WinExist(app_hwnd)
  {
    ExitApp(0)  ; Script Exit
  }
}

; Kill eventual Flashplayer Security popups
; Useful when running flash, and flash tries to connect to the Internet and fails
SetTimer EventFlashSecurity
EventFlashSecurity()
{
  if warn_id := WinActive("Adobe Flash Player Security")
  {
    WinClose(warn_id)
    if WinExist(app_hwnd)
      WinMoveTop(app_hwnd)
  }
}

; Tell Windows to notify us on events on any window
;https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registershellhookwindow
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(MsgNum, ShellMessage)
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  static HSHELL_MONITORCHANGED   := 0x00000010
       , HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Some window moved to another monitor
  if (wParam = HSHELL_MONITORCHANGED)
  {
    if (lParam = app_hwnd)
    {
      ; App has moved to another monitor
      ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
    }
  }

  ; Some window got focus
  else if (wParam = HSHELL_RUDEAPPACTIVATED || wParam = HSHELL_WINDOWACTIVATED)
  {
    if (lParam = app_hwnd)
    {
      ; App got focused, make app and bars AlwaysOnTop
      if WinExist(barBL.Hwnd) {
        barBL.Opt("+AlwaysOnTop")
        WinMoveTop(barBL.Hwnd)
      }
      if WinExist(barTR.Hwnd) {
        barTR.Opt("+AlwaysOnTop")
        WinMoveTop(barTR.Hwnd)
      }
      if WinExist(app_hwnd) {
        WinSetAlwaysOnTop(true, app_hwnd)
        WinMoveTop(app_hwnd)
      }
    }
    else if (lParam = 0)
    {
      ; DO NOTHING
      ; Focus was given to either:
      ;   - one of the black bars
      ;   - the windows taskbar
      ;   - something unknown
    }
    else
    {
      ; Something other than the app got focus
      ;  Remove AlwaysOnTop so the focused window can be seen
      if WinExist(barBL.Hwnd)
        barBL.Opt("-AlwaysOnTop")
      if WinExist(barTR.Hwnd)
        barTR.Opt("-AlwaysOnTop")
      if WinExist(app_hwnd)
        WinSetAlwaysOnTop(false, app_hwnd)
      if WinExist(lParam)
        WinMoveTop(lParam)  ; Make sure the newly focused window is visible
    }
  }
}

#Requires AutoHotkey v2.0
;#NoTrayIcon
;; Flash Launcher
;;
;; Runs the *.swf file in the same folder as the script,
;; and runs it in fullscreen.
;;
;; Usage1:
;;   Place a *.swf and this script in the same folder.
;; Usage2:
;;   Place a *.swf and another ahk-script in the same folder.
;;   The other script includes this script like this:
;;   ```
;;   flashplayer := "path\to\flashplayer.exe"
;;   #include "path\to\this_script.ahk"
;;   ```


;; Configuration
if not IsSet(flashplayer)
  flashplayer := "./flashplayer_32_sa.exe"


;; Helper Functions
GetWindowInternalSize(hwnd)
{
  WinGetClientPos(, , &win_width, &win_height, hwnd)
  Return {
    width:  win_width,
    height: win_height,
  }
}

GetActiveMonitorRectangle()
{
  ;CoordMode("Mouse", "Screen")
  ;MouseGetPos(&x, &y)
  active_hwnd := WinExist("A")
  WinGetPos(&x, &y, , , active_hwnd)
  Loop MonitorGetCount()
  {
    MonitorGet(A_Index, &mon_x0, &mon_y0, &mon_x1, &mon_y1)
    if (mon_x0 <= x and x <= mon_x1 and mon_y0 <= y and y <= mon_y1)
    {
      Return {
        x: mon_x0,
        y: mon_y0,
        width:  (mon_x1 - mon_x0),
        height: (mon_y1 - mon_y0),
      }
    }
  }
  throw TargetError("Could not find the active computer screen.")
}

WindowMakeMaxSizeAndCenter(win_id, win_size, screen_size)
{
  if (screen_size.width/screen_size.height) > (win_size.width/win_size.height)
  {
    new_width := (screen_size.height / win_size.height) * win_size.width
    new_height := screen_size.height
    new_x := screen_size.x + ((screen_size.width - new_width) / 2)
    new_y := screen_size.y
  }
  else
  {
    new_width := screen_size.width
    new_height := (screen_size.width / win_size.width) * win_size.height
    new_x := screen_size.x
    new_y := screen_size.y + ((screen_size.height - new_height) / 2)
  }

  WinMove(new_x, new_y, new_width, new_height, win_id)
}


;; Find the first *.swf file
Loop Files "*.swf", "F"
{
  game := A_LoopFilePath
  break
}
if not IsSet(game)
{
  MsgBox("*.swf file not found.", , 0x30)
  Exit(1)
}


;; Run
screen_size := GetActiveMonitorRectangle()
;MsgBox(String(screen_size.width)) ;DEBUG DELETEME

; Create Background
background := Gui("-Caption +AlwaysOnTop")
;background := Gui("-Caption")
;background := Gui("+Resize")
background.BackColor := "Black"
;background.Show("Maximize")
; Arbitary width height so background is not super small when not maximized
background.Show("W200 H200 Maximize")
; Add [X] button
xb_sizepos := CalculateXButtonSizePos()
xb_options := ""
xb_options .= " Default"
xb_options .= " X" String(xb_sizepos.x)
xb_options .= " Y" String(xb_sizepos.y)
xb_options .= " W" String(xb_sizepos.width)
xb_options .= " H" String(xb_sizepos.height)
x_button := background.Add("Button", xb_options, "X")
background.OnEvent("Size", EventBgSize, -1)  ;-1: Prioritize event before other events
x_button.OnEvent("Click", EventXButtonClick)

EventXButtonClick(*)
{
  WinClose(win_id)
}

EventBgSize(GuiObj, MinMax, Width, Height)
{
  if MinMax = -1  ; Ignore if minimized
    Return
  xb_sizepos := CalculateXButtonSizePos()
  x_button.Move(xb_sizepos.x, xb_sizepos.y, xb_sizepos.width, xb_sizepos.height)
}

CalculateXButtonSizePos()
{
  background.GetClientPos(, , &bg_width, )
  xb_width_height := 30
  xb_spacing := 10
  Return {
    x: bg_width - xb_width_height - xb_spacing,
    y: xb_spacing,
    width: xb_width_height,
    height: xb_width_height,
  }
}

; Start window
Run(flashplayer ' ' game, , , &process_id)
win_id := WinWait("ahk_pid " process_id, , 5)
if win_id = 0
  ExitApp(0)

; Modify Window
original_win_size := GetWindowInternalSize(win_id)
DllCall("SetMenu", "uint", win_id, "uint", 0)  ; Remove menu bar
win_styles := 0
win_styles |= 0x00C00000  ; WS_CAPTION    (title bar)
win_styles |= 0x00800000  ; WS_BORDER     (visible border)
win_styles |= 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" String(win_styles), win_id)  ; Remove styles
WindowMakeMaxSizeAndCenter(win_id, original_win_size, screen_size)
WinSetAlwaysOnTop(True, win_id)

; Focus Window
WinMoveTop(win_id)
WinActivate(win_id)


;; Event Handlers
; Get rid of eventual security warning windows
SetTimer EventFlashSecurity
EventFlashSecurity()
{
  warn_id := WinActive("Adobe Flash Player Security")
  if warn_id != 0
  {
    WinClose(warn_id)
    if WinExist(win_id)
      WinMoveTop(win_id)
  }
}

; Exit Script if Window is closed
SetTimer EventWindowClose
EventWindowClose()
{
  ;if not ProcessExist(process_id)
  if not WinExist(win_id)
  {
    background.Destroy()
    ExitApp(0)  ; Script Exit
  }
}

; Hand over all other events to Microsoft Windows
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(MsgNum, ShellMessage)
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  static HSHELL_WINDOWACTIVATED := 0x04
       , HSHELL_HIGHBIT := 0x8000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Magic
  if not (wParam = HSHELL_RUDEAPPACTIVATED || wParam = HSHELL_WINDOWACTIVATED)
    Return

  ; Handle Events
  if (lParam = background.Hwnd)
  {
    ; Background should never have focus.
    ; If background gets focus, hand focus back to window
    if WinExist(win_id)
      WinActivate(win_id)
  }
  else if (lParam = win_id)
  {
    ; Hide Windows Taskbar
    background.Opt("+AlwaysOnTop")
    WinSetAlwaysOnTop(True, win_id)
  }
  else
  {
    ;MsgBox(String(lParam)) ;DEBUG DELETEME
    ; Make sure other apps can be shown on top of window IF window is not in focus
    background.Opt("-AlwaysOnTop")
    if WinExist(win_id)
      WinSetAlwaysOnTop(False, win_id)
    if lParam
      WinMoveTop(lParam)  ; Make sure the focused app is visible
  }

  ;MsgBox( (wParam == HSHELL_WINDOWACTIVATED ? "HSHELL_WINDOWACTIVATED" : "HSHELL_RUDEAPPACTIVATED") " message received!`nWindow activated: " title "`nHWND: " String(lParam) "`nmsg: " msg "`nscript_hwnd: " String(script_hwnd)) ;DEBUG
}

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

;;TODOS
;; - For each game, custom pictures for use as bars (left/right or up/down of game window)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Set Flash player
if not IsSet(flashplayer)
  flashplayer := "./flashplayer_32_sa.exe"

;; Set Flash file
; Take the first *.swf file in current working directory
Loop Files "*.swf", "F"
{
  game := A_LoopFilePath
  break
}
if not IsSet(game)
{
  MsgBox("*.swf file not found.", , 0x30)
  ExitApp(1)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if true
{
  RGB_to_BGR(int)
  {
    if (int is String) && IsXDigit(int) && (SubStr(int, 0, 2) != "0x")
      int := "0x" . int

    int := Integer(int)  ; Crash if int is invalid

    static bytes := 8
    Return (
        ( (int & 0xff0000) >> 2*bytes ) |  ; RGB => ..R
        ( (int & 0x00ff00)            ) |  ; RGB => .G.
        ( (int & 0x0000ff) << 2*bytes )    ; RGB => B..
      )
}

  WindowProcActions := Map()
  HijackWindowProc(hwnd)
  {
    ; Init
    static GWL_WNDPROC := -4
    static SetWindowLong := (A_PtrSize = 8) ? "SetWindowLongPtr"  ; 64-bit
                                            : "SetWindowLong"     ; 32-bit
    static WindowProcNew := CallbackCreate(WindowProc)

    WindowProcOld := DllCall(SetWindowLong, "Ptr", hwnd,
                                            "Int", GWL_WNDPROC,
                                            "Ptr", WindowProcNew,
                                            "Ptr")

    WindowProcActions[hwnd] := {WindowProc: WindowProcOld}
  }

  WindowProc(hwnd, uMsg, wParam, lParam)
  {
    Critical  ; Prevents the current thread from being interrupted by other threads
  
    ;TODO

    return DllCall("CallWindowProc", "Ptr", WindowProcActions[win.Hwnd].WindowProc, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
  }




  WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures both be clickable,
                                ; and have other elements placed in front of it.
  black_pixel := RegExReplace(flashplayer, "[\\/][^\\/]*$", "") . "\pixel.bmp"
                                ;TODO: Generate in code instead of using a file.

  win := Gui("+Resize")
  win.BackColor := "Red"
  win.OnEvent("Size", event_win_size)
  event_win_size(*)
  {
    btnx_reposition(btnX)
    pic_reposition(pic)
  }
  btnX := win.Add("Button", "Default", "X")
  btnX_reposition(btn)
  {
    win.GetClientPos(,,&w,&h)
    btn.GetPos(,,&bw,&bh)
    btn.move(w-bw,0)
  }
  pic := win.Add("Picture", WS_CLIPSIBLINGS, black_pixel)
  pic_reposition(pic)
  {
    win.GetClientPos(,,&w,&h)
    pic.move(0,0,w,h)
  }

  ;win_bgbrush := DllCall("CreateSolidBrush", "UInt", RGB_to_BGR(win.BackColor))
  SetWindowLong := (A_PtrSize = 8) ? "SetWindowLongPtr"  ; 64-bit
                                   : "SetWindowLong"     ; 32-bit
  WindowProcNew := CallbackCreate(WindowProc_)
  WindowProcOld := DllCall(SetWindowLong, "Ptr", win.Hwnd, "Int", GWL_WNDPROC := -4, "Ptr", WindowProcNew, "Ptr")
  
  WindowProc_(hwnd, uMsg, wParam, lParam)
  {
    Critical  ; Prevents the current thread from being interrupted by other threads
  ;  
  ;  if IsSet(btnX)  ; Prevent error on exit: "This variable has not been assigned a value."
  ;  && lParam = btnX.Hwnd
  ;  && (0x0132 <= uMsg && uMsg <= 0x0138)  ; WM_CTLCOLOR(MSGBOX|EDIT|LISTBOX|BTN|DLG|SCROLLBAR|STATIC).
  ;  {
  ;    ;DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", win_textcolor)
  ;    DllCall("SetBkColor", "Ptr", wParam, "UInt", RGB_to_BGR(win.BackColor))
  ;    return win_bgbrush  ; Return the HBRUSH to notify the OS that we altered the HDC.
  ;  }
  ;  
    return DllCall("CallWindowProc", "Ptr", WindowProcOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
  }

  win.Show()
  pic_reposition(pic)

  WinWaitClose(win.Hwnd)
  ExitApp(0)
}
;if false
;{
;  ;DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB:=0xff000000, "UPtr*", &pBrush)
;  ;ExitApp(0)
;
;  ; Let picture exist underneath buttons and still receive click events
;  WS_CLIPSIBLINGS := 0x4000000
;  black_pixel := RegExReplace(flashplayer, "[\\/][^\\/]*$", "") . "\pixel.bmp"
;  ;
;  win := Gui("+Resize")
;  win.BackColor := "Black"
;  btnX := win.Add("Button", "Default", "X")
;  pic := win.Add("Picture", WS_CLIPSIBLINGS, black_pixel)
;  ;
;  ;win.OnEvent("Size", event_win_size)
;  ;btnX.OnEvent("Click", event_btnx_click)
;  ;pic.OnEvent("Click", event_pic_click)
;  ;
;  event_win_size(*)
;  {
;    btnx_reposition()
;    pic_reposition()
;  }
;  event_btnx_click(*)
;  {
;    ;ExitApp(0)
;    win.Destroy()
;  }
;  event_pic_click(*)
;  {
;    MsgBox("Hello World!")
;  }
;  ;
;  btnx_reposition()
;  {
;    win.GetClientPos(,,&w,&h)
;    btnx.GetPos(,,&bw,&bh)
;    btnx.move(w-bw,0)
;  }
;  pic_reposition()
;  {
;    win.GetClientPos(,,&w,&h)
;    pic.move(0,0,w,h)
;  }
;  ;
;  win.Show("W200 H200")
;  pic_reposition()
;  ;
;  WinWait(win.hwnd)
;  WinWaitClose(win.hwnd)
;  ;MsgBox("Right before exit.")
;  ExitApp(0)
;}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetActiveMonitorSize()
{
  ; Coordinates - Method 1
  ;CoordMode("Mouse", "Screen")
  ;MouseGetPos(&x, &y)  ; Get x y coordinates of mouse pointer

  ; Coordinates - Method 2
  active_hwnd := WinExist("A")  ; Get the window that is currently in focus
  WinGetPos(&x, &y, , , active_hwnd)  ; Get x y coordinates of window upper left corner

  ; Find the monitor that contains the x y coordinates
  Loop MonitorGetCount()
  {
    MonitorGet(A_Index, &mon_x0, &mon_y0, &mon_x1, &mon_y1)
    if (mon_x0 <= x and x <= mon_x1 and mon_y0 <= y and y <= mon_y1)
    {
      Return {
        x: mon_x0,
        y: mon_y0,
        width:  (mon_x1 - mon_x0), ;TODO: Should we not add `+ 1` here?
        height: (mon_y1 - mon_y0), ;TODO: Should we not add `+ 1` here?
      }
    }
  }
  ; Fatal Error: This should never happen
  throw TargetError("Could not find the active computer screen.")
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

RepositionXButton(xBtn)
{
  xBtn.Gui.GetPos(, , &bar_width, &bar_height)
  xBtn_size := CalculateXButtonSize(bar_width, bar_height)
  xBtn.Move(xBtn_size.x, xBtn_size.y, xBtn_size.width, xBtn_size.height)
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

;; Run (borderless fullscreen with black bars)
; Start app
Run(Format("{1} {2}", flashplayer, game), , , &app_pid)
app_hwnd := WinWait(Format("ahk_pid {1}", app_pid), , 5)  ; Get app window id (hwnd)
if app_hwnd = 0
{
  if ProcessExist(app_pid)
    ProcessClose(app_pid)
  ExitApp(0)
}

; Create black bars
barBL := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Bottom Left
barTR := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Top Right
barBL.BackColor := "Black"
barTR.BackColor := "Black"
barBL.Show("W0 H0")
barTR.Show("W0 H0")

; Create exit button
xBtn := barTR.Add("Button", "Default", "X")
xBtn.OnEvent("Click", EventXButtonClick)
barTR.OnEvent("Size", EventBarTRSize)

EventXButtonClick(*)
{
  WinClose(app_hwnd)
}

EventBarTRSize(*)
{
  RepositionXButton(xBtn)
}

; Make app borderless
WinGetClientPos(, , &app_client_width, &app_client_height, app_hwnd)
DllCall("SetMenu", "uint", app_hwnd, "uint", 0)  ; Remove menu bar
win_styles := 0
win_styles |= 0x00C00000  ; WS_CAPTION    (title bar)
win_styles |= 0x00800000  ; WS_BORDER     (visible border)
win_styles |= 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle(Format("-{1}", win_styles), app_hwnd)  ; Remove styles
WinMove(, , app_client_width, app_client_height, app_hwnd)  ; Restore app client area size

; Set position and size of app and bars
ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)

; Show
barBL.Opt("+AlwaysOnTop")
barTR.Opt("+AlwaysOnTop")
WinSetAlwaysOnTop(True, app_hwnd)
WinMoveTop(barBL.Hwnd)
WinMoveTop(barTR.Hwnd)
WinMoveTop(app_hwnd)
WinActivate(app_hwnd)  ; Focus the app window


;; Event Handlers
; Get rid of eventual security warning windows
SetTimer EventFlashSecurity
EventFlashSecurity()
{
  warn_id := WinActive("Adobe Flash Player Security")
  if warn_id != 0
  {
    WinClose(warn_id)
    if WinExist(app_hwnd)
      WinMoveTop(app_hwnd)
  }
}

; Exit Script if Window is closed
SetTimer EventWindowClose
EventWindowClose()
{
  ;if not ProcessExist(app_pid)
  if not WinExist(app_hwnd)
  {
    ExitApp(0)  ; Script Exit
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
      ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
    }
  }

  ; Some window got focus
  else if (wParam = HSHELL_RUDEAPPACTIVATED || wParam = HSHELL_WINDOWACTIVATED)
  {
    if (lParam = app_hwnd)
    {
      ; App got focused, make app and bars AlwaysOnTop again
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
    }
    else
    {
      ;MsgBox(Format("lParam: {1}`n`napp.hwnd: {2}`nbarBL.hwnd: {3}`nbarTR.hwnd: {4}",lParam,app_hwnd,barBL.Hwnd,barTR.Hwnd), , 0x1000)

      ; If user changed focus to something other than the app, remove AlwaysOnTop
      ;   Otherwise the focused window may be hidden behind the app and bars
      if WinExist(barBL.Hwnd)
        barBL.Opt("-AlwaysOnTop")
      if WinExist(barTR.Hwnd)
        barTR.Opt("-AlwaysOnTop")
      if WinExist(app_hwnd)
        WinSetAlwaysOnTop(false, app_hwnd)
      if WinExist(lParam)
        WinMoveTop(lParam)  ; Make sure the newly focused app is visible
    }
  }
}

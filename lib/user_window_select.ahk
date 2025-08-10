lib_userWindowSelect(timeout := 0) {
  ;; Get desktop bounds
  SM_XVIRTUALSCREEN  := 76  ; x coord
  SM_YVIRTUALSCREEN  := 77  ; y coord
  SM_CXVIRTUALSCREEN := 78  ; width
  SM_CYVIRTUALSCREEN := 79  ; height
  x := SysGet(SM_XVIRTUALSCREEN)
  y := SysGet(SM_YVIRTUALSCREEN)
  w := SysGet(SM_CXVIRTUALSCREEN)
  h := SysGet(SM_CYVIRTUALSCREEN)

  ;; Create desktop overlay
  mygui := Gui("+AlwaysOnTop +ToolWindow -Caption")
  ctl := mygui.Add("Text", "w" w " h" h)  ; Create empty control to handle clicks

  ;; Create overlay exit actions
  exit_reason := "(none)"
  ctl.OnEvent(  "Click",  (*) => (exit_reason := "click" ) && mygui.Destroy())
  mygui.OnEvent("Escape", (*) => (exit_reason := "escape") && mygui.Destroy())

  ;; Enable overlay and make it transparent
  mygui.Show("x" x " y" y " w" w " h" h)
  WinSetTransparent(35, "ahk_id " mygui.Hwnd)

  ;; Fetch crosshair cursor
  hCross := DllCall("User32.dll\LoadCursor"
                   , "Ptr" , 0
                   , "UInt", 32515
                   , "Ptr")

  ;; Change overlay cursor to a crosshair
  ; Call correct function depending if running 32-bit or 64-bit
  DllCall((A_PtrSize = 8 ? "User32.dll\SetClassLongPtr" : "User32.dll\SetClassLong")
         , "Ptr", ctl.Hwnd
         , "Int", -12  ; GCLP_HCURSOR
         , "Ptr", hCross)

  ;; Create function that waits for the overlay to disappear
  if timeout {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd, , timeout)
  } else {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd)
  }

  ;; Wait until overlay has disappeared
  if ! winWaitFunc() {
    WinClose("ahk_id " mygui.Hwnd)
    exit_reason := "timeout"
  }

  ;; Return window that mouse points at
  if exit_reason = "timeout" {
    return { ok: false, reason: "timeout" }
  } else if exit_reason = "escape" {
    return { ok: false, reason: "user cancel" }
  } else if exit_reason = "click" {
    MouseGetPos(, , &hWnd)
    pid       := WinGetPID("ahk_id " hWnd)
    className := WinGetClass("ahk_id " hWnd)
    return { ok: true, hWnd: hWnd, pid: pid, className: className}
  }
}

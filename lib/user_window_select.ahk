userWindowSelect(timeout := 0) {
  ; Get desktop bounds
  SM_XVIRTUALSCREEN  := 76  ; x coord
  SM_YVIRTUALSCREEN  := 77  ; y coord
  SM_CXVIRTUALSCREEN := 78  ; width
  SM_CYVIRTUALSCREEN := 79  ; height
  x := SysGet(SM_XVIRTUALSCREEN)
  y := SysGet(SM_YVIRTUALSCREEN)
  w := SysGet(SM_CXVIRTUALSCREEN)
  h := SysGet(SM_CYVIRTUALSCREEN)

  ; Create transparent desktop overlay
  mygui := Gui("+AlwaysOnTop +ToolWindow -Caption")
  ctl := mygui.Add("Text", "w" w " h" h)  ; Empty control to handle clicks

  ; Overlay exit actions
  exit_reason := "(none)"
  ctl.OnEvent(  "Click",  (*) => (exit_reason := "click" ) && mygui.Destroy())
  mygui.OnEvent("Escape", (*) => (exit_reason := "escape") && mygui.Destroy())

  ; Enable overlay
  mygui.Show("x" x " y" y " w" w " h" h)
  WinSetTransparent(35, "ahk_id " mygui.Hwnd)

  ; Change to a crosshair cursor
  hCross := DllCall("LoadCursor", "Ptr" , 0
                                , "UInt", 32515
                                , "Ptr")
  DllCall("SetClassLongPtrW", "Ptr", ctl.Hwnd
                            , "Int", -12  ; GCLP_HCURSOR
                            , "Ptr", hCross)

  ; Create function that waits for the overlay to disappear
  if timeout {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd, , timeout)
  } else {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd)
  }

  ; Wait until overlay has disappeared
  if ! winWaitFunc() {
    WinClose("ahk_id " mygui.Hwnd)
    exit_reason := "timeout"
  }

  ; Return window that mouse points at
  if exit_reason = "timeout" {
    return { ok: false }
  } else if exit_reason = "escape" {
    return { ok: false }
  } else if exit_reason = "click" {
    MouseGetPos(, , &hWnd)
    return { ok: true, hWnd: hWnd}
  }
}

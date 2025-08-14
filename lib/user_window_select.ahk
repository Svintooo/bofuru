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
  ctl := mygui.Add("Text", "w{} h{}".f(w, h))  ; Create empty control to handle clicks

  ;; Enable overlay and make it transparent
  mygui.Show("x{} y{} w{} h{}".f(x, y, w, h))
  WinSetTransparent(35, "ahk_id " mygui.Hwnd)

  ;; Change cursor - Preparations
  GCLP_HCURSOR := -12
  GetClassCursor := "User32.dll\{}".f(A_PtrSize = 8 ? "GetClassLongPtr" : "GetClassLong")
  SetClassCursor := "User32.dll\{}".f(A_PtrSize = 8 ? "SetClassLongPtr" : "SetClassLong")
  origCursor := DllCall(GetClassCursor
                       , "Ptr", ctl.Hwnd
                       , "Int", GCLP_HCURSOR
                       , "Ptr")
  newCursor := DllCall("User32.dll\LoadCursor"
                       , "Ptr" , 0
                       , "UInt", 32515  ; Crosshair
                       , "Ptr")

  ;; Change cursor - Execute
  DllCall(SetClassCursor
         , "Ptr", ctl.Hwnd
         , "Int", GCLP_HCURSOR
         , "Ptr", newCursor)

  ;; Change cursor - Restore
  ; Otherwise other windows we create will have their default cursor changed
  restoreCursorFunc := () => DllCall(SetClassCursor
                                    , "Ptr", ctl.Hwnd
                                    , "Int", GCLP_HCURSOR
                                    , "Ptr", origCursor)

  ;; Create overlay exit actions
  exitReason := "(none)"
  ctl.OnEvent(  "Click",  (*) => (exitReason := "click" , restoreCursorFunc(), mygui.Destroy()))
  mygui.OnEvent("Escape", (*) => (exitReason := "escape", restoreCursorFunc(), mygui.Destroy()))

  ;; Create function that waits for the overlay to disappear
  if timeout {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd, , timeout)
  } else {
    winWaitFunc := () => WinWaitClose("ahk_id " mygui.Hwnd)
  }

  ;; Wait until overlay has disappeared
  if ! winWaitFunc() {
    WinClose("ahk_id " mygui.Hwnd)
    exitReason := "timeout"
  }

  ;; Return window that mouse points at
  if exitReason = "timeout" {
    return { ok: false, reason: "timeout" }
  } else if exitReason = "escape" {
    return { ok: false, reason: "user cancel" }
  } else if exitReason = "click" {
    MouseGetPos(, , &hWnd)
    pid       := WinGetPID("ahk_id " hWnd)
    className := WinGetClass("ahk_id " hWnd)
    return { ok: true, hWnd: hWnd, pid: pid, className: className}
  }
}

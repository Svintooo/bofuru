lib_userWindowSelect(timeout := unset)
{
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

  ;; Change overlay mouse cursor
  newCursor := DllCall("User32.dll\LoadCursor"
                       , "Ptr" , 0
                       , "UInt", 32515  ; Crosshair cursor
                       , "Ptr")
  origCursor := lib_changeCursor(ctl.Hwnd, newCursor)

  ;; Restore overlay mouse cursor
  ; Otherwise other windows we create will have their default cursor changed for some reason
  restoreCursorFunc := () => lib_changeCursor(ctl.Hwnd, origCursor)

  ;; Create overlay exit function
  exitReason := "(none)"
  overlayCloseFunc := (reason) => (exitReason := reason, restoreCursorFunc(), mygui.Destroy())

  ;; Create overlay exit actions
  ctl.OnEvent(  "Click",  (*) => overlayCloseFunc("click") )
  mygui.OnEvent("Escape", (*) => overlayCloseFunc("escape"))

  ;; Enable overlay and make it transparent
  mygui.Show("x{} y{} w{} h{}".f(x, y, w, h))
  WinSetTransparent(35, "ahk_id " mygui.Hwnd)

  ;; Wait until overlay has disappeared
  if ! WinWaitClose(mygui.Hwnd, , IsSet(timeout) ? timeout : unset) {
    overlayCloseFunc("timeout")
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
  } else {
    return { ok: false, reason: "FATAL: THIS SHOULD NEVER HAPPEN" }
  }
}


lib_changeCursor(hWnd, newCursor)
{
  ;; Constants
  static GCLP_HCURSOR   := -12
  static GetClassCursor := "User32.dll\{}".f(A_PtrSize = 8 ? "GetClassLongPtr" : "GetClassLong")
  static SetClassCursor := "User32.dll\{}".f(A_PtrSize = 8 ? "SetClassLongPtr" : "SetClassLong")

  ;; Old cursor
  oldCursor := DllCall(GetClassCursor
                      , "Ptr", hWnd
                      , "Int", GCLP_HCURSOR
                      , "Ptr")

  ;; Change cursor
  DllCall(SetClassCursor
         , "Ptr", hWnd
         , "Int", GCLP_HCURSOR
         , "Ptr", newCursor)

  ;; Return old cursor
  return oldCursor
}

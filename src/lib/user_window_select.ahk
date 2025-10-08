#Include %A_ScriptDir%\lib\change_cursor.ahk

lib_userWindowSelect(timeout?)
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

  ;; Prepare user input variable
  userInput := ""

  ;; Create overlay exit actions
  ctl.OnEvent("Click",  (*) => (userInput := "Click", ih.Stop()) )
  ih := InputHook("M", "{Esc}")

  ;; Show overlay, Wait for user input
  mygui.Show("x{} y{} w{} h{}".f(x, y, w, h))
  WinSetTransparent(35, "ahk_id " mygui.Hwnd)
  ih.Start()
  ih.Wait(timeout?)

  ;; Stop inputhook
  ih.Stop()

  ;; Fetch the user input
  if !userInput {
    if ih.EndReason = "EndKey" {
      userInput := ih.EndKey
    } else if ih.EndReason = "Stopped" {
      userInput := "Timeout"
    }
  }

  ;; Restore overlay mouse cursor
  ; Otherwise other windows we create will have their default cursor changed for some reason
  lib_changeCursor(ctl.Hwnd, origCursor)

  ;; Destroy desktop overlay
  mygui.Destroy()

  ;; Return window that mouse points at
  if userInput = "Timeout" {
    return { ok: false, reason: "timeout" }
  } else if userInput = "Escape" {
    return { ok: false, reason: "user cancel" }
  } else if userInput = "Click" {
    MouseGetPos(, , &hWnd)
    pid       := WinGetPID("ahk_id " hWnd)
    className := WinGetClass("ahk_id " hWnd)
    return { ok: true, hWnd: hWnd, pid: pid, className: className}
  } else {
    return { ok: false, reason: "FATAL: THIS SHOULD NEVER HAPPEN" }
  }
}

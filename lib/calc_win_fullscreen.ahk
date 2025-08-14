;; Calculate coordinate, size, and screen area to make window fullscreen
lib_calcFullscreenArgs(hWnd, selectedMonitorNumber := 0, winSize := "fit", taskbar := "hide")
{
  ;; Set default return values
  ok     := true
  reason := ""


  ;; Get Window Position
  WinGetPos(&winX, &winY, &winW, &winH, "ahk_id" hWnd)
  win := { x:winX, y:winY, w:winW, h:winH }
  winX := winY := winW := WinH := unset


  ;; Get Monitor Area
  monitorCount := MonitorGetCount()
  monitorNumber  := false

  if selectedMonitorNumber && selectedMonitorNumber <= monitorCount {
    monitorNumber := selectedMonitorNumber
    MonitorGet(monitorNumber, &monX1, &monY1, &monX2, &monY2)
  }

  if !monitorNumber {
    Loop monitorCount {
      MonitorGet(A_Index, &monX1, &monY1, &monX2, &monY2)

      if (monX1 <= win.x && win.x <= monX2 && monY1 <= win.y && win.y <= monY2)
      || (monX2 <= win.x && win.x <= monX1 && monY2 <= win.y && win.y <= monY1) {
        monitorNumber := A_Index
        break
      }
    }
  }

  if !monitorNumber {
    monitorNumber := MonitorGetPrimary()
    MonitorGet(monitorNumber, &monX1, &monY1, &monX2, &monY2)
  }

  ;NOTE: mon = monitor area
  ;      scr = screen area
  mon := {
    x: Min(monX1,monX2),
    y: Min(monY1,monY2),
    w: Abs(monX1-monX2),
    h: Abs(monY1-monY2)
  }
  scr := mon.Clone()
  monX1 := monX2 := monY1 := monY2 := unset


  ;; (optional) Exclude taskbar area from monitor area
  ; Can be used in case there is a problem overlaying the Window taskbar
  switch taskbar {
  case "hide":
    ; DO NOTHING
  case "show":
    for trayHwnd in WinGetList("ahk_class ^(Shell_TrayWnd|Shell_SecondaryTrayWnd)$") {
      WinGetPos(&trayX, &trayY, &trayW, &trayH, "ahk_id" trayHwnd)
      tray := { x:trayX, y:trayY, w:trayW, h:trayH }
      trayX := trayY := trayW := trayH := unset

      if (scr.x <= tray.x && tray.x <= scr.x+scr.w && scr.y <= tray.y && tray.y <= scr.y+scr.h) {
        if tray.w = scr.w {
          ; Taskbar is placed at the top or bottom
          scr.y += tray.h
          scr.h -= tray.h * 2
          win.noTaskbar := "ok"
        } else if tray.h = scr.h {
          ; Taskbar is placed at the left or right side
          scr.x += tray.w
          scr.w -= tray.w * 2
          win.noTaskbar := "ok"
        } else {
          ; THIS SHOULD NEVER HAPPEN
          win.noTaskbar := "error"
        }
      }
    }
  default:
    ; ERROR
    ok := false
    reason := "Invalid arg: taskbar={}".f(taskbar.Inspect())
  }


  ;; Calculate new window position and size
  switch winSize {
  case "fit":
    ; Maximum enlargement while keeping window aspect ratio
    if (scr.w / scr.h) > (win.w / win.h) {
      win.w := Round((scr.h / win.h) * win.w)
      win.h := scr.h
      win.x := Round(scr.x + (Abs(scr.w - win.w) / 2))
      win.y := scr.y
    } else {
      win.w := scr.w
      win.h := Round((scr.w / win.w) * win.h)
      win.x := scr.x
      win.y := Round(scr.y + (Abs(scr.h - win.h) / 2))
    }
  case "pixel-perfect":
    ; Only enlarge window by exakt pixels
    mult := Min(scr.w // win.w, scr.h // win.h)

    win.w *= mult
    win.h *= mult
    win.x := scr.x
    win.y := scr.y

    if win.w != scr.w
      win.x += (( scr.w - win.w ) // 2)
    if win.h != scr.h
      win.y += (( scr.h - win.h ) // 2)
  default:
    ; ERROR
    ok := false
    reason := "Invalid arg: winSize={}".f(winSize.Inspect())
  }


  ;; Return new window size and position
  return { ok: ok, reason: reason, window: win, screen: scr }
}

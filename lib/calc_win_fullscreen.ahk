;; Calculate new window size and position to make it fullscreen
lib_calcWinFullscreen(hWnd, selectedMonitorNumber := 0, noTaskbar := false, dotByDot := false)
{
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

  mon := {
    x: Min(monX1,monX2),
    y: Min(monY1,monY2),
    w: Abs(monX1-monX2),
    h: Abs(monY1-monY2)
  }

  monX1 := monX2 := monY1 := monY2 := unset


  ;; (optional) Exclude taskbar area from monitor area
  ; Can be used in case there is a problem overlaying the Window taskbar
  if noTaskbar {
    for trayHwnd in WinGetList("ahk_class ^(Shell_TrayWnd|Shell_SecondaryTrayWnd)$") {
      WinGetPos(&trayX, &trayY, &trayW, &trayH, "ahk_id" trayHwnd)
      tray := { x:trayX, y:trayY, w:trayW, h:trayH }
      trayX := trayY := trayW := trayH := unset

      if (mon.x <= tray.x && tray.x <= mon.x+mon.w && mon.y <= tray.y && tray.y <= mon.y+mon.h) {
        if tray.w = mon.w {
          ; Taskbar is placed at the top or bottom
          mon.y += tray.h
          mon.h -= tray.h * 2
          win.noTaskbar := "ok"
        } else if tray.h = mon.h {
          ; Taskbar is placed at the left or right side
          mon.x += tray.w
          mon.w -= tray.w * 2
          win.noTaskbar := "ok"
        } else {
          ; THIS SHOULD NEVER HAPPEN
          win.noTaskbar := "error"
        }
      }
    }
  }


  ;; Calculate new window position and size
  if dotByDot {
    ; Only enlarge window by exakt pixels
    mult := Min(mon.w // win.w, mon.h // win.h)

    win.w *= mult
    win.h *= mult
    win.x := mon.x
    win.y := mon.y

    if win.w != mon.w
      win.x += (( mon.w - win.w ) // 2)
    if win.h != mon.h
      win.y += (( mon.h - win.h ) // 2)
  } else {
    ; Maximum enlargement
    if (mon.w / mon.h) > (win.w / win.h) {
      win.w := Round((mon.h / win.h) * win.w)
      win.h := mon.h
      win.x := Round(mon.x + (Abs(mon.w - win.w) / 2))
      win.y := mon.y
    } else {
      win.w := mon.w
      win.h := Round((mon.w / win.w) * win.h)
      win.x := mon.x
      win.y := Round(mon.y + (Abs(mon.h - win.h) / 2))
    }
  }


  ;; Return new window size and position
  return { window: win, monitor: mon }
}

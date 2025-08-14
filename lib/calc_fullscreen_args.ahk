;; Calculate coordinate, size, and screen area to make window fullscreen
;
; winSize    original         Keep original window size (no enlargement).
;            fit              Enlarge window as much as possible while keeping its aspect ratio.
;            stretch          Stretch window to fit the whole screen area.
;            pixel-perfect    Enlarge window by exact multiple.
;
; taskbar    show             Show the MS Windows taskbar.
;            hide             Hide the MS Windows taskbar.
lib_calcFullscreenArgs(hWnd, selectedMonitorNumber := 0, winSize := "fit", taskbar := "hide")
{
  ;; Set default return values
  ok                     := true  ; No errors
  reason                 := ""    ; No error reason message
  needsBackgroundOverlay := true  ; Usually needed for monitor area not covered by window
  needsAlwaysOnTop       := true  ; Usually needed to hide MS Windows taskbar


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
    ; AlwaysOnTop not needed since taskbar will be shown
    needsAlwaysOnTop := false

    ; Subtract the taskbar area from the screen area
    for trayHwnd in WinGetList("ahk_class ^(Shell_TrayWnd|Shell_SecondaryTrayWnd)$") {
      WinGetPos(&trayX, &trayY, &trayW, &trayH, "ahk_id" trayHwnd)
      tray := { x:trayX, y:trayY, w:trayW, h:trayH }
      trayX := trayY := trayW := trayH := unset

      if (mon.x <= tray.x && tray.x <= mon.x+mon.w && mon.y <= tray.y && tray.y <= mon.y+mon.h) {
        if tray.w = mon.w {
          if tray.y > mon.y {
            ; Taskbar at the bottom
            scr.h -= tray.h
          } else {
            ; Taskbar at the top
            scr.y += tray.h
            scr.h -= tray.h
          }
        } else if tray.h = mon.h {
          if tray.x > mon.x {
            ; Taskbar to the right
            scr.w -= tray.w
          } else {
            ; Taskbar to the left
            scr.x += tray.w
            scr.w -= tray.w
          }
        } else {
          ; THIS SHOULD NEVER HAPPEN
          ok     := false
          reason := "Failed to detect position of the MS Windows taskbar"
        }
      }
    }
  default:
    ; ERROR
    ok     := false
    reason := "Invalid arg: taskbar={}".f(taskbar.Inspect())
  }


  ;; Calculate new window position and size
  switch winSize {
  case "original":
    ; Center the window on the monitor (keeping window original size)
    win.x := scr.x + ((scr.w - win.w) // 2)
    win.y := scr.y + ((scr.h - win.h) // 2)
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
  case "stretch":
    ; Stretch the window over the whole screen area
    win.x := scr.x
    win.y := scr.y
    win.w := scr.w
    win.h := scr.h
  case "pixel-perfect":
    ; Only enlarge window by exact pixels
    mult := Min(scr.w // win.w, scr.h // win.h)

    if mult != 0 {
      win.w *= mult
      win.h *= mult
    }

    ; Center the window on the monitor
    win.x := scr.x + ((scr.w - win.w) // 2)
    win.y := scr.y + ((scr.h - win.h) // 2)
  default:
    ; ERROR
    ok     := false
    reason := "Invalid arg: winSize={}".f(winSize.Inspect())
  }


  ;; Check if window will cover the whole monitor area
  if win.x = mon.x
  && win.y = mon.y
  && win.w = mon.w
  && win.h = mon.h {
    ; Not needed: window will cover the whole monitor by itself
    needsBackgroundOverlay := false

    ; Not needed: MS Windows will hide the taskbar automatically
    needsAlwaysOnTop := false
  }


  ;; Return
  return {
    ok:     ok,
    reason: reason,
    window: win,
    screen: scr,
    needsBackgroundOverlay: needsBackgroundOverlay,
    needsAlwaysOnTop:       needsAlwaysOnTop,
  }
}

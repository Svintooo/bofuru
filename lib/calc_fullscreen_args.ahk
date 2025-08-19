;; Calculate coordinate, size, and screen area to make window fullscreen
;
; winSize    original         Keep original window size (no enlargement).
;            fit              Enlarge window as much as possible while keeping its aspect ratio.
;            stretch          Stretch window to fit the whole screen area.
;            pixel-perfect    Enlarge window by exact multiple.
;
; taskbar    hide             Hide the MS Windows taskbar.
;            show             Show the MS Windows taskbar.
;                             Window is centered related to monitor area.
;            show2            Show the MS Windows taskbar.
;                             Window is centered related to background overlay area.
;            show3            Show the MS Windows taskbar.
;                             Taskbar is removed twice from the allowed window area.
lib_calcFullscreenArgs(window, selectedMonitorNumber := 0, winSize := "fit", taskbar := "hide")
{
  ;; Set default return values
  ok                     := true  ; No errors
  reason                 := ""    ; No error reason message
  needsBackgroundOverlay := true  ; Usually needed for monitor area not covered by window
  needsAlwaysOnTop       := true  ; Usually needed to hide MS Windows taskbar


  ;; Get Window
  if window is Number {
    WinGetPos(&winX, &winY, &winW, &winH, "ahk_id" window)
    win := { x:winX, y:winY, w:winW, h:winH }
    winX := winY := winW := WinH := unset
  } else {
    win := { x:window.x, y:window.y, w:window.width, h:window.height }
  }


  ;; Get Monitor Area
  monitorCount := MonitorGetCount()
  monitorNumber  := false

  if selectedMonitorNumber && selectedMonitorNumber <= monitorCount {
    monitorNumber := selectedMonitorNumber
    MonitorGet(monitorNumber, &monX1, &monY1, &monX2, &monY2)
  }

  if !monitorNumber {
    ; Select first monitor that contains window x y coordinates
    Loop monitorCount {
      MonitorGet(A_Index, &monX1, &monY1, &monX2, &monY2)

      if (monX1 <= win.x && win.x <= monX2 && monY1 <= win.y && win.y <= monY2)
      || (monX2 <= win.x && win.x <= monX1 && monY2 <= win.y && win.y <= monY1) {
        monitorNumber := A_Index
        break
      }
    }

    if !monitorNumber {
      ; Select first monitor that overlaps with the window
      Loop monitorCount {
        MonitorGet(A_Index, &monX1, &monY1, &monX2, &monY2)

        if (monX1 < win.x + win.w && win.x < monX2 && monY1 < win.y + win.h && win.y < monY2)
        || (monX2 < win.x + win.w && win.x < monX1 && monY2 < win.y + win.h && win.y < monY1) {
          monitorNumber := A_Index
          break
        }
      }
    }
  }

  if !monitorNumber {
    monitorNumber := MonitorGetPrimary()
    MonitorGet(monitorNumber, &monX1, &monY1, &monX2, &monY2)
  }

  ;NOTE: mon = monitor area
  ;      scr = allowed screen area for the window to reside in
  ;      ovr = allowed screen area for the background overlay
  mon := {
    x: Min(monX1,monX2),
    y: Min(monY1,monY2),
    w: Abs(monX1-monX2),
    h: Abs(monY1-monY2)
  }
  scr := mon.Clone()
  ovr := mon.Clone()
  cntr := "mon"  ; Window position is centered relative to mon (monitor area)
  monX1 := monX2 := monY1 := monY2 := unset


  ;; (optional) Exclude taskbar area from allowed screen area
  ; Can be used in case there is a problem overlaying the MS Windows taskbar
  switch taskbar
  {
  case "hide":
    ; DO NOTHING
    ; Taskbar is hidden by default
  case "show", "show2", "show3":
    ; Let window position be centered relative to scr (allowed screen area)
    if taskbar = "show2"
      cntr := "scr"

    ; Check if taskbar area should be excluded from both sides of the screen area
    opposite_taskbar_area := (taskbar = "show3")

    ; AlwaysOnTop not needed since taskbar will be shown
    needsAlwaysOnTop := false

    ; Subtract the taskbar area from the allowed screen area
    for trayHwnd in WinGetList("ahk_class ^(Shell_TrayWnd|Shell_SecondaryTrayWnd)$") {
      WinGetPos(&trayX, &trayY, &trayW, &trayH, "ahk_id" trayHwnd)
      tray := { x:trayX, y:trayY, w:trayW, h:trayH }
      trayX := trayY := trayW := trayH := unset

      if (mon.x <= tray.x && tray.x <= mon.x+mon.w && mon.y <= tray.y && tray.y <= mon.y+mon.h) {
        if tray.w = mon.w {
          ; Taskbar at the top or bottom
          if tray.y > mon.y {
            ; Taskbar at the bottom
            ovr.h -= tray.h
          } else {
            ; Taskbar at the top
            ovr.y += tray.h
            ovr.h -= tray.h
          }

          if opposite_taskbar_area {
            scr.y += tray.h
            scr.h -= tray.h * 2
          } else {
            scr := ovr.Clone()
          }
        } else if tray.h = mon.h {
          ; Taskbar at the left or right side
          if tray.x > mon.x {
            ; Taskbar at the right side
            ovr.w -= tray.w
          } else {
            ; Taskbar at the left side
            ovr.x += tray.w
            ovr.w -= tray.w
          }

          if opposite_taskbar_area {
            scr.x += tray.w
            scr.w -= tray.w * 2
          } else {
            scr := ovr.Clone()
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
  ; size is calculated to fit inside scr (allowed screen area)
  ; position is centered relative to mon (monitor area)
  switch winSize
  {
  case "original", "keep":
    ; Center the window (keeping window original size)
    win.x := %cntr%.x + ((%cntr%.w - win.w) // 2)
    win.y := %cntr%.y + ((%cntr%.h - win.h) // 2)
  case "fit":
    ; Maximum size while keeping window aspect ratio
    if (scr.w / scr.h) > (win.w / win.h) {
      win.w := Round((scr.h / win.h) * win.w)
      win.h := scr.h
      win.x := Round(%cntr%.x + (Abs(%cntr%.w - win.w) / 2))
      win.y := scr.y
    } else {
      win.w := scr.w
      win.h := Round((scr.w / win.w) * win.h)
      win.x := scr.x
      win.y := Round(%cntr%.y + (Abs(%cntr%.h - win.h) / 2))
    }
  case "stretch":
    ; Stretch the window over the whole screen area
    win.x := scr.x
    win.y := scr.y
    win.w := scr.w
    win.h := scr.h
  case "pixel-perfect":
    ; Only resize window so it fits exact pixels (no pixel distortions)
    mult := Min(scr.w // win.w, scr.h // win.h)

    if mult != 0 {
      win.w *= mult
      win.h *= mult
    }

    ; Center the window
    win.x := %cntr%.x + ((%cntr%.w - win.w) // 2)
    win.y := %cntr%.y + ((%cntr%.h - win.h) // 2)
  default:
    ; ERROR
    ok     := false
    reason := "Invalid arg: winSize={}".f(winSize.Inspect())
  }


  ;; Make sure window is inside the allowed screen area
  if win.w <= scr.w {
    if win.x < scr.x
      win.x := scr.x
    else if win.x + win.w > scr.x + scr.w
      win.x := scr.x + scr.w - win.w
  }

  if win.h <= scr.h {
    if win.y < scr.y
      win.y := scr.y
    else if win.y + win.h > scr.y + scr.h
      win.y := scr.y + scr.h - win.h
  }


  ;; Check if window will cover the whole monitor area
  if win.x = mon.x && win.y = mon.y && win.w = mon.w && win.h = mon.h {
    ; Not needed: window will cover the whole area by itself
    needsBackgroundOverlay := false

    ; Not needed: MS Windows will hide the taskbar automatically
    needsAlwaysOnTop := false
  }


  ;; Check if window will cover the whole allowed screen area
  if win.x = scr.x && win.y = scr.y && win.w = scr.w && win.h = scr.h {
    ; Not needed: window will cover the whole area by itself
    needsBackgroundOverlay := false
  }


  ;; Return
  return {
    ok:     ok,
    reason: reason,
    window:  win,
    screen:  scr,
    overlay: ovr,
    monitor: mon,
    needsBackgroundOverlay: needsBackgroundOverlay,
    needsAlwaysOnTop:       needsAlwaysOnTop,
  }
}

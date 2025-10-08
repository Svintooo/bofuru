; https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles
lib_parseWindowStyle(winStyle)
{
   winStyles := {
    0x00000000: "WS_OVERLAPPED",        ; Type: Overlapped window (the default) (has title bar and border) (also called WS_TILED)
    0x00CF0000: "WS_OVERLAPPEDWINDOW",  ; Type: Overlapped window (also called WS_TILEDWINDOW)
                                        ;   (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)
    0x80000000: "WS_POPUP",             ; Type: Pop-up window (WS_CHILD incompatible)
    0x80880000: "WS_POPUPWINDOW",       ; Type: Pop-up window (WS_CAPTION needed to make visible)
                                        ;   (WS_POPUP | WS_BORDER | WS_SYSMENU)
    0x40000000: "WS_CHILD",             ; Type: Child window (menu bar unallowed) (WS_POPUP incompatible) (also callsed WS_CHILDWINDOW)

    0x02000000: "WS_CLIPCHILDREN",      ; Group: Never overlap child windows
    0x04000000: "WS_CLIPSIBLINGS",      ; Group: Never overlap sibling windows

    0x00800000: "WS_BORDER",            ; Border: thin-lined
    0x00400000: "WS_DLGFRAME",          ; Border: dialog box style (WS_CAPTION incompatible (no titlebar))
    0x00040000: "WS_THICKFRAME",        ; Border: Resizable (also called WS_SIZEBOX)

    0x00C00000: "WS_CAPTION",           ; Title bar: Enable (note: includes WS_BORDER)
    0x00080000: "WS_SYSMENU",           ; Title bar: Window menu (requires WS_CAPTION)
    0x00010000: "WS_MAXIMIZEBOX",       ; Title bar: Maximize button (requires WS_SYSMENU) (WS_EX_CONTEXTHELP incompatible)
    0x00020000: "WS_MINIMIZEBOX",       ; Title bar: Minimize button (requires WS_SYSMENU) (WS_EX_CONTEXTHELP incompatible)

    0x00100000: "WS_HSCROLL",           ; Scroll bar: Horizontal
    0x00200000: "WS_VSCROLL",           ; Scroll bar: Vertical

    0x08000000: "WS_DISABLED",          ; Init state: Disabled (cannot receive input from the user)
    0x10000000: "WS_VISIBLE",           ; Init state: Visible
    0x01000000: "WS_MAXIMIZE",          ; Init state: Maximized
    0x20000000: "WS_MINIMIZE",          ; Init state: Minimized (aslo called WS_ICONIC)
  }

  result := []

  for styleValue, styleName in WinStyles.OwnProps() {
    if (winStyle & styleValue = styleValue) {
      ; Extra test to handle 0x00000000
      if (styleValue != 0) || (styleValue = 0 && winStyle = 0) {
        result.Push(styleName)
      }
    }
  }

  return result
}


; https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles
lib_parseWindowExStyle(winExStyle)
{
  WinExStyles := {
    ;0x00000000: "WS_EX_LEFT",                 ; Left-Alignment: Properties left-aligned          (default)
    ;0x00000000: "WS_EX_LTRREADING",           ; Left-Alignment: Text left-to-right               (default)
    ;0x00000000: "WS_EX_RIGHTSCROLLBAR",       ; Left-Alignment: Vertical scroll bar to the right (default)

    0x00001000: "WS_EX_RIGHT",                ; Right-Alignment: Properties right aligned         (ignored unless OS lang support right-to-left)
    0x00002000: "WS_EX_RTLREADING",           ; Right-Alignment: Text right-to-left               (ignored unless OS lang support right-to-left)
    0x00004000: "WS_EX_LEFTSCROLLBAR",        ; Right-Alignment: Vertical scroll bar to the left  (ignored unless OS lang support right-to-left)
    0x00400000: "WS_EX_LAYOUTRTL",            ; Right-Alignment: X origin is top right window corner. Increasing x coordinate move window to the left.
                                              ;                                                   (ignored unless OS lang support right-to-left)

    0x00000001: "WS_EX_DLGMODALFRAME",        ; Border: Double border
    0x00000100: "WS_EX_WINDOWEDGE",           ; Border: Raised edges
    0x00000200: "WS_EX_CLIENTEDGE",           ; Border: Sunken edges
    0x00020000: "WS_EX_STATICEDGE",           ; Border: Three-dimensional

    0x00000400: "WS_EX_CONTEXTHELP",          ; Title bar: Question mark  (incompatible: WS_MAXIMIZEBOX, WS_MINIMIZEBOX)

    0x00000080: "WS_EX_TOOLWINDOW",           ; Type: Floating toolbar  (shorter title bar, smaller title bar font, no ALT+TAB)
    0x00080000: "WS_EX_LAYERED",              ; Type: Layered window    (before Win8: child windows unsupported)
    0x00000188: "WS_EX_PALETTEWINDOW",        ; Type: Palette window  (modeless dialog box with an array of commands)
                                              ;   (WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST)
    0x00000300: "WS_EX_OVERLAPPEDWINDOW",     ; Type: Overlapped window
                                              ;   (WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE)

    0x00000008: "WS_EX_TOPMOST",              ; Ability: Always above non-topmost windows
    0x00000010: "WS_EX_ACCEPTFILES",          ; Ability: Accepts drag-drop files
    0x00000020: "WS_EX_TRANSPARENT",          ; Ability: Transparent window (only works with other sibling windows unless SetWindowRgn function is used)
    0x00040000: "WS_EX_APPWINDOW",            ; Ability: When visible, forces top-level window to taskbar
    0x00200000: "WS_EX_NOREDIRECTIONBITMAP",  ; Ability: No render to a redirection surface
    0x08000000: "WS_EX_NOACTIVATE",           ; Ability: Never in focus  (not in taskbar without WS_EX_APPWINDOW)

    0x00000004: "WS_EX_NOPARENTNOTIFY",       ; Group: No notify parent when created or destroyed
    0x00000040: "WS_EX_MDICHILD",             ; Group: MDI child window
    0x00010000: "WS_EX_CONTROLPARENT",        ; Group: Contains child windows that should get focus when using TAB
    0x00100000: "WS_EX_NOINHERITLAYOUT",      ; Group: Does not pass window layout to child windows
    0x02000000: "WS_EX_COMPOSITED",           ; Group: Paint descendants in bottom-to-top painting order using double-buffering  (needed for translucency (alpha) and transparency (color-key) effects) (descendent window requires WS_EX_TRANSPARENT) (Win2000 not supported)
  }

  result := []

  for exStyleValue, exStyleName in WinExStyles.OwnProps() {
    if (winExStyle & exStyleValue = exStyleValue) {
      ; Extra test to handle 0x00000000
      if (exStyleValue != 0) || (exStyleValue = 0 && winExStyle = 0) {
        result.Push(exStyleName)
      }
    }
  }

  return result
}

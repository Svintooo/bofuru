; https://learn.microsoft.com/en-us/windows/win32/winmsg/window-styles
lib_parseWindowStyle(winStyle)
{
  WinStyles := {
    0x00800000: "WS_BORDER",           ; The window has a thin-line border
    0x00C00000: "WS_CAPTION",          ; The window has a title bar (includes the WS_BORDER style).
    0x40000000: "WS_CHILD",            ; The window is a child window. A window with this style cannot have a menu bar. This style cannot be used with the WS_POPUP style.
    0x02000000: "WS_CLIPCHILDREN",     ; Excludes the area occupied by child windows when drawing occurs within the parent window. This style is used when creating the parent window.
    0x04000000: "WS_CLIPSIBLINGS",     ; Clips child windows relative to each other; that is, when a particular child window receives a WM_PAINT message, the WS_CLIPSIBLINGS style clips all other overlapping child windows out of the region of the child window to be updated. If WS_CLIPSIBLINGS is not specified and child windows overlap, it is possible, when drawing within the client area of a child window, to draw within the client area of a neighboring child window.
    0x08000000: "WS_DISABLED",         ; The window is initially disabled. A disabled window cannot receive input from the user. To change this after a window has been created, use the EnableWindow function.
    0x00400000: "WS_DLGFRAME",         ; The window has a border of a style typically used with dialog boxes. A window with this style cannot have a title bar.
    0x00020000: "WS_GROUP",            ; The window is the first control of a group of controls. The group consists of this first control and all controls defined after it, up to the next control with the WS_GROUP style. The first control in each group usually has the WS_TABSTOP style so that the user can move from group to group. The user can subsequently change the keyboard focus from one control in the group to the next control in the group by using the direction keys. You can turn this style on and off to change dialog box navigation. To change this style after a window has been created, use the SetWindowLong function.
    0x00100000: "WS_HSCROLL",          ; The window has a horizontal scroll bar.
    0x01000000: "WS_MAXIMIZE",         ; The window is initially maximized.
    0x00010000: "WS_MAXIMIZEBOX",      ; The window has a maximize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
    0x20000000: "WS_MINIMIZE",         ; The window is initially minimized. Same as the WS_ICONIC style.
    0x00020000: "WS_MINIMIZEBOX",      ; The window has a minimize button. Cannot be combined with the WS_EX_CONTEXTHELP style. The WS_SYSMENU style must also be specified.
    0x00000000: "WS_OVERLAPPED",       ; The window is an overlapped window. An overlapped window has a title bar and a border. Same as the WS_TILED style.
    0x80000000: "WS_POPUP",            ; The window is a pop-up window. This style cannot be used with the WS_CHILD style.
    0x00040000: "WS_SIZEBOX",          ; The window has a sizing border. Same as the WS_THICKFRAME style.
    0x00080000: "WS_SYSMENU",          ; The window has a window menu on its title bar. The WS_CAPTION style must also be specified.
    0x10000000: "WS_VISIBLE",          ; The window is initially visible. This style can be turned on and off by using the ShowWindow or SetWindowPos function.
    0x00200000: "WS_VSCROLL",          ; The window has a vertical scroll bar.
    0x00CE0000: "WS_OVERLAPPEDWINDOW", ; (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX) The window is an overlapped window. Same as the WS_TILEDWINDOW style.
    0x80880000: "WS_POPUPWINDOW",      ; (WS_POPUP | WS_BORDER | WS_SYSMENU)   The window is a pop-up window. The WS_CAPTION and WS_POPUPWINDOW styles must be combined to make the window menu visible.
  }

  result := []

  for styleValue, styleName in WinStyles.OwnProps() {
    if winStyle & styleValue
      result.Push(styleName)
  }

  return result
}


; https://learn.microsoft.com/en-us/windows/win32/winmsg/extended-window-styles?redirectedfrom=MSDN
lib_parseWindowExStyle(winExStyle)
{
  WinExStyles := {
    0x00000010: "WS_EX_ACCEPTFILES",          ; The window accepts drag-drop files.
    0x00040000: "WS_EX_APPWINDOW",            ; Forces a top-level window onto the taskbar when the window is visible.
    0x00000200: "WS_EX_CLIENTEDGE",           ; The window has a border with a sunken edge.
    0x02000000: "WS_EX_COMPOSITED",           ; Paints all descendants of a window in bottom-to-top painting order using double-buffering. Bottom-to-top painting order allows a descendent window to have translucency (alpha) and transparency (color-key) effects, but only if the descendent window also has the WS_EX_TRANSPARENT bit set. Double-buffering allows the window and its descendents to be painted without flicker. This cannot be used if the window has a class style of CS_OWNDC, CS_CLASSDC, or CS_PARENTDC. Windows 2000: This style is not supported.
    0x00000400: "WS_EX_CONTEXTHELP",          ; The title bar of the window includes a question mark. When the user clicks the question mark, the cursor changes to a question mark with a pointer. If the user then clicks a child window, the child receives a WM_HELP message. The child window should pass the message to the parent window procedure, which should call the WinHelp function using the HELP_WM_HELP command. The Help application displays a pop-up window that typically contains help for the child window. WS_EX_CONTEXTHELP cannot be used with the WS_MAXIMIZEBOX or WS_MINIMIZEBOX styles.
    0x00010000: "WS_EX_CONTROLPARENT",        ; The window itself contains child windows that should take part in dialog box navigation. If this style is specified, the dialog manager recurses into children of this window when performing navigation operations such as handling the TAB key, an arrow key, or a keyboard mnemonic.
    0x00000001: "WS_EX_DLGMODALFRAME",        ; The window has a double border; the window can, optionally, be created with a title bar by specifying the WS_CAPTION style in the dwStyle parameter.
    0x00080000: "WS_EX_LAYERED",              ; The window is a layered window. This style cannot be used if the window has a class style of either CS_OWNDC or CS_CLASSDC. Windows 8: The WS_EX_LAYERED style is supported for top-level windows and child windows. Previous Windows versions support WS_EX_LAYERED only for top-level windows.
    0x00400000: "WS_EX_LAYOUTRTL",            ; If the shell language is Hebrew, Arabic, or another language that supports reading order alignment, the horizontal origin of the window is on the right edge. Increasing horizontal values advance to the left.
    0x00000000: "WS_EX_LEFT",                 ; The window has generic left-aligned properties. This is the default.
    0x00004000: "WS_EX_LEFTSCROLLBAR",        ; If the shell language is Hebrew, Arabic, or another language that supports reading order alignment, the vertical scroll bar (if present) is to the left of the client area. For other languages, the style is ignored.
    0x00000000: "WS_EX_LTRREADING",           ; The window text is displayed using left-to-right reading-order properties. This is the default.
    0x00000040: "WS_EX_MDICHILD",             ; The window is a MDI child window.
    0x08000000: "WS_EX_NOACTIVATE",           ; A top-level window created with this style does not become the foreground window when the user clicks it. The system does not bring this window to the foreground when the user minimizes or closes the foreground window. The window should not be activated through programmatic access or via keyboard navigation by accessible technology, such as Narrator. To activate the window, use the SetActiveWindow or SetForegroundWindow function. The window does not appear on the taskbar by default. To force the window to appear on the taskbar, use the WS_EX_APPWINDOW style.
    0x00100000: "WS_EX_NOINHERITLAYOUT",      ; The window does not pass its window layout to its child windows.
    0x00000004: "WS_EX_NOPARENTNOTIFY",       ; The child window created with this style does not send the WM_PARENTNOTIFY message to its parent window when it is created or destroyed.
    0x00200000: "WS_EX_NOREDIRECTIONBITMAP",  ; The window does not render to a redirection surface. This is for windows that do not have visible content or that use mechanisms other than surfaces to provide their visual.
    0x00001000: "WS_EX_RIGHT",                ; The window has generic "right-aligned" properties. This depends on the window class. This style has an effect only if the shell language is Hebrew, Arabic, or another language that supports reading-order alignment; otherwise, the style is ignored. Using the WS_EX_RIGHT style for static or edit controls has the same effect as using the SS_RIGHT or ES_RIGHT style, respectively. Using this style with button controls has the same effect as using BS_RIGHT and BS_RIGHTBUTTON styles.
    0x00000000: "WS_EX_RIGHTSCROLLBAR",       ; The vertical scroll bar (if present) is to the right of the client area. This is the default.
    0x00002000: "WS_EX_RTLREADING",           ; If the shell language is Hebrew, Arabic, or another language that supports reading-order alignment, the window text is displayed using right-to-left reading-order properties. For other languages, the style is ignored.
    0x00020000: "WS_EX_STATICEDGE",           ; The window has a three-dimensional border style intended to be used for items that do not accept user input.
    0x00000080: "WS_EX_TOOLWINDOW",           ; The window is intended to be used as a floating toolbar. A tool window has a title bar that is shorter than a normal title bar, and the window title is drawn using a smaller font. A tool window does not appear in the taskbar or in the dialog that appears when the user presses ALT+TAB. If a tool window has a system menu, its icon is not displayed on the title bar. However, you can display the system menu by right-clicking or by typing ALT+SPACE.
    0x00000008: "WS_EX_TOPMOST",              ; The window should be placed above all non-topmost windows and should stay above them, even when the window is deactivated. To add or remove this style, use the SetWindowPos function.
    0x00000020: "WS_EX_TRANSPARENT",          ; The window should not be painted until siblings beneath the window (that were created by the same thread) have been painted. The window appears transparent because the bits of underlying sibling windows have already been painted. To achieve transparency without these restrictions, use the SetWindowRgn function.
    0x00000100: "WS_EX_WINDOWEDGE",           ; The window has a border with a raised edge.
    0x00000300: "WS_EX_OVERLAPPEDWINDOW",     ; (WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE)  The window is an overlapped window.
    0x00000188: "WS_EX_PALETTEWINDOW",        ; (WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST)  The window is palette window, which is a modeless dialog box that presents an array of commands.
  }

  result := []

  for exStyleValue, exStyleName in WinExStyles.OwnProps() {
    if winExStyle & exStyleValue
      result.Push(exStyleName)
  }

  return result
}

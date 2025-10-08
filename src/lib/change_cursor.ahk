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

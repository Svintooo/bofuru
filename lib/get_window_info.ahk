getWindowInfo() {
  MouseGetPos(&x, &y, &hWnd, &ctrlClassNN)
  pid       := WinGetPID("ahk_id " hWnd)
  className := WinGetClass("ahk_id " hWnd)
  return { hWnd: hWnd, pid: pid, className: className }
}

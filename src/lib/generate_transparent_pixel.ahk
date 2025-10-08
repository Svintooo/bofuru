;; Create a transparent pixel
; THANK YOU SO MUCH AHKv2-Gdip!
; URL: https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk
; I could not have figured out this code without you.
lib_GenerateTransparentPixel()
{
  ;If !pToken := Gdip_Startup()
  ;  Abort("GDI+ failed to start. Please ensure you have GDI+ on your system")
  if (!DllCall("LoadLibrary", "str", "gdiplus", "UPtr"))
    return { ok: false, reason: "Could not load GDI+ library" }
  si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
  NumPut("UInt", 1, si)
  DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken:=0, "UPtr", si.Ptr, "UPtr", 0)
  if (!pToken)
    return { ok: false, reason: "GDI+ failed to start, ensure you have GDI+ on your system" }

  ;pBitmap := Gdip_CreateBitmap(Width:=1, Height:=1, _Format:=0x26200A)
  DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Width:=1, "Int", Height:=1, "Int", 0, "Int", _Format:=0x26200A, "UPtr", 0, "UPtr*", &pBitmap:=0)

  ;pGraphics := Gdip_GraphicsFromImage(pBitmap)
  DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pBitmap, "UPtr*", &pGraphics:=0)

  ;pBrush := Gdip_BrushCreateSolid(ARGB:=0x00000000)
  DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB:=0x00000000, "UPtr*", &pBrush:=0)

  ;Region := Gdip_GetClipRegion(pGraphics)
  DllCall("gdiplus\GdipCreateRegion", "UInt*", &Region:=0)
  DllCall("gdiplus\GdipGetClip", "UPtr", pGraphics, "UInt", Region)

  ;Gdip_FillRegion(pGraphics, pBrush, Region)
  DllCall("gdiplus\GdipFillRegion", "UPtr", pGraphics, "UPtr", pBrush, "UPtr", Region)

  ;hIcon := Gdip_CreateHICONFromBitmap(pBitmap)
  DllCall("gdiplus\GdipCreateHICONFromBitmap", "UPtr", pBitmap, "UPtr*", &hIcon:=0)

  ;Gdip_DisposeImage(pBitmap)
  DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)

  ;Gdip_Shutdown(pToken)
  DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
  hModule := DllCall("GetModuleHandle", "str", "gdiplus", "UPtr")
  if (!hModule)
    return { ok: false, reason: "GDI+ library already unloaded" }
  if (!DllCall("FreeLibrary", "UPtr", hModule))
    return { ok: false, reason: "Could not free GDI+ library" }

  ; return
  return { ok: true, data: "HICON:" hIcon }
}

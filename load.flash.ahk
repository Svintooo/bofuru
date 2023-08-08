#Requires AutoHotkey v2.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Flash Loader                                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                      ;;
;; Sets up the environment for running a flash file     ;;
;;                                                      ;;
;; Usage Example 1:                                     ;;
;;   ```                                                ;;
;;   ; Place a *.swf file in same folder as your script ;;
;;   #include "path\to\load.flash.ahk"                  ;;
;;   #include "path\to\launch.fullscreen.ahk"           ;; 
;;   ```                                                ;;
;;                                                      ;;
;; Usage Example 2:                                     ;;
;;   ```                                                ;;
;;   ; Use a custom flashplayer                         ;;
;;   flashplayer := "path\to\custom_flashplayer.exe"    ;;
;;   #include "path\to\load.flash.ahk"                  ;;
;;   #include "path\to\launch.fullscreen.ahk"           ;;
;;   ```                                                ;;
;;                                                      ;;
;; Usage Example 3:                                     ;;
;;   ```                                                ;;
;;   ; Manually set path to a flashfile                 ;;
;;   flashfile := "path\to\flashfile.swf"               ;;
;;   #include "path\to\load.flash.ahk"                  ;;
;;   #include "path\to\launch.fullscreen.ahk"           ;; 
;;   ```                                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; This Script Dir
script_dir := RegexReplace(A_LineFile, "[\\/][^\\/]*$", "")

;; Set Flash player
if not IsSet(flashplayer)
{
  flashplayer := script_dir "\flash\flashplayer_32_sa.exe"
}

;; Set Flash file
if not IsSet(flashfile)
{
  ; Take the first *.swf file in current working directory
  Loop Files "*.swf", "F"
  {
    if A_LoopFileExt = "swf"  ; Prevent matching 8.3 short names (*.swf*)
    {
      flashfile := A_LoopFilePath
      break
    }
  }
}
if not IsSet(flashfile)
{
  MsgBox("No *.swf file found.", "Error", "Icon!")
  ExitApp(1)
}

;; Set launch string
launch_string := flashplayer " " flashfile

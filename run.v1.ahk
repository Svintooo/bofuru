#Requires AutoHotkey v2.0
;; Flash Launcher
;;
;; Runs the *.swf file in the same folder as the script,
;; and runs it in fullscreen.
;;
;; Usage1:
;;   Place a *.swf and this script in the same folder.
;; Usage2:
;;   Place a *.swf and another ahk-script in the same folder.
;;   The other script includes this script like this:
;;   ```
;;   flashplayer := "path\to\flashplayer.exe"
;;   #include "path\to\this_script.ahk"
;;   ```

;; Configuration
if not IsSet(flashplayer)
{
  flashplayer := "./flashplayer_32_sa.exe"
}

;; Find *.swf file
Loop Files "*.swf", "F"
{
  game := A_LoopFilePath
  break
}
if not IsSet(game)
{
  MsgBox("*.swf file not found.", , 0x30)
  Exit(1)
}

;; Run Fullscreen
Run(flashplayer ' ' game, , , &process_id)
win_id := WinWait("ahk_pid " process_id)
WinActivate(win_id)
Send("^f")  ; Same as: Send("{LCtrl down}f{LCtrl up}")

;; Loop while game is running
Loop
{
  if !WinExist("ahk_pid " process_id)
  {
    break
  }

  ;; Get rid of eventual security warning windows
  warn_id := WinWait("Adobe Flash Player Security", , 2)
  if warn_id != 0
  {
    WinClose(warn_id)
  }
}
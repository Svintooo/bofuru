#Requires AutoHotkey v2.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Exe Loader                                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                      ;;
;; Sets up the environment for running an exe file      ;;
;;                                                      ;;
;; Optional Variables:                                  ;;
;;   exefile := "path\to\exefile.exe"                   ;;
;;   workdir := "path\to\workdir\"                      ;;
;;                                                      ;;
;; Usage Example:                                       ;;
;;   ```                                                ;;
;;   ... Optional Variables ...                         ;;
;;   #include "path\to\load.exe.ahk"                    ;;
;;   #include "path\to\launch.fullscreen.ahk"           ;; 
;;   ```                                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; This Script Dir
script_dir := RegexReplace(A_LineFile, "[\\/][^\\/]*$", "")  ; "some\path\file.ahk" => "some\path"

;; Set Flash file
if not IsSet(exefile)
{
  ; Take the first *.exe file in current working directory
  Loop Files "*.exe", "F"
  {
    if A_LoopFileExt = "exe"  ; Prevent matching 8.3 short names (*.exe*)
    {
      exefile := A_LoopFilePath
      break
    }
  }
}
if not IsSet(exefile)
{
  MsgBox("No *.exe file found.", "Error", "Icon!")
  ExitApp(1)
}

;; Set working directory
if not IsSet(workdir) and RegExMatch(exefile, "[\\/]")
{
  workdir := RegexReplace(exefile, "[\\/][^\\/]*$", "")  ; "some\path\file.exe" => "some\path"
  exefile := RegexReplace(exefile, ".*[\\/]", "")        ; "some\path\file.exe" => "file.exe"
  SetWorkingDir(workdir)
}

;; Set launch string
launch_string := exefile

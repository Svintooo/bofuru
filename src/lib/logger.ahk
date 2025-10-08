;; Logger Class
;
; Example usage:
; ```
;   logWriter := (message) => ...
;   logMethods := Map(
;     "info" ,"[INFO] ",
;     "error","[ERROR] ",
;   )
;   logg := lib_Logger(logWriter, logMethods)
;   logg.info("My first log message")
;   logg.error("Oh no! An error occured!")
; ```
class lib_Logger
{
  ; How many empty lines to write before the log message.
  ; Is reset after every write.
  extraNewLines := 0

  ;; Constructor
  __New(logWriterFunc, methods)
  {
    ; Tells Logger how to write to the log
    this.__logWriterFunc := (this, msg) => logWriterFunc(msg)

    ; Tells Logger what log methods to have
    for methodName, leadingStr in methods
      this.%methodName% := this.__LogMsg.Bind(, leadingStr, ,)
  }

  ;; Internal log method
  ; Not meant to be called directly.
  ; Is called through the methods defined in `methods` variable in __New().
  __LogMsg(leadingStr, message := "", options := "")
  {
    ; Add surrounding whitespaces (makes regex matching easier)
    options := " " options " "

    ; Blank out the leading string
    if RegExMatch(options, "i) LeadingBlanks ")
      leadingStr := leadingStr.RegExReplace(".", " ")

    ; Calculate the minimum amount of empty lines before the log message
    if RegExMatch(options, "i) MinimumEmptyLinesBefore *(\d+) ", &match)
    {
      minimumEmptyLines  := Integer(match[1])
      this.extraNewLines := Max(this.extraNewLines, minimumEmptyLines)
    }

    ; Generate newlines
    newLines := "`n"

    loop this.extraNewLines
      newLines .= "`n"

    ; Write log message
    if message {
      if not RegExMatch(options, "i) NoNewLine ")
        this.__logWriterFunc(newLines)

      this.__logWriterFunc(leadingStr . message)

      this.extraNewLines := 0
    }

    ; Calculate extra newlines that will be used for the next log message
    if RegExMatch(options, "i) MinimumEmptyLinesAfter *(\d+) ", &match)
    {
      minimumEmptyLines  := Integer(match[1])
      this.extraNewLines += minimumEmptyLines
    }
  }
}

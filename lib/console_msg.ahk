#Requires AutoHotkey v2.0

ConsoleMsg(msg, wait := false) {
    static hasConsole := false
    static ih

    ; 1. Allocate a console on first call
    if (!hasConsole) {
        DllCall("AllocConsole")  ; WinAPI call to create a console window
        ih := InputHook("", "{Enter}")
        hasConsole := true
    }

    ; 2. Write the message to the console
    ;    FileAppend to "*" writes directly to the script’s console
    FileAppend msg . "`n", "*"

    ; 3. Wait for Enter
    if wait {
        ih.Start()
        ih.Wait()
        ih.Stop()
    }
}

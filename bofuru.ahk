#Requires AutoHotkey v2.0
#WinActivateForce
;#NoTrayIcon

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BoFuru - Borderless Fullscreen Launcher       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                               ;;
;; Run games in simulated fullscreen.            ;;
;;                                               ;;
;; Usage Example:                                ;;
;;   ```                                         ;;
;;   ```                                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;TODOS
;; - config file: read bofuru.conf.txt
;; - autorun file: read bofuru.auto.txt
;; - blacklist of windows not to modify:
;;     https://learn.microsoft.com/en-gb/windows/win32/winmsg/about-window-classes?redirectedfrom=MSDN
;;     * "ahk class Button"      The class for a button.
;;     * "ahk class ComboBox"    The class for a combo box.
;;     * "ahk class Edit"        The class for an edit control.
;;     * "ahk class ListBox"     The class for a list box.
;;     * "ahk class MDIClient"   The class for an MDI client window.
;;     * "ahk class ScrollBar"   The class for a scroll bar.
;;     * "ahk class Static"      The class for a static control.
;;     * "ahk class ComboLBox"   The class for the list box contained in a combo box.
;;     * "ahk class DDEMLEvent"  The class for Dynamic Data Exchange Management Library (DDEML) events.
;;     * "ahk class Message"     The class for a message-only window.
;;     * "ahk class #32768"      The class for a menu.
;;     * "ahk class #32769"      The class for the desktop window.
;;     * "ahk class #32770"      The class for a dialog box.
;;     * "ahk class #32771"      The class for the task switch window.
;;     * "ahk class #32772"      The class for icon titles.
;; - vpatch briefly show game borders, hides game window, show fullscreen dialog
;;     make sure script do not modify hidden game window, wait until it properly starts
;; - trayicon:
;;     * custom icon
;;     * custom menu: Show text: "title text of target game window"
;;                    option: fullscreen on/off
;;                    option: quit
;; - compiled exe:
;;     * custom icon (same as trayicon)
;; - For each game, custom pictures for use as bars (left/right or up/down of game window)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Language Extensions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Make `DefineProp` usable with other prototypes, not just Object.Prototype.
; https://www.autohotkey.com/boards/viewtopic.php?t=115591
;   Normally, `this` will implicitly refer to Object.prototype:
;     Object.Prototype.DefineProp(Name, Desc)  ; `this` cannot be set
;   By copying the method, we can set the prototype explicitly:
;     __ObjDefineProp(prototype, Name, Desc)   ; this := prototype
__ObjDefineProp := Object.Prototype.DefineProp

;; Add a `Bind` function to all classes
; https://www.autohotkey.com/boards/viewtopic.php?t=115591
; Example:
;   fun := Array.Bind(, "Alpha", "Beta", "Gamma")
;   arr := fun()  ; Same as: arr := Array("Alpha", "Beta", "Gamma")
__ObjDefineProp(Class.Prototype, "Bind", {
  Call: (this, Method := 'Call', Params*) => ObjBindMethod(this, Method, Params*)
})

;; Add a `DefineFunc` function to all classes
; This makes it possible to add user defined functions to objects of existing classes.
; Example:
;   Array.DefineFunc("add_four", ArrayObj => ArrayObj.Push(4))
;   arr := [1,2,3]
;   arr.add_four()  ; Same as: arr.Push(4)
__ObjDefineProp(Class.Prototype, "DefineFunc", {
  Call: (this, NewMethod, ExternalMethod, Params*) => __ObjDefineProp(this.prototype, NewMethod, {call: ObjBindMethod(ExternalMethod)})
})

;; __FuncHandler
; Used by functions that receives a function reference.
__FuncHandler(this, func)
{
  if not func is String {
    FuncObj := func
  } else if "." = SubStr(func,1,1) {
    FuncObj := this.%SubStr(func,2)%  ; ".func" -> this.func
  } else {
    FuncObj := %func%
  }

  return FuncObj
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (stdLib)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Inspect
; How else are you gonna debug your variables?
Inspect(SomeObj)
{
  TypeString := Type(SomeObj)
  InspectFunc := "__" TypeString "_Inspect"

  if IsSet(InspectFunc)
    StringObj := %InspectFunc%(SomeObj)
  else
    StringObj := TypeString "()"

  return StringObj
}

Object.DefineFunc("Inspect", __Object_Inspect)
__Object_Inspect(obj)
{
  return Type(obj) "()"
}

Integer.DefineFunc("Inspect", __Integer_Inspect)
__Integer_Inspect(IntegerObj)
{
  return String(IntegerObj)
}

Float.DefineFunc("Inspect", __Float_Inspect)
__Float_Inspect(FloatObj)
{
  return String(FloatObj)
}

String.DefineFunc("Inspect", __String_Inspect)
__String_Inspect(StringObj)
{
  return '"' StrReplace(StringObj,'"','``"') '"'
}

Array.DefineFunc("Inspect", __Array_Inspect)
;__Array_Inspect(ArrayObj)  ; Recursive solution
;{
;  StringObj := "["
;
;  loop ArrayObj.Length-1
;  {
;    ;StringObj .= ArrayObj.Has(A_index) ? ArrayObj[A_index].Inspect() : ""
;    StringObj .= ArrayObj.Has(A_index) ? Inspect(ArrayObj[A_index]) : ""
;    StringObj .= ", "
;  }
;
;  ;StringObj .= ArrayObj.Has(-1) ? ArrayObj[-1].Inspect() : ""
;  StringObj .= ArrayObj.Has(-1) ? Inspect(ArrayObj[-1]) : ""
;  StringObj .= "]"
;
;  return StringObj
;}
__Array_Inspect(RootArrayObj)  ; Iterative solution
{
  StringObj := ""
  queue := [{index: 0, visited: 0, array: RootArrayObj}]

  while queue.Length > 0
  {
    o := queue[-1]

    if o.array.Has(o.index) && o.visited < o.index
    {
      o.visited := o.index

      if o.array[o.index] is Array {
        queue.Push({index: 0, visited: 0, array: o.array[o.index]})
        continue
      } else {
        ;StringObj .= o.array[o.index].Inspect()
        StringObj .= Inspect(o.array[o.index])
      }
    }

    if o.index = 0 {
      StringObj .= "["
    } else if o.index < o.array.Length {
      StringObj .= ", "
    } else {  ; if o.index = o.array.Length
      StringObj .= "]"
      queue.Pop()
    }

    o.index += 1
  }

  return StringObj
}

Map.DefineFunc("Inspect", __Map_Inspect)
__Map_Inspect(MapObj)
{
  StringObj := "Map("

  EnumObj := MapObj.__Enum()

  EnumObj.Call(&key, &value)
  StringObj .= Inspect(key) "," Inspect(value)

  while EnumObj.Call(&key, &value)
    StringObj .= ", " Inspect(key) "," Inspect(value)

  StringObj .= ")"

  return StringObj
}


;; IsEmpty
; True if the variable is considered empty.
IsEmpty(SomeObj)
{
  TypeString := Type(SomeObj)
  InspectFunc := TypeString "_IsEmpty"

  ;if IsSet(InspectFunc)
    StringObj := %InspectFunc%(SomeObj)
  ;else
    ;TODO: Some error handling here

  return StringObj
}
String.DefineFunc("IsEmpty", __String_IsEmpty)
__String_IsEmpty(StringObj)
{
  return StrLen(StringObj) = 0
}
Array.DefineFunc("IsEmpty", __Array_IsEmpty)
__Array_IsEmpty(ArrayObj)
{
  return ArrayObj.Length = 0
}
Map.DefineFunc("IsEmpty", __Map_IsEmpty)
__Map_IsEmpty(MapObj)
{
  return MapObj.Count = 0
}

;; IsBlank
; True if the variable is considered blank.
; True for strings, arrays, and maps, if they are empty.
; False for everything else.
IsBlank(SomeObj)
{
  TypeString := Type(SomeObj)
  InspectFunc := "__" TypeString "_IsEmpty"

  if IsSet(InspectFunc)
    StringObj := %InspectFunc%(SomeObj)
  else
    __Object_IsBlank(SomeObj)

  return StringObj
}
Object.DefineFunc("IsBlank", __Object_IsBlank)
__Object_IsBlank(Obj)
{
  return false
}
Integer.DefineFunc("IsBlank", __Integer_IsBlank)
__Integer_IsBlank(IntegerObj)
{
  return false
}
Float.DefineFunc("IsBlank", __Float_IsBlank)
__Float_IsBlank(FloatObj)
{
  return false
}
String.DefineFunc("IsBlank", __String_IsBlank)
__String_IsBlank(StringObj)
{
  return __String_IsEmpty(StringObj)
}
Array.DefineFunc("IsBlank", __Array_IsBlank)
__Array_IsBlank(ArrayObj)
{
  return __Array_IsEmpty(ArrayObj)
}
Map.DefineFunc("IsBlank", __Map_IsBlank)
__Map_IsBlank(MapObj)
{
  return __Map_IsEmpty(MapObj)
}

;; IsPresent
; True if the variable is considered present.
; False for strings, arrays, and maps, if they are empty.
; True for everything else.
IsPresent(SomeObj)
{
  TypeString := Type(SomeObj)
  InspectFunc := TypeString "_IsPresent"

  if IsSet(InspectFunc)
    StringObj := %InspectFunc%(SomeObj)
  else
    __Object_IsPresent(SomeObj)

  return StringObj
}
Object.DefineFunc("IsPresent", __Object_IsPresent)
__Object_IsPresent(Obj)
{
  return true
}
Integer.DefineFunc("IsPresent", __Integer_IsPresent)
__Integer_IsPresent(IntegerObj)
{
  return true
}
Float.DefineFunc("IsPresent", __Float_IsPresent)
__Float_IsPresent(FloatObj)
{
  return true
}
String.DefineFunc("IsPresent", __String_IsPresent)
__String_IsPresent(StringObj)
{
  return not __String_IsEmpty(StringObj)
}
Array.DefineFunc("IsPresent", __Array_IsPresent)
__Array_IsPresent(ArrayObj)
{
  return not __Array_IsEmpty(ArrayObj)
}
Map.DefineFunc("IsPresent", __Map_IsPresent)
__Map_IsPresent(MapObj)
{
  return not __Map_IsEmpty(MapObj)
}

;; Contains
Array.DefineFunc("Contains", __Array_Contains)
__Array_Contains(ArrayObj, needle)
{
  for value in ArrayObj
    if value = needle
      return true
  return false
}
Map.DefineFunc("Contains", __Map_Contains)
__Map_Contains(MapObj, needle)
{
  for , value in MapObj
    if value = needle
      return true
  return false
}

;; Array of all keys in a Map
Map.DefineFunc("Keys", __Map_Keys)
__Map_Keys(MapObj)
{
  ArrayObj := Array()

  for key in MapObj
    ArrayObj.Push(key)

  return ArrayObj
}

;; Array of all values in a Map
Map.DefineFunc("Values", __Map_Values)
__Map_Values(MapObj)
{
  ArrayObj := Array()
  
  for , value in MapObj
    ArrayObj.Push(value)

  return ArrayObj
}

;; True if for all elements e: func(e, args*) => true
Array.DefineFunc("All", __Array_All)
__Array_All(ArrayObj, func, args*)
{
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    if not FuncObj(ArrayObj[A_Index], args*)
      return false
  }
  return true
}

;; True if for all values v: func(v, args*) => true
Map.DefineFunc("All", __Map_All)
__Map_All(MapObj, func, args*)
{
  return __Array_All(__Map_Values(MapObj), func, args)
}

;; True if for any element e: func(e, args*) => true
Array.DefineFunc("Any", __Array_Any)
__Array_Any(ArrayObj, func, args*)
{
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    if FuncObj(ArrayObj[A_Index], args*)
      return true
  }
  return false
}

;; True if for any value v: func(v, args*) => true
Map.DefineFunc("Any", __Map_Any)
__Map_Any(MapObj, func, args*)
{
  return __Array_Any(__Map_Values(MapObj), func, args)
}

;; New array where each element e: func(e, args*)
Array.DefineFunc("Collect", __Array_Collect)
__Array_Collect(ArrayObj, func, args*)
{
  NewArrayObj := Array()
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    NewArrayObj.Push FuncObj(ArrayObj[A_Index], args*)
  }
  return NewArrayObj
}

;; New array where each element e: func(e, args*)
Map.DefineFunc("Collect", __Map_Collect)
__Map_Collect(MapObj, func, args*)
{
  NewMapObj := Map()
  for key, value in MapObj
  {
    FuncObj := __FuncHandler(value, func)
    NewMapObj[key] := FuncObj(value, args*)
  }
  return NewMapObj
}

;;
Array.DefineFunc("Inject", __Array_Inject)
__Array_Inject(ArrayObj, func, args*)
{
  if ArrayObj.Length < 2
    return ArrayObj

  EnumeratorObj := ArrayObj.__Enum()

  EnumeratorObj.Call(&NewArrayObj)
  FuncObj := __FuncHandler(NewArrayObj, func)

  while EnumeratorObj.Call(&NewArrayObj2)
    NewArrayObj := FuncObj(NewArrayObj, NewArrayObj2, args*)

  return NewArrayObj
}

;; New array that only contains elements e where: func(e, args*) = true
Array.DefineFunc("Select", __Array_Select)
__Array_Select(ArrayObj, func, args*)
{
  NewArrayObj := Array()

  for value in ArrayObj
  {
    FuncObj := __FuncHandler(value, func)
    if FuncObj(value, args*)
      NewArrayObj.Push(value)
  }

  return NewArrayObj
}

;; New array that only contains elements e where: func(e, args*) = false
Array.DefineFunc("Reject", __Array_Reject)
__Array_Reject(ArrayObj, func, args*)
{
  NewArrayObj := Array()

  for value in ArrayObj
  {
    FuncObj := __FuncHandler(value, func)
    if not FuncObj(value, args*)
      NewArrayObj.Push(value)
  }

  return NewArrayObj
}

;; New array that only contains elements e where: IsSet(e) = true
; Basically removes all unset elements in an array.
; Example:
;   [1,2,3,,5,6,,8,,,,12,] -> [1,2,3,5,6,8,12]
Array.DefineFunc("Compact", __Array_Compact)
__Array_Compact(ArrayObj)
{
  NewArrayObj := Array()

  for value in ArrayObj
  {
    if IsSet(value)
      NewArrayObj.Push(value)
  }

  return NewArrayObj
}

;; Convert each element to String, and join them together to one single String.
; Example:
;   [1,2,3.3,"444"].Join("|") -> "1|2|3.3|444"
Array.DefineFunc("Join", __Array_Join)
__Array_Join(ArrayObj, delimiter := "")
{
  StringObj := ""

  for value in ArrayObj
    StringObj .= String(value) delimiter

  if delimiter
    StringObj := SubStr(StringObj, 1, -StrLen(delimiter))

  return StringObj
}

;; Flatten any array to a 1-dimentional array
; Example:
;   [ "a", ["b", ["c"]] ] -> [ "a", "b", "c" ]
Array.DefineFunc("Flatten", __Array_Flatten)
__Array_Flatten(RootArrayObj, max_depth := unset)
{
  if RootArrayObj.Length = 0
    return []

  NewArrayObj := Array()

  queue := Array([RootArrayObj,0,1])  ; LIFO queue
  static pos := -1  ; Queue position
  static arr := 1   ; Array
  static idx := 2   ; Index
  static dpt := 3   ; Depth

  ; No need for a recursive solution when you can loop!
  while queue.Length > 0
  {
    while queue[pos][idx] < queue[pos][arr].Length
    {
      ArrayObj := queue[pos][arr]
      index    := queue[pos][idx] += 1
      depth    := queue[pos][dpt]

      if ArrayObj[index] is Array
      && (!IsSet(max_depth) || depth <= max_depth) {
        if ArrayObj[index].Length != 0 {
          queue.Push([ArrayObj[index], 0, depth+1])
        }
      } else {
        NewArrayObj.Push(ArrayObj[index])
      }
    }

    queue.Pop()
  }

  return NewArrayObj
}

;; Product of two arrays
; Example: [1].Product([2,3]) -> [[1,2],[1,3]]
Array.DefineFunc("Product", __Array_Product)
__Array_Product(ArrayObj, ArrayObj2)
{
  NewArrayObj := Array()

  for value in ArrayObj
    for value2 in ArrayObj2
      NewArrayObj.push([value, value2])

  return NewArrayObj
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (setup)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Split a command line string into its separate parts
; Example:
;   'cd "C:\Program Files"' -> ["cd", "C:\Program Files"]
SplitCmdString(CmdString)
{
  ArrayObj  := Array()
  StringObj := ""
  inside_quotes := false

  loop Parse CmdString
  {
    if A_LoopField = '"' {
      inside_quotes := !inside_quotes
    } else if A_LoopField = ' ' and not inside_quotes {
      ArrayObj.Push(StringObj)
      StringObj := ""
    } else {
      StringObj .= A_LoopField
    }
  }

  if StrLen(StringObj) != 0
    ArrayObj.Push(StringObj)

  if inside_quotes
  {
    MsgBox "Quote-pair is missing an ending quote (`"):`n`n" CmdString, , "Icon!"
    ExitApp(1)
  }

  return ArrayObj
}

FindFiles(file_pattern)
{
  files := Array()
  loop Files file_pattern, "F"
    files.push(A_LoopFilePath)
  return files
}

GenerateLaunchStrings(launch_pattern)
{
  launch_strings := []

  for file_pattern in SplitCmdString(launch_pattern)
  {
    files := FindFiles(file_pattern)
    launch_strings.Push(files)
  }

  if launch_strings.Any(".IsEmpty")
    launch_strings := []
  else
    launch_strings := launch_strings.Inject(".Product").Collect(".Join", " ")

  return launch_strings
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (fullscreen)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetActiveMonitorSize()
{
  monitor := 0

  ; Coordinates - Method 1
  ;CoordMode("Mouse", "Screen")
  ;MouseGetPos(&x, &y)  ; Get x y coordinates of mouse pointer

  ; Coordinates - Method 2
  active_hwnd := WinExist("A")  ; Get the window that is currently in focus
  WinGetPos(&x, &y, , , active_hwnd)  ; Get x y coordinates of window upper left corner

  ; Find the monitor that contains the x y coordinates
  Loop MonitorGetCount()
  {
    MonitorGet(A_Index, &mon_x1, &mon_y1, &mon_x2, &mon_y2)
    if (mon_x1 <= x and x <= mon_x2 and mon_y1 <= y and y <= mon_y2)
    {
      monitor := {
          x1: mon_x1, y1: mon_y1,
          x2: mon_x2, y2: mon_y2
        }
      Break
    }
  }
  
  ; If monitor not found, use primary monitor
  if not monitor
  {
    MonitorGet(MonitorGetPrimary(), &mon_x1, &mon_y1, &mon_x2, &mon_y2)
    monitor := {
        x1: mon_x1, y1: mon_y1,
        x2: mon_x2, y2: mon_y2
      }
  }

  Return {
    x: monitor.x1,
    y: monitor.y1,
    width:  (monitor.x2 - monitor.x1),
    height: (monitor.y2 - monitor.y1),
  }
}

CalculateCorrectWindowsSizePos(app_hwnd)
{
  WinGetPos(, , &app_width, &app_height, app_hwnd)
  screen_size := GetActiveMonitorSize()

  if (screen_size.width / screen_size.height) > (app_width / app_height)
  {
    win_width := (screen_size.height / app_height) * app_width
    win_height := screen_size.height
    win_x := screen_size.x + ((screen_size.width - win_width) / 2)
    win_y := screen_size.y

    barBL_x := screen_size.x
    barBL_y := screen_size.y
    barBL_width := win_x - screen_size.x
    barBL_height := screen_size.height

    barTR_x := win_x + win_width
    barTR_y := screen_size.y
    barTR_width := screen_size.width - barBL_width - win_width
    barTR_height := screen_size.height
  }
  else
  {
    win_width := screen_size.width
    win_height := (screen_size.width / app_width) * app_height
    win_x := screen_size.x
    win_y := screen_size.y + ((screen_size.height - win_height) / 2)

    barTR_x := screen_size.x
    barTR_y := screen_size.y
    barTR_width := screen_size.width
    barTR_height := win_y - screen_size.y

    barBL_x := screen_size.x
    barBL_y := win_y + win_height
    barBL_width := screen_size.width
    barBL_height := screen_size.height - barTR_height - win_height
  }

  Return {
    app_size: {
      x: win_x,
      y: win_y,
      width: win_width,
      height: win_height,
    },
    bar_bl_size: {
      x: barBL_x,
      y: barBL_y,
      width: barBL_width,
      height: barBL_height,
    },
    bar_tr_size: {
      x: barTR_x,
      y: barTR_y,
      width: barTR_width,
      height: barTR_height,
    },
  }
}

CalculateXButtonSize(bar_width, bar_height)
{
  xb_width := 30 ;TODO: Make constant
  xb_height := 30 ;TODO: Make constant
  xb_spacing := 0 ;TODO: Make constant
  Return {
    x: bar_width - xb_width - xb_spacing,
    y: xb_spacing,
    width: xb_width,
    height: xb_height,
  }
}

ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
{
  win_sizes := CalculateCorrectWindowsSizePos(app_hwnd)

  app_size := win_sizes.app_size
  barBL_size := win_sizes.bar_bl_size
  barTR_size := win_sizes.bar_tr_size

  WinMove(app_size.x, app_size.y, app_size.width, app_size.height, app_hwnd)
  barBL.Move(barBL_size.x, barBL_size.y, barBL_size.width, barBL_size.height)
  barTR.Move(barTR_size.x, barTR_size.y, barTR_size.width, barTR_size.height)
  RepositionXButton(xBtn)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Global Variables
; Note: `A_LineFile` is used since it gives same result for: current script, #Include file, compiled file
script_name := RegexReplace(A_LineFile, "^.*[\\/]|[\.][^\.]*$", "")  ; "some\path\bofuru.ahk" -> "bofuru"
script_dir  := RegexReplace(A_LineFile, "[\\/][^\\/]+$", "")  ; "some\path\bofuru.ahk" -> "some\path"
config_file  := script_dir "\" script_name ".ini"

;; Transparent Pixel
; This is needed to create clickable areas in GUI windows.
;TODO: Generate pixel in code instead of loading from file
;@Ahk2Exe-IgnoreBegin
pixel := script_dir . "\resourses\transparent_pixel.ico"
;@Ahk2Exe-IgnoreEnd
;@Ahk2Exe-AddResource resourses\transparent_pixel.ico, pixel

;; Config File
launch_string       := IniRead(config_file, "config", "launch", "")
workdir             := IniRead(config_file, "config", "workdir", "")
x_button_visibility := IniRead(config_file, "config", "x_button", "")
autorun_find        := Array()
autorun_ignore      := Array()
loop Parse IniRead(config_file, "autorun"), "`r`n", A_Space A_Tab
  if A_LoopField ~= "^!"
    autorun_ignore.Push( SubStr(A_LoopField,2) )
  else
    autorun_find.Push( A_LoopField )



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if workdir
{
  if not FileExist(workdir) ~= "D"
    MsgBox("workdir not found:`n`n" workdir, "")
  SetWorkingDir workdir
}

if not launch_string
{
  autorun_ignore :=
    autorun_ignore.Collect(GenerateLaunchStrings)
                  .Reject(".IsEmpty")
                  .Flatten()

  autorun_find :=
    autorun_find.Collect(GenerateLaunchStrings)
                .Reject(".IsEmpty")
                .Flatten()
                .Reject(launch_string=>autorun_ignore.Contains(launch_string))

  if autorun_find.Has(1)
    launch_string := autorun_find[1]
}

if not launch_string
{
  MsgBox("Could not find anything to execute.", , "Icon!")
  ExitApp(1)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Run
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Run
; Start app
Run(launch_string, , , &app_pid)
if not app_hwnd := WinWait("ahk_pid " app_pid, , 5)  ; Get app window id (hwnd)
{
  if ProcessExist(app_pid)
    ProcessClose(app_pid)
  ExitApp(0)
}
;WinWaitClose(app_hwnd)
;ExitApp(0)

; Create black bars
barBL := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Bottom Left
barTR := Gui("+ToolWindow -Caption -DPIScale")  ; Bar at Top Right
barBL.BackColor := "Black"
barTR.BackColor := "Black"
barBL.Show("W0 H0")  ; Initially hidden by setting width/height to 0
barTR.Show("W0 H0")  ; Initially hidden by setting width/height to 0
barBL.OnEvent("Size", EventBarBLSize)
barTR.OnEvent("Size", EventBarTRSize)
EventBarBLSize(*)
{
  clickArea_reposition(barBL_clickArea) ;pixel
}
EventBarTRSize(*)
{
  clickArea_reposition(barTR_clickArea) ;pixel
  RepositionXButton(xBtn)
}

; Create exit button
xBtn := barTR.Add("Button", "Default", "X")
xBtn.OnEvent("Click", EventXButtonClick)
EventXButtonClick(*)
{
  WinClose(app_hwnd)
}
RepositionXButton(xBtn)
{
  xBtn.Gui.GetPos(, , &bar_width, &bar_height)
  xBtn_size := CalculateXButtonSize(bar_width, bar_height)
  xBtn.Move(xBtn_size.x, xBtn_size.y, xBtn_size.width, xBtn_size.height)
}

; Make mouse clicks on the bars return focus to the app
WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures be both clickable,
                              ; and have other elements placed on top of them.
barBL_clickArea := barBL.Add("Picture", WS_CLIPSIBLINGS, pixel)
barTR_clickArea := barTR.Add("Picture", WS_CLIPSIBLINGS, pixel)
barBL_clickArea.OnEvent("Click", event_clickArea_click)
barTR_clickArea.OnEvent("Click", event_clickArea_click)
barBL_clickArea.OnEvent("DoubleClick", event_clickArea_click)
barTR_clickArea.OnEvent("DoubleClick", event_clickArea_click)
event_clickArea_click(*)
{
  WinActivate(app_hwnd)  ; Hand focus back to the app
}
clickArea_reposition(clickArea)
{
  ; Stretch the pixel to fit the whole bar
  clickArea.Gui.GetClientPos(,,&w,&h)
  clickArea.move(0,0,w,h)
}

; Make app borderless
WinGetClientPos(, , &app_width, &app_height, app_hwnd)  ; Get width/height before removing border
DllCall("SetMenu", "uint", app_hwnd, "uint", 0)  ; Remove menu bar
win_styles := 0x00C00000  ; WS_CAPTION    (title bar)
            | 0x00800000  ; WS_BORDER     (visible border)
            | 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" win_styles, app_hwnd)  ; Remove styles
WinMove(, , app_width, app_height, app_hwnd)  ; Restore width/height

; Activate fullscreen
ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
barBL.Opt("+AlwaysOnTop")
barTR.Opt("+AlwaysOnTop")
WinSetAlwaysOnTop(True, app_hwnd)
WinMoveTop(barBL.Hwnd)
WinMoveTop(barTR.Hwnd)
WinMoveTop(app_hwnd)
WinActivate(app_hwnd)  ; Focus the app window


;; Misc Event Handlers

; Exit when App has quit
SetTimer EventWindowClose
EventWindowClose()
{
  ;if not ProcessExist(app_pid)
  if not WinExist(app_hwnd)
  {
    ExitApp(0)  ; Script Exit
  }
}

; Kill eventual Flashplayer Security popups
; Useful when running flash, and flash tries to connect to the Internet and fails
SetTimer EventFlashSecurity
EventFlashSecurity()
{
  if warn_id := WinActive("Adobe Flash Player Security")
  {
    WinClose(warn_id)
    if WinExist(app_hwnd)
      WinMoveTop(app_hwnd)
  }
}

; Tell Windows to notify us on events on any window
;https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registershellhookwindow
DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(MsgNum, ShellMessage)
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  static HSHELL_MONITORCHANGED   := 0x00000010
       , HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Some window moved to another monitor
  if (wParam = HSHELL_MONITORCHANGED)
  {
    if (lParam = app_hwnd)
    {
      ; App has moved to another monitor
      ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
    }
  }

  ; Some window got focus
  else if (wParam = HSHELL_RUDEAPPACTIVATED || wParam = HSHELL_WINDOWACTIVATED)
  {
    if (lParam = app_hwnd)
    {
      ; App got focused, make app and bars AlwaysOnTop
      if WinExist(barBL.Hwnd) {
        barBL.Opt("+AlwaysOnTop")
        WinMoveTop(barBL.Hwnd)
      }
      if WinExist(barTR.Hwnd) {
        barTR.Opt("+AlwaysOnTop")
        WinMoveTop(barTR.Hwnd)
      }
      if WinExist(app_hwnd) {
        WinSetAlwaysOnTop(true, app_hwnd)
        WinMoveTop(app_hwnd)
      }
    }
    else if (lParam = 0)
    {
      ; DO NOTHING
      ; Focus was given to either:
      ;   - one of the black bars
      ;   - the windows taskbar
      ;   - something unknown
    }
    else
    {
      ; Something other than the app got focus
      ;  Remove AlwaysOnTop so the focused window can be seen
      if WinExist(barBL.Hwnd)
        barBL.Opt("-AlwaysOnTop")
      if WinExist(barTR.Hwnd)
        barTR.Opt("-AlwaysOnTop")
      if WinExist(app_hwnd)
        WinSetAlwaysOnTop(false, app_hwnd)
      if WinExist(lParam)
        WinMoveTop(lParam)  ; Make sure the newly focused window is visible
    }
  }
}

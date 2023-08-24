#Requires AutoHotkey v2.0
#WinActivateForce
;#NoTrayIcon
SetTitleMatchMode "RegEx"

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
;; - Fix UTF-8 parse problem in *.ini files.
;; - Detect/ignore games in "true fullscreen".
;; - create transparent_pixel.ico in code
;;     stop relying on a separate *.ico file.
;; - vpatch briefly show game borders, hides game window, show fullscreen dialog
;;     make sure script do not modify hidden game window, wait until it properly starts
;; - trayicon:
;;     * custom icon
;;     * custom menu: Show text: "title text of target game window"
;;                    option: fullscreen on/off
;;                    option: move to another monitor
;;                    option: quit
;; - compiled exe:
;;     * custom icon (same as trayicon)
;; - For each game, custom pictures for use as bars (left/right or up/down of game window)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (for other helper functions)
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
  StringObj := "{"

  EnumObj := obj.OwnProps()

  EnumObj.Call(&name, &value)
  StringObj .= Inspect(name) ": " Inspect(value)

  for name, value in EnumObj
    StringObj .= ", " name ": " value

  StringObj .= "}"

  return StringObj
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

  if EnumObj.Call(&key, &value)
  {
    StringObj .= Inspect(key) "," Inspect(value)

    while EnumObj.Call(&key, &value)
      StringObj .= ", " Inspect(key) "," Inspect(value)
  }

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

;; For each element e: Run func(e, args*)
Array.DefineFunc("Each", __Array_Each)
__Array_Each(ArrayObj, func, args*)
{
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    FuncObj(ArrayObj[A_Index], args*)
  }
  return ArrayObj
}

;; For each key/value pair: Run func([key, value], args*)
Map.DefineFunc("Each", __Map_Each)
__Map_Each(MapObj, func, args*)
{
  for key, value in MapObj
  {
    key_val := [key, value]
    FuncObj := __FuncHandler(key_val, func)
    FuncObj(key_val, args*)
  }
  return MapObj
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

;; New map where each map[key] := func([key, value], args*)
Map.DefineFunc("Collect", __Map_Collect)
__Map_Collect(MapObj, func, args*)
{
  NewMapObj := Map()
  for key, value in MapObj
  {
    key_val := [key, value]
    FuncObj := __FuncHandler(key_val, func)
    NewMapObj[key] := FuncObj(key_val, args*)
  }
  return NewMapObj
}

;;
Array.DefineFunc("Inject", __Array_Inject)
__Array_Inject(ArrayObj, init?, func?, args*)
{
  if not IsSet(func)
    Throw "`"Error: Too few parameters passed to function.`""

  EnumeratorObj := ArrayObj.__Enum()

  if IsSet(init)
    result := init
  else
    EnumeratorObj.Call(&result)

  FuncObj := __FuncHandler(result, func)

  while EnumeratorObj.Call(&value)
    result := FuncObj(result, value, args*)

  return result
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

;; Take a sub array from an array.
; Example:
;   [1,2,3,4,5].Slice(2,4)  -> [2,3,4]
;   [1,2,3,4,5].Slice(2,-2) -> [2,3,4]
Array.DefineFunc("Slice", __Array_Slice)
__Array_Slice(ArrayObj, start, end := -1)
{
  NewArrayObj := []

  for arg in [&start, &end] {
    if %arg% < 0
      %arg% += 1 + ArrayObj.Length
    if not (1 <= %arg% && %arg% <= ArrayObj.Length)
      Throw "`"Error: Invalid parameters passed to function.`""
  }

  if not (start <= end)
    Throw "`"Error: Invalid parameters passed to function.`""

  loop end - (start - 1)
    NewArrayObj.Push ArrayObj[ A_Index + (start - 1) ]

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

  EnumObj := ArrayObj.__Enum()

  if EnumObj.Call(&value)
  {
    StringObj .= String(value)

    while EnumObj.Call(&value)
      StringObj .= delimiter String(value)
  }

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

;; Check if a file is encoded in UTF-8
; _file              FileObj or String
; accept_ascii_only  Boolean
FileIsUTF8(_file, accept_ascii_only := true)
{
  if not _file is File
    _file := FileOpen(_file, "r")

  ; Check BOM
  if _file.Encoding = "UTF-8"
    return true
  if _file.Encoding = "UTF-16"
    return false

  ; Helper Function: Read 1 byte from file
  _file.ReadBuffer := Buffer(1)
  _file.ReadByte := ReadByte
  ReadByte(_file, &byte)
  {
    if not _file.RawRead(_file.ReadBuffer, 1)
      return false
    byte := NumGet(_file.ReadBuffer, "UChar")
    return true
  }

  ascii_only := true

  ; Loop implements the following UTF-8 regular expression:
  ;source: https://www.w3.org/International/questions/qa-forms-utf-8
  /*
  /\A(
     [\x00-\x7F]                        # ASCII
   | [\xC2-\xDF][\x80-\xBF]             # non-overlong 2-byte
   |  \xE0[\xA0-\xBF][\x80-\xBF]        # excluding overlongs
   | [\xE1-\xEC\xEE\xEF][\x80-\xBF]{2}  # straight 3-byte
   |  \xED[\x80-\x9F][\x80-\xBF]        # excluding surrogates
   |  \xF0[\x90-\xBF][\x80-\xBF]{2}     # planes 1-3
   | [\xF1-\xF3][\x80-\xBF]{3}          # planes 4-15
   |  \xF4[\x80-\x8F][\x80-\xBF]{2}     # plane 16
  )*\z/x;
  */
  while not _file.AtEOF
  {
    if not _file.ReadByte(&b1)
      return false
    if(0x00<=b1&&b1<=0x7F)  ; ASCII
      continue

    ascii_only := false

    if not _file.ReadByte(&b2)
      return false
    if(0xC2<=b1&&b1<=0xDF)&&(0x80<=b2&&b2<=0xBF)  ; non-overlong 2-byte
      continue

    if not _file.ReadByte(&b3)
      return false
    if(b1=0xE0)&&(0xA0<=b2&&b2<=0xBF)&&(0x80<=b3&&b3<=0xBF)                               ; excluding overlongs
    ||(0xE1<=b1&&b1<=0xEC||b1=0xEE||b1=0xEF)&&(0x80<=b2&&b2<=0xBF)&&(0x80<=b3&&b3<=0xBF)  ; straight 3-byte
    ||(b1=0xED)&&(0x80<=b2&&b2<=0x9F)&&(0x80<=b3&&b3<=0xBF)                               ; excluding surrogates
      continue

    if not _file.ReadByte(&b4)
      return false
    if(b1=0xF0)&&(0x90<=b2&&b2<=0xBF)&&(0x80<=b3&&b3<=0xBF)&&(0x80<=b4&&b4<=0xBF)             ; planes 1-3
    ||(0xF1<=b1&&b1<=0xF3)&&(0x80<=b2&&b2<=0xBF)&&(0x80<=b3&&b3<=0xBF)&&(0x80<=b4&&b4<=0xBF)  ; planes 4-15
    ||(b1=0xF4)&&(0x80<=b2&&b2<=0x8F)&&(0x80<=b3&&b3<=0xBF)&&(0x80<=b4&&b4<=0xBF)             ; plane 16
      continue

    return false
  }

  if ascii_only && not accept_ascii_only
    return false

  return true
}

;; Split a command line string into its separate parts
; Example:
;   'cd "C:\Program Files"' -> ["cd", "C:\Program Files"]
SplitCmdString(CmdString)
{
  ArrayObj  := Array()
  StringObj := ""
  inside_quotes := false

  loop Parse Trim(CmdString)
  {
    if A_LoopField = '"' {
      inside_quotes := !inside_quotes
    } else if A_LoopField = ' ' and not inside_quotes {
      if not StringObj.IsEmpty() {
        ArrayObj.Push(StringObj)
        StringObj := ""
      }
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

FindFiles(file_pattern, full_path := false)
{
  files := Array()
  loop Files file_pattern, "F"
    files.push(full_path ? A_LoopFileFullPath : A_LoopFilePath)
  return files
}

ParseAutorunPattern(autorun_pattern)
{
  launch_pattern := unset
  winexe         := ""
  winclass       := ""
  wingrab        := ""
  btnX           := ""
  btnO           := ""
  btn_           := ""

  if not InStr(autorun_pattern, SEP) {
    launch_pattern := autorun_pattern
  } else {
    split := StrSplit(autorun_pattern, SEP, , 2)
    launch_pattern := split[1]
    window_patterns := StrSplit(split[2], SEP)
    window_patterns.Each(GenerateWindowString, &winexe, &winclass, &wingrab, &btnX, &btnO, &btn_)
  }

  if winexe = "ERROR"
    launch_strings := []
  else
    launch_strings := GenerateLaunchStrings(launch_pattern)
                      .Collect(str=>(str ":" winexe ":" winclass ":" wingrab ":" btnX ":" btnO ":" btn_))

  return launch_strings
}

GenerateWindowString(window_pattern, &winexe, &winclass, &wingrab, &btnX, &btnO, &btn_)
{
  if window_pattern ~= "^\s*winexe\s*="
  {
    file_pattern := Trim(StrSplit(window_pattern, "=", , 2)[2])
    files := FindFiles(file_pattern,true)
    file_regexes := files.Collect(str=>RegExReplace(str,"^.*[\\]","\\"))
                         .Collect(str=>StrReplace(str,".","\."))
                         .Join("|")
    winexe := file_regexes.IsEmpty() ? "ERROR" : ("ahk_exe" "(" file_regexes ")$")
  }
  else if window_pattern ~= "^\s*winclass\s*="
  {
    class_regex := Trim(StrSplit(window_pattern, "=", , 2)[2])
    winclass := "ahk_class" "^" class_regex "$"
  }
  else if window_pattern ~= "^\s*wingrab\s*="
  {
    wingrab := Trim(StrSplit(window_pattern, "=", , 2)[2])
  }
  else if window_pattern ~= "^\s*btnX\s*="
  {
    btnX := Trim(StrSplit(window_pattern, "=", , 2)[2])
  }
  else if window_pattern ~= "^\s*btnO\s*="
  {
    btnO := Trim(StrSplit(window_pattern, "=", , 2)[2])
  }
  else if window_pattern ~= "^\s*btn_\s*="
  {
    btn_ := Trim(StrSplit(window_pattern, "=", , 2)[2])
  }
}

GenerateLaunchStrings(launch_pattern)
{
  if launch_pattern.IsEmpty()
    return []

  launch_strings := []

  enum := SplitCmdString(launch_pattern).__Enum()
  enum.Call(&file_pattern)

  if (files := FindFiles(file_pattern), not files.IsEmpty())
  {
    ; First str in launch_pattern is the file to be run
    launch_strings.Push(files)

    while enum.Call(&file_pattern)
    {
      if contains_a_but_not_inbetween_b(file_pattern, a:="*", b:='"') {
        ; wildcard found, treat it as a file
        files := FindFiles(file_pattern)
        launch_strings.Push(files)
      } else {
        ; no wildcard, treat it as normal parameter
        launch_strings.Push([file_pattern])
      }
    }

    if launch_strings.Any(".IsEmpty")
      launch_strings := []
    else if launch_strings.Length = 1
      launch_strings := launch_strings[1]
    else
      launch_strings := launch_strings.Inject(,".Product")
                                      .Collect(".Flatten")
                                      .Collect(".Join", " ")
  }

  return launch_strings
}

contains_a_but_not_inbetween_b(haystack, a, b)
{
  inbetween_b := false
  
  loop parse haystack
  {
    if !inbetween_b && A_LoopField = a
      return true
    else if A_LoopField = b
      inbetween_b := !inbetween_b
  }

  return false
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (fullscreen)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetActiveMonitorSize()
{
  monitor := 0

  ; Coordinates - Method 1
  CoordMode("Mouse", "Screen")
  MouseGetPos(&x, &y)  ; Get x y coordinates of mouse pointer

  ; Coordinates - Method 2
  ;active_hwnd := WinExist("A")  ; Get the window that is currently in focus
  ;WinGetPos(&x, &y, , , active_hwnd)  ; Get x y coordinates of window upper left corner

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
    win_width := Round((screen_size.height / app_height) * app_width)
    win_height := screen_size.height
    win_x := Round(screen_size.x + ((screen_size.width - win_width) / 2))
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
    win_height := Round((screen_size.width / app_width) * app_height)
    win_x := screen_size.x
    win_y := Round(screen_size.y + ((screen_size.height - win_height) / 2))

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
  ; Even without borders, the app window can be moved by shift-left click on the app icon in the taskbar.
  ; When moving the app window between monitors, somethimes the black bars gets slightly misaligned.
  ; This is used to try to prevent this misalignment from happening. Not sure though if it works.
  Sleep(250)

  win_sizes := CalculateCorrectWindowsSizePos(app_hwnd)

  app_size := win_sizes.app_size
  barBL_size := win_sizes.bar_bl_size
  barTR_size := win_sizes.bar_tr_size

  WinMove(app_size.x, app_size.y, app_size.width, app_size.height, app_hwnd)

  ; Bars sometimes gets missing (transparent) pixel rows at the top.
  ; This funky code prevents that for some reason. ¯\_(ツ)_/¯
  barBL.Move(barBL_size.x, barBL_size.y+2, barBL_size.width, barBL_size.height)
  barTR.Move(barTR_size.x, barTR_size.y+2, barTR_size.width, barTR_size.height)
  barBL.Move(barBL_size.x, barBL_size.y,   barBL_size.width, barBL_size.height)
  barTR.Move(barTR_size.x, barTR_size.y,   barTR_size.width, barTR_size.height)

  RepositionXButton(xBtn)

  return app_size
}

RepositionXButton(xBtn)
{
  xBtn.Gui.GetPos(, , &bar_width, &bar_height)
  xBtn_size := CalculateXButtonSize(bar_width, bar_height)
  xBtn.Move(xBtn_size.x, xBtn_size.y, xBtn_size.width, xBtn_size.height)
}

clickArea_reposition(clickArea)
{
  ; Stretch the pixel to fit the whole bar
  clickArea.Gui.GetClientPos(,,&w,&h)
  clickArea.move(0,0,w,h)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Global Variables
; Note: `A_LineFile` is used since it gives same result for: current script, #Include file, compiled file
SCRIPT_NAME := RegexReplace(A_LineFile, "^.*[\\/]|[\.][^\.]*$", "")  ; "some\path\bofuru.ahk" -> "bofuru"
SCRIPT_DIR  := RegexReplace(A_LineFile, "[\\/][^\\/]+$", "")  ; "some\path\bofuru.ahk" -> "some\path"
CONFIG_NAME := SCRIPT_NAME ".ini"
CONFIG_PATH := SCRIPT_DIR "\" CONFIG_NAME
SEP := "|"  ; Separator: Used in the config [autorun] section

;; Transparent Pixel
; This is needed to create clickable areas in GUI windows.
;TODO: Generate pixel in code instead of loading from file
;@Ahk2Exe-IgnoreBegin
pixel := SCRIPT_DIR . "\resourses\transparent_pixel.ico"
;@Ahk2Exe-IgnoreEnd
;@Ahk2Exe-AddResource resourses\transparent_pixel.ico, pixel

;; Ignored Window Classes
IGNORED_CLASSES := [
  ; https://learn.microsoft.com/en-gb/windows/win32/winmsg/about-window-classes?redirectedfrom=MSDN
  "Button",     ; button
  "ComboBox",   ; combo box
  "Edit",       ; edit control
  "ListBox",    ; list box
  "MDIClient",  ; MDI client window
  "ScrollBar",  ; scroll bar
  "Static",     ; static control
  "ComboLBox",  ; list box contained in a combo box
  "DDEMLEvent",
  "Message",    ; message-only window
  "#32768",     ; menu (ex: when you click top left icon in a window title)
  "#32769",     ; desktop window
  "#32770",     ; dialog box
  "#32771",     ; task switch window
  "#32772",     ; icon titles

  ; Misc
  "Progman",  ; Desktop - No wallpaper
  "WorkerW",  ; Desktop - With wallpaper
  "PseudoConsoleWindow",  ; Win11 cmd.exe
]
ahk_class_ignore := Format("ahk_class ^(?!{})", IGNORED_CLASSES.Collect(str => str "$").Join("|"))
;ahk_class_ignore := "ahk_class ^(?!Button$|ComboBox$|Edit$|ListBox$|MDIClient$|ScrollBar$|Static$|ComboLBox$|DDEMLEvent$|Message$|#32768$|#32769$|#32770$|#32771$|#32772$)"



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Config File
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Config File
if FileIsUTF8(CONFIG_PATH, accept_ascii_only := false)
{
  ; IniRead() do not support UTF-8 files
  answer := MsgBox("File " CONFIG_NAME " uses UTF-8 encoding which unfortunately is not supported.`n`nAutomatically convert " CONFIG_NAME " to UTF-16?", , "YesNo")
  if answer != "Yes"
    ExitApp(0)

  config_str := FileRead(CONFIG_PATH, "UTF-8")
  FileDelete(CONFIG_PATH)
  FileAppend(config_str, CONFIG_PATH, "UTF-16")
  config_str := unset
}

launch_string  := IniRead(CONFIG_PATH, "config", "launch", "")
workdir        := IniRead(CONFIG_PATH, "config", "workdir", "")
buttonX        := IniRead(CONFIG_PATH, "config", "btnX", "disable")
buttonO        := IniRead(CONFIG_PATH, "config", "btnO", "disable")
button_        := IniRead(CONFIG_PATH, "config", "btn_", "disable")
winexe         := IniRead(CONFIG_PATH, "config", "winexe", "")
winclass       := IniRead(CONFIG_PATH, "config", "winclass", "")
wingrab        := IniRead(CONFIG_PATH, "config", "wingrab", "instant")
autorun_find   := Array()
autorun_ignore := Array()
window_string  := ""
delay_millisec := 0

loop Parse IniRead(CONFIG_PATH, "autorun"), "`r`n", A_Space A_Tab
{
  if InStr(A_LoopField, SEP)
  && not StrSplit(A_LoopField, SEP).Slice(2).All(RegExMatch, "^\s*btn[XO_]\s*=\s*(disable|enable|hide)\s*$|^\s*(winexe|winclass)\s*=|^\s*wingrab\s*=\s*(instant|waitlauncherquit|waittimesec\(\s*[0-9]+\s*\))\s*$")
  {
    MsgBox "Invalid autorun entry:`n`n" A_LoopField, CONFIG_PATH, "Icon!"
    ExitApp(1)
  }

  if A_LoopField ~= "^!"
    autorun_ignore.Push( SubStr(A_LoopField,2) )
  else
    autorun_find.Push( A_LoopField )
}

for button in [buttonX, buttonO, button_]
{
  if not button ~= "^(disable|enable|hide)$"
  {
    MsgBox "Invalid button setting:`n`n" button, CONFIG_PATH, "Icon!"
    ExitApp(1)
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if workdir
{
  if not FileExist(workdir) ~= "D" {
    MsgBox("Workdir not found:`n`n" workdir, CONFIG_PATH, "Icon!")
    ExitApp(1)
  }
  SetWorkingDir workdir
}

if launch_string.IsEmpty()
{
  autorun_ignore :=
    autorun_ignore.Collect(ParseAutorunPattern)
                  .Flatten()
                  .Collect(str=>StrSplit(str,":",,2)[1])

  autorun_find :=
    autorun_find.Collect(ParseAutorunPattern)
                .Flatten()
                .Reject(str=>autorun_ignore.Contains(StrSplit(str,":",,2)[1]))

  if autorun_find.Has(1) {
    split := StrSplit(autorun_find[1], ":")
    launch_string := split[1]
    winexe   := split[2]
    winclass := split[3]
    wingrab  := split[4]
    btnX     := split[5]
    btnO     := split[6]
    btn_     := split[7]
    split := unset
  }
}

if launch_string.IsEmpty()
{
  MsgBox("Could not find anything to execute.", , "Icon!")
  ExitApp(1)
}

window_string := Trim([winexe, winclass].Join(" "))

if wingrab.IsEmpty()
  wingrab := "instant"  ;TODO: Store default fvalues in only one place

if RegExMatch(wingrab, "^waittimesec\(\s*([0-9]+)\s*\)$", &match)
{
  ; Ex: "waittimesec(5)" -> "waittimesec", 5
  wingrab := "waittimesec"
  delay_millisec := Number(match[1]) * 1000
}

if not btnX
  btnX := "disable"
if not btnO
  btnO := "disable"
if not btn_
  btn_ := "disable"



MsgBox [launch_string,window_string,wingrab,delay_millisec,btnX,btnO,btn_].Inspect()
ExitApp(0)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Run
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Run
; Start app
Run(launch_string, , , &app_pid)

; Find window handle
if window_string
{
  while ProcessExist(app_pid)
    app_hwnd := WinWait(window_string " " ahk_class_ignore, , timeout_sec := 1)
  if not app_hwnd
    ExitApp(0)

  switch wingrab {
  case "waitlauncherquit":
    ProcessWaitClose(app_pid)
  case "waittimesec":
    Sleep(delay_millisec)
  }
}
else
{
  SetTimer(Event_AppExit)
  Event_AppExit()
  {
    if not ProcessExist(app_pid)
      ExitApp(0)
  }
  app_hwnd := WinWait("ahk_pid" app_pid " " ahk_class_ignore)
}

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

; Make app borderless
WinGetClientPos(, , &app_width, &app_height, app_hwnd)  ; Get width/height before removing border
DllCall("SetMenu", "uint", app_hwnd, "uint", 0)  ; Remove menu bar
win_styles := 0x00C00000  ; WS_CAPTION    (title bar)
            | 0x00800000  ; WS_BORDER     (visible border)
            | 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" win_styles, app_hwnd)  ; Remove styles
WinMove(, , app_width, app_height, app_hwnd)  ; Restore width/height

; Activate fullscreen
app_size := ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
barBL.Opt("+AlwaysOnTop")
barTR.Opt("+AlwaysOnTop")
WinSetAlwaysOnTop(true, app_hwnd)
WinMoveTop(barBL.Hwnd)
WinMoveTop(barTR.Hwnd)
WinMoveTop(app_hwnd)
WinActivate(app_hwnd)  ; Focus the app window


;; Misc Event Handlers

; Prevent moving the app window
SetTimer(PreventWindowMove)
PreventWindowMove()
{
  global app_size
  if WinExist(app_hwnd) {
    WinGetClientPos(&app_x, &app_y, , , app_hwnd)
    if app_x != app_size.x || app_y != app_size.y {
      app_size := ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
    }
  }
}

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
    ;if (lParam = app_hwnd)
    ;{
    ;  ; App has moved to another monitor
    ;  ResizeAndPositionWindows(app_hwnd, barBL, barTR, xBtn)
    ;}
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

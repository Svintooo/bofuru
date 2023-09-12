#Requires AutoHotkey v2.0
#WinActivateForce
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
;; - Only use weird fix for transparent pixel rows at top
;;   when it is needed. Scan pixel row and see if it is all black.
;; - create transparent_pixel.ico in code
;;     stop relying on a separate *.ico file.
;; - let config include another config.
;; - make buttons that do not look like shit.
;; - Make configurable what monitor to use.
;; - trayicon:
;;     * custom icon
;;     * custom menu: Show text: "title text of target game window"
;;                    option: move to another monitor
;;                    option: exit and restore window
;;                    option: exit and quit app
;; - compiled exe:
;;     * custom icon (same as trayicon)
;; - For each game, custom pictures for use as bars background (left/right or up/down of app window)



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

  if EnumObj.Call(&name, &value)
  {
    StringObj .= Inspect(name) ": " Inspect(value)

    for name, value in EnumObj
      StringObj .= ", " Inspect(name) ": " Inspect(value)
  }

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
Object.DefineFunc("IsEmpty", __Object_IsEmpty)
__Object_IsEmpty(obj)
{
  return obj.ObjOwnPropCount = 0
}

;; IsBlank
; True if the variable is considered blank.
; True for strings, arrays, maps, and Objects, if they are empty.
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
Object.DefineFunc("IsBlank", __Object_IsBlank)
__Object_IsBlank(obj)
{
  return __Object_IsEmpty(obj)
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
Object.DefineFunc("IsPresent", __Object_IsPresent)
__Object_IsPresent(obj)
{
  return not __Object_IsEmpty(obj)
}

;; Contains
String.DefineFunc("Contains", __String_Contains)
__String_Contains(StringObj, Needle)
{
  return InStr(StringObj, Needle, CaseSense := "On")
}
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
Object.DefineFunc("Contains", __Object_Contains)
__Object_Contains(obj, needle)
{
  for , value in obj.OwnProps
    if value = needle
      return true
  return false
}

;; IsIn
Object.DefineFunc("IsIn", __Object_IsIn)
__Object_IsIn(Obj, collection)
{
  return collection.Contains(Obj)
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

;; Array of all Prop names in an object
Object.DefineFunc("PropNames", __Object_PropNames)
__Object_PropNames(SomeObj)
{
  ArrayObj := Array()

  for name in SomeObj.OwnProps()
    ArrayObj.Push(name)

  return ArrayObj
}

;; Array of all Prop values in an object
Object.DefineFunc("PropValues", __Object_PropValues)
__Object_PropValues(SomeObj)
{
  ArrayObj := Array()
  
  for , value in SomeObj.OwnProps()
    ArrayObj.Push(value)

  return ArrayObj
}

;;
Object.DefineFunc("Tap", __Object_Tap)
__Object_Tap(Obj, func, args*)
{
  FuncObj := __FuncHandler(Obj, func)
  FuncObj(Obj, args*)
  return Obj
}

;;
Object.DefineFunc("YieldSelf", __Object_YieldSelf)
__Object_YieldSelf(Obj, func, args*)
{
  FuncObj := __FuncHandler(Obj, func)
  return FuncObj(Obj, args*)
}

;; True if for all elements e: func(e, args*) => true
Array.DefineFunc("HasAll", __Array_HasAll)
__Array_HasAll(ArrayObj, func, args*)
{
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    if not FuncObj(ArrayObj[A_Index], args*)
      return false
  }
  return true
}

;; True if for all k,v: func({key:k,value:v}, args*) => true
Map.DefineFunc("HasAll", __Map_HasAll)
__Map_HasAll(MapObj, func, args*)
{
  for key, value in MapObj
  {
    FuncObj := __FuncHandler({}, func)
    if not FuncObj(key, value, args*)
      return false
  }
  return true
}

;; True if for all prop n,v: func({name:n,value:v}, args*) => true
Object.DefineFunc("HasAll", __Object_HasAll)
__Object_HasAll(Obj, func, args*)
{
  for name, value in Obj.OwnProps()
  {
    FuncObj := __FuncHandler({}, func)
    if not FuncObj(name, value, args*)
      return false
  }
  return true
}

;; True if for any element e: func(e, args*) => true
Array.DefineFunc("HasAny", __Array_HasAny)
__Array_HasAny(ArrayObj, func, args*)
{
  loop ArrayObj.Length
  {
    FuncObj := __FuncHandler(ArrayObj[A_Index], func)
    if FuncObj(ArrayObj[A_Index], args*)
      return true
  }
  return false
}

;; True if for any k,v: func({key:k,value:v}, args*) => true
Map.DefineFunc("HasAny", __Map_HasAny)
__Map_HasAny(MapObj, func, args*)
{
  for key, value in MapObj
  {
    FuncObj := __FuncHandler({}, func)
    if FuncObj(key, value, args*)
      return true
  }
  return false
}

;; True if for any prop n,v: func({name:n,value:v}, args*) => true
Object.DefineFunc("HasAny", __Object_HasAny)
__Object_HasAny(Obj, func, args*)
{
  for name, value in Obj.OwnProps()
  {
    FuncObj := __FuncHandler({}, func)
    if FuncObj(name, value, args*)
      return true
  }
  return false
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
    key_val := {key:key, value:value}
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
    throw "`"Error: Too few parameters passed to function.`""

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

;;
Map.DefineFunc("Inject", __Map_Inject)
__Map_Inject(MapObj, init?, func?, args*)
{
  if not IsSet(func)
    throw "`"Error: Too few parameters passed to function.`""

  EnumeratorObj := MapObj.__Enum()

  if IsSet(init) {
    result := init
  } else {
    EnumeratorObj.Call(&key, &value)
    result := {key:key, value:value}
  }

  FuncObj := __FuncHandler(result, func)

  while EnumeratorObj.Call(&key, &value)
    result := FuncObj(result, {key:key, value:value}, args*)

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
; Is meant to mimic `arr[n..m]` from other languages.
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
      throw "`"Error: Invalid parameters passed to function.`""
  }

  if not (start <= end)
    throw "`"Error: Invalid parameters passed to function.`""

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

;;
;
String.DefineFunc("StrReplace", __String_StrReplace)
__String_StrReplace(StringObj, Needle, ReplaceText?, CaseSense?, &OutputVarCount?, Limit?)
{
  return StrReplace(StringObj, Needle, ReplaceText?, CaseSense?, &OutputVarCount?, Limit?)
}

;;
;
String.DefineFunc("RegExReplace", __String_RegExReplace)
__String_RegExReplace(StringObj, NeedleRegEx ,Replacement?, &OutputVarCount?, Limit?, StartingPos?)
{
  return RegExReplace(StringObj, NeedleRegEx ,Replacement?, &OutputVarCount?, Limit?, StartingPos?)
}

;; Trim a string
; Example:
;   "  asdf ".Trim() -> "asdf"
String.DefineFunc("Trim", __String_Trim)
__String_Trim(StringObj, OmitChars?)
{
  return Trim(StringObj, OmitChars?)
}

;; Left trim a string
; Example:
;   "  asdf ".Trim() -> "asdf "
String.DefineFunc("LTrim", __String_LTrim)
__String_LTrim(StringObj, OmitChars?)
{
  return LTrim(StringObj, OmitChars?)
}

;; Right trim a string
; Example:
;   "  asdf ".Trim() -> "  asdf"
String.DefineFunc("RTrim", __String_RTrim)
__String_RTrim(StringObj, OmitChars?)
{
  return RTrim(StringObj, OmitChars?)
}

;; Split a string into an array
; Example:
;   "1|2|3.3|444".Split("|") -> [1,2,3.3,"444"]
String.DefineFunc("Split", __String_Split)
__String_Split(StringObj, Delimiters?, OmitChars?, MaxParts?)
{
  return StrSplit(StringObj, Delimiters?, OmitChars?, MaxParts?)
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
; Examples:
;   [ "a", ["b", ["c"]] ].Flatten()  -> [ "a", "b",  "c"  ]
;   [ "a", ["b", ["c"]] ].Flatten(1) -> [ "a", "b", ["c"] ]
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

;; Assigns array values to variables.
; Example:
;   arr := ["a", "b"]
;   arr.Assign(&x, &y)
; Same as:
;   arr := ["a", "b"]
;   x := arr[1]
;   y := arr[2]
Array.DefineFunc("Assign", __Array_Assign)
__Array_Assign(ArrayObj, VarRefs*)
{
  for i, VarRef in VarRefs
  {
    if ArrayObj.Has(i)
      %VarRef% := ArrayObj[i]
  }
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (initialization)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; URL: https://github.com/buliasz/AHKv2-Gdip
;#Include Gdip_All.ahk
;GenerateTransparentPixel()
;{
;  If !pToken := Gdip_Startup()
;    Abort("Gdiplus failed to start. Please ensure you have gdiplus on your system")
;  pBitmap   := Gdip_CreateBitmap(Width:=1, Height:=1, _Format:=0x26200A)
;  ;pGraphics := Gdip_GraphicsFromImage(pBitmap)
;  ;pBrush    := Gdip_BrushCreateSolid(ARGB:=0x00000000)
;  ;Region    := Gdip_GetClipRegion(pGraphics)
;  ;Gdip_FillRegion(pGraphics, pBrush, Region)  ; Not needed. Pixel seems to be transparent by default.
;  hIcon     := Gdip_CreateHICONFromBitmap(pBitmap)
;  ;Gdip_DeleteRegion(Region)
;  ;Gdip_DeleteBrush(pBrush)
;  ;Gdip_DeleteGraphics(pGraphics)
;  Gdip_DisposeImage(pBitmap)
;  Gdip_Shutdown(pToken)
;  return "HICON:" hIcon
;}

;; Create a transparent pixel 
; THANK YOU SO MUCH AHKv2-Gdip!
; URL: https://github.com/buliasz/AHKv2-Gdip
; I could not have figured out this code without you.
GenerateTransparentPixel()
{
  ;If !pToken := Gdip_Startup()
  ;  Abort("GDI+ failed to start. Please ensure you have GDI+ on your system")
  if (!DllCall("LoadLibrary", "str", "gdiplus", "UPtr"))
    Abort("FATAL ERROR: Could not load GDI+ library.")
  si := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
  NumPut("UInt", 1, si)
  DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken:=0, "UPtr", si.Ptr, "UPtr", 0)
  if (!pToken)
    Abort("FATAL ERROR: GDI+ failed to start. Please ensure you have GDI+ on your system.")

  ;pBitmap := Gdip_CreateBitmap(Width:=1, Height:=1, _Format:=0x26200A)
  DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Width:=1, "Int", Height:=1, "Int", 0, "Int", _Format:=0x26200A, "UPtr", 0, "UPtr*", &pBitmap:=0)

  ;NOTE: Pixel seems to be transparent by default. No need to paint the pixel.

  ;hIcon := Gdip_CreateHICONFromBitmap(pBitmap)
  DllCall("gdiplus\GdipCreateHICONFromBitmap", "UPtr", pBitmap, "UPtr*", &hIcon:=0)

  ;Gdip_DisposeImage(pBitmap)
  DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)

  ;Gdip_Shutdown(pToken)
  DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
  hModule := DllCall("GetModuleHandle", "str", "gdiplus", "UPtr")
  if (!hModule)
    Abort("FATAL ERROR: GDI+ library already unloaded.")
  if (!DllCall("FreeLibrary", "UPtr", hModule))
    Abort("FATAL ERROR: Could not free GDI+ library.")

  ; return
  return "HICON:" hIcon
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions (setup)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Show error message, and then exit
Abort(message)
{
  static WS_EX_TOPMOST := "0x40000"  ; Always On Top
  MsgBox message, , "Icon! " WS_EX_TOPMOST
  ExitApp(0)
}

;; Make RegEx treat all characters in StringObj as literal.
; ref: https://www.autohotkey.com/docs/v2/misc/RegEx-QuickRef.htm#fundamentals
RegExEscape(StringObj)
{
  result := unset

  if InStr(StringObj,"\E")
    result := RegExReplace(StringObj, "([\\.*?+[{|()^$])", "\$1")
  else
    result := "\Q" StringObj "\E"

  return result
}

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

  ; ReadByte: Function that reads from file one byte at a time
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
;   'file.exe /flag1 -flag2 "value one" --flag3 "value two"' -> ["some\file.exe" "/flag1" "-flag2" "value one" "--flag3" "value two"]
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

contains_x_but_not_inbetween_y(haystack, x, y)
{
  inbetween_y := false
  
  loop parse haystack
  {
    if !inbetween_y && A_LoopField ~= "[" x "]"
      return true
    else if A_LoopField = y
      inbetween_y := !inbetween_y
  }

  return false
}

FindFiles(file_pattern, relative_path := false)
{
  files := Array()

  loop Files file_pattern, "F"
  {
    if A_LoopFileAttrib.Contains("S")  ; Skip system files
      continue
    files.push(relative_path ? A_LoopFilePath : A_LoopFileFullPath)
  }

  return files
}

FindDirectories(file_pattern, relative_path := false)
{
  files := Array()

  loop Files file_pattern, "D"
    files.push(relative_path ? A_LoopFilePath : A_LoopFileFullPath)

  return files
}

;; Check if setting name is permitted, and if setting value is valid
CheckSetting(name, value?)
{
  result := unset

  switch name
  {
  case "launch":
    result := true
  case "launchdir":
    result := true
  case "autorundir":
    result := true
  case "buttons":
    result := IsSet(value) ? ["show", "hide", "slide"].Contains(value) : true
  case "btnX", "btnO", "btn_":
    result := IsSet(value) ? ["enable", "disable"].Contains(value) : true
  case "winexe":
    result := true
  case "winclass":
    result := true
  case "wingrab":
    result := IsSet(value) ? ["instant","waitlauncherquit","waittimesec\(\s*[0-9]+\s*\)"].HasAny(regex => value ~= "^" regex "$") : true
  default:
    result := false
  }

  return result
}

;; Match launch pattern against files on disk
; Examples:
;   "folder\game_*.exe" -> ["folder\game_A.exe", "folder\game_B.exe"]
;   "cheat.exe --godmode *.exe" -> ["cheat.exe --godmode some_game.exe", "cheat.exe --godmode another_game.exe"]
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
    launch_strings.Push files.Collect(str => '"' str '"')

    while enum.Call(&str)
    {
      if contains_x_but_not_inbetween_y(str, x:="*?", y:='"') {
        ; wildcard found, treat str as a file pattern
        files := FindFiles(str)
        launch_strings.Push files.Collect(str => '"' str '"')
      } else {
        ; no wildcard, treat str as a normal parameter
        launch_strings.Push([str])
      }
    }

    if launch_strings.HasAny(".IsEmpty")
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
    width:  Abs(monitor.x2 - monitor.x1),
    height: Abs(monitor.y2 - monitor.y1),
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
    win_x := Round(screen_size.x + (Abs(screen_size.width - win_width) / 2))
    win_y := screen_size.y

    barBL_x := screen_size.x
    barBL_y := screen_size.y
    barBL_width := Abs(win_x - screen_size.x)
    barBL_height := screen_size.height

    barTR_x := win_x + win_width
    barTR_y := screen_size.y
    barTR_width := Abs(screen_size.width - barBL_width - win_width)
    barTR_height := screen_size.height
  }
  else
  {
    win_width := screen_size.width
    win_height := Round((screen_size.width / app_width) * app_height)
    win_x := screen_size.x
    win_y := Round(screen_size.y + (Abs(screen_size.height - win_height) / 2))

    barTR_x := screen_size.x
    barTR_y := screen_size.y
    barTR_width := screen_size.width
    barTR_height := Abs(win_y - screen_size.y)

    barBL_x := screen_size.x
    barBL_y := win_y + win_height
    barBL_width := screen_size.width
    barBL_height := Abs(screen_size.height - barTR_height - win_height)
  }

  size_pos := {
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

  return size_pos
}

ResizeAndPositionWindows(fscr)
{
  ; Even without borders, the app window can be moved by shift-left click on the app icon in the taskbar.
  ; When moving the app window between monitors, somethimes the black bars gets slightly misaligned.
  ; This is used to try to prevent this misalignment from happening. Not sure though if it works.
  Sleep(250)

  win_sizes := CalculateCorrectWindowsSizePos(fscr.app_hwnd)

  app_size := win_sizes.app_size
  barBL_size := win_sizes.bar_bl_size
  barTR_size := win_sizes.bar_tr_size

  WinMove(app_size.x, app_size.y, app_size.width, app_size.height, fscr.app_hwnd)

  ; Bars sometimes gets missing (transparent) pixel rows at the top.
  ; This funky code prevents that for some reason. ¯\_(ツ)_/¯
  WinMove(barBL_size.x, barBL_size.y+2, barBL_size.width, barBL_size.height, fscr.barBL.hwnd)
  WinMove(barTR_size.x, barTR_size.y+2, barTR_size.width, barTR_size.height, fscr.barTR.hwnd)
  WinMove(barBL_size.x, barBL_size.y  , barBL_size.width, barBL_size.height, fscr.barBL.hwnd)
  WinMove(barTR_size.x, barTR_size.y  , barTR_size.width, barTR_size.height, fscr.barTR.hwnd)

  if fscr.HasOwnProp("buttonX")
    RepositionButtons(fscr)

  ; Windows sometimes do not like the size/position we set, so it changes them.
  ; This code tries to fetch the actual size/position of the window.
  Sleep(250)
  WinGetPos(&x, &y, &width, &height, fscr.app_hwnd)
  actual_app_size := {x: x, y: y, width: width, height: height}

  return actual_app_size
}

RepositionButtons(fscr)
{
  fscr.buttonX.Gui.GetPos(, , &bar_width, &bar_height)
  buttons := CalculateButtonsSizes(bar_width, bar_height)
  fscr.buttonX.Move(buttons.X.x, buttons.X.y, buttons.X.width, buttons.X.height)
  fscr.buttonO.Move(buttons.O.x, buttons.O.y, buttons.O.width, buttons.O.height)
  fscr.button_.Move(buttons._.x, buttons._.y, buttons._.width, buttons._.height)
}

CalculateButtonsSizes(bar_width, bar_height)
{
  static btn_width := 30 ;TODO: Make configurable
  static btn_height := 30 ;TODO: Make configurable
  static btn_spacing := 2 ;TODO: Make configurable

  buttons_sizes :=  {
    X: {
      x: bar_width - 1*(btn_width + btn_spacing),
      y: btn_spacing,
      width: btn_width,
      height: btn_height,
    },
    O: {
      x: bar_width - 2*(btn_width + btn_spacing),
      y: btn_spacing,
      width: btn_width,
      height: btn_height,
    },
    _: {
      x: bar_width - 3*(btn_width + btn_spacing),
      y: btn_spacing,
      width: btn_width,
      height: btn_height,
    },
  }

  return buttons_sizes
}

clickArea_reposition(clickArea)
{
  ; Stretch the pixel to fit the whole bar
  clickArea.Gui.GetClientPos(,,&w,&h)
  clickArea.move(0,0,w,h)
}

ExitFullScreen(fscr)
{
  ; Stop preventing moving the app window
  PreventWindowMove_Unregister()

  ; Stop re:fullscreening the app window when moved to another monitor
  ShellMessage_Unregister()

  ; Hide borders
  fscr.barBL.Hide()
  fscr.barTR.Hide()

  ; Restore window border
  WinSetStyle(fscr.app_origstyle, fscr.app_hwnd)

  ; Restore window menu bar
  if fscr.app_origmenu
    DllCall("SetMenu", "uint", fscr.app_hwnd, "uint", fscr.app_origmenu)

  ; Restore window size and position
  win_x      := fscr.app_origpos.x
  win_y      := fscr.app_origpos.y
  win_width  := fscr.app_origpos.width
  win_height := fscr.app_origpos.height
  WinMove(win_x, win_y, win_width, win_height, fscr.app_hwnd)
}



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Misc
; Note: `A_LineFile` is used since it gives same result for: current script, #Include file, compiled file
SplitPath(A_LineFile, , &SCRIPT_DIR, , &SCRIPT_NAME, )  ; "some\path\bofuru.ahk" -> "some\path" "bofuru"
CONFIG_NAME := SCRIPT_NAME ".conf"
CONFIG_PATH := SCRIPT_DIR "\" CONFIG_NAME

;; Transparent Pixel
; This is needed to create clickable areas in GUI windows.
PIXEL := GenerateTransparentPixel()

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
; This is the reason why script uses: SetTitleMatchMode "RegEx"
AHK_CLASS_IGNORE := Format("ahk_class ^(?!{})", IGNORED_CLASSES.Collect(str => str "$").Join("|"))

;; Config Variables
cnfg := {}
cnfg.launch         := ""
cnfg.launchdir      := A_WorkingDir
cnfg.autorundir     := A_WorkingDir
cnfg.buttons        := "hide"
cnfg.btnX           := "enable"
cnfg.btnO           := "enable"
cnfg.btn_           := "enable"
cnfg.winexe         := ""
cnfg.winclass       := ""
cnfg.wingrab        := "instant"
cnfg.window_string  := ""
cnfg.delay_millisec := 0
;
cnfg_args   := {}
cnfg_config := {}
autoruns        := []
autoruns_ignore := []

;; Fullscreen Variables
fscr := {}
fscr.app_pid       := unset
fscr.app_hwnd      := unset
fscr.app_pos       := unset
fscr.app_origpos   := unset
fscr.app_origstyle := unset
fscr.app_origmenu  := unset
fscr.barBL         := unset
fscr.barTR         := unset
fscr.buttonX       := unset
fscr.buttonO       := unset
fscr.button_       := unset



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Config
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Script Arguments ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Parse all "--name value" and "--name=value" upto the first non "--*" arg.
; The remaining args are treated as a launch_string.
; Example:
;   bofuru.ahk [bofuru args] game.exe [game args]
; Each arg in [bofuru args] are parsed separately.
; "game.exe [game args]" is treated as one big launch_string arg.
if not A_Args.IsEmpty()
{
  i := 0
  while (i += 1, i <= A_Args.Length)
  {
    ; Get name and value
    if RegExMatch(A_Args[i], "^--(.+?)=(.+)", &match) {
      arg_str := A_Args[i]
      name  := match[1].Trim()
      value := match[2].Trim()
    } else if RegExMatch(A_Args[i], "^--(.+)", &match) {
      arg_str := A_Args[i] " " A_Args[i+1]
      name  := match[1].Trim()
      value := A_Args[i+1].Trim()
      i += 1
    } else {
      if A_Args[i] = "--"
        i += 1
      name := "launch"
      value := A_Args.Slice(i)
                     .Collect(arg => (arg ~= "\s" ? '"' arg '"' : arg))
                     .Join(" ")
      i := A_Args.Length  ; Make this loop iteration the last one
    }

    ; Verify name and value
    if not CheckSetting(name)
      Abort("Invalid argument:`n`n" arg_str)
    if not CheckSetting(name, value)
      Abort("Cannot use argument value: " value "`n`n" arg_str)

    ; Store name and value
    cnfg_args.%name% := value
  }
}

; Config File
if FileExist(CONFIG_PATH) ~= "^[^D]+$"  ; If config file exists
{
  ; Detect UTF-8
  if FileIsUTF8(CONFIG_PATH, accept_ascii_only := false)
  {
    ; IniRead() do unfortunately not support UTF-8 files
    answer := MsgBox("File " CONFIG_NAME " uses UTF-8 encoding which unfortunately is not supported.`n`nAutomatically convert " CONFIG_NAME " to UTF-16?", , "YesNo")
    if answer != "Yes"
      ExitApp(0)

    ; Convert file to UTF-16
    config_str := FileRead(CONFIG_PATH, "UTF-8")
    FileDelete(CONFIG_PATH)
    FileAppend(config_str, CONFIG_PATH, "UTF-16")
    config_str := unset
  }

  ;; Config File ([config]) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Parses all "name = value" lines in the [config] section.
  if IniRead(CONFIG_PATH).Split(["`r","`n"]).Contains("config")
  {
    loop Parse IniRead(CONFIG_PATH, "config"), "`r`n", A_Space A_Tab
    {
      config_line := A_LoopField

      if not config_line.Contains("=")
        Abort(CONFIG_PATH "`n`nInvalid config entry:`n`n" config_line)
      
      ; Get name and value
      config_line.Split("=", , 2).Collect(".Trim").Assign(&name, &value)

      ; Verify name and value
      if not CheckSetting(name)
        Abort(CONFIG_PATH "`n`nInvalid config name: " name "`n`n" config_line)
      if not CheckSetting(name, value)
        Abort(CONFIG_PATH "`n`nInvalid config value: " value "`n`n" config_line)

      ; Store name and value
      cnfg_config.%name% := value
    }
  }

  ;; Config File ([autorun]) ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Parses all "file.exe|name=val|name=val" lines in the [autorun] section.
  if IniRead(CONFIG_PATH).Split(["`r","`n"]).Contains("autorun")
  {
    loop Parse IniRead(CONFIG_PATH, "autorun"), "`r`n", A_Space A_Tab
    {
      if A_LoopField ~= "^!" {
        if A_LoopField.Contains("|")
          Abort(CONFIG_PATH "`n`nInvalid autorun ignore entry:`n`n" A_LoopField)
        launch_pattern := SubStr(A_LoopField, 2)  ; "!file_pat*ern.exe" -> "file_pat*ern.exe"
        autoruns_ignore.Push(launch_pattern)
        continue  ;NOTE
      }

      autorun_line := A_LoopField
      autorun_cnfg := {}

      for name_value in ("launch=" autorun_line).Split("|")
      {
        if not name_value.Contains("=")
          Abort(CONFIG_PATH "`n`nInvalid autorun entry:`n`n" autorun_line)

        ; Get name and value
        name_value.Split("=", , 2).Collect(".Trim").Assign(&name, &value)

        ; Verify name and value
        if not CheckSetting(name) or name = "autorundir"
          Abort(CONFIG_PATH "`n`nInvalid autorun config name: " name "`n`n" autorun_line)
        if not CheckSetting(name, value)
          Abort(CONFIG_PATH "`n`nInvalid config value: " value "`n`n" autorun_line)

        ; Store name and value
        autorun_cnfg.%name% := value
      }

      autoruns.Push(autorun_cnfg)
    }
  }
}

;DEBUG
;MsgBox cnfg_args.Inspect()
;MsgBox cnfg_config.Inspect()
;MsgBox autoruns.Inspect()
;MsgBox autoruns_ignore.Inspect()
;ExitApp(0)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Apply cnfg_config to cnfg
for name, value in cnfg_config.OwnProps()
  cnfg.%name% := value

; Apply cnfg_args to cnfg
for name, value in cnfg_args.OwnProps()
  cnfg.%name% := value

; Launch string exists
if cnfg.launch
{
  if cnfg.winexe
    cnfg.winexe := "^" RegExEscape(cnfg.winexe) "$"

  if cnfg.winclass
    cnfg.winclass := "^" RegExEscape(cnfg.winclass) "$"
}

; Try finding a working launch string in autoruns
else
{
  ; Set Autorun Working Directory
  if cnfg.autorundir != A_WorkingDir
  {
    if not FileExist(cnfg.autorundir) ~= "D"  ; If directory does not exist
      Abort("Autorun Directory not found:`n`n" cnfg.autorundir)
    SetWorkingDir cnfg.autorundir
    cnfg.launchdir := cnfg.autorundir
  }

  ; Find all files that should be rejected by autorun (not launched)
  autoruns_ignore := autoruns_ignore.Collect(GenerateLaunchStrings).Flatten()

  ; Find all usable autoruns
  usable_autoruns := []
  for autorun_cnfg in autoruns
  {
    launch_strings := GenerateLaunchStrings(autorun_cnfg.launch)
    launch_strings.Collect( str => autorun_cnfg.Clone().Tap(a_cnfg => a_cnfg.launch := str) )
                  .Reject( a_cnfg => autoruns_ignore.Contains(a_cnfg.launch) )
                  .Select( a_cnfg => !a_cnfg.HasOwnProp("launchdir") || FileExist(a_cnfg.launchdir) ~= "[D]" )
                  .Each(a_cnfg => usable_autoruns.Push(a_cnfg))
  }

  if not usable_autoruns.IsEmpty()
  {
    autorun_cnfg := usable_autoruns[1]

    if autorun_cnfg.HasOwnProp("winexe") {
      files := FindFiles(autorun_cnfg.winexe)
      files_regex := files.Collect(RegExReplace, "^.*\\", "\")
                          .Collect(RegExEscape)
                          .Join("|")
      autorun_cnfg.winexe := (files_regex ? "(" files_regex ")$" : "")
    }

    if autorun_cnfg.HasOwnProp("winclass") {
      class_regex := RegExEscape(autorun_cnfg.winclass)
      autorun_cnfg.winclass := (class_regex ? "^" class_regex "$" : "")
    }

    ; Apply autorun config to cnfg
    for name, value in autorun_cnfg.OwnProps()
      cnfg.%name% := value
  }
}

if cnfg.launch.IsEmpty()
  Abort("Could not find anything to execute.")

; Set working directory
if cnfg.launchdir != A_WorkingDir
{
  if not FileExist(cnfg.launchdir) ~= "D"  ; If directory does not exist
    Abort("Launchdir not found:`n`n" cnfg.launchdir)
  SetWorkingDir cnfg.launchdir
}

; Create window string
{
  if cnfg.winexe
    cnfg.winexe := "ahk_exe" cnfg.winexe

  if cnfg.winclass
    cnfg.winclass := "ahk_class" cnfg.winclass

  cnfg.window_string := Trim(cnfg.winexe " " cnfg.winclass)
}

; Parse wingrab "waittimesec()"
if RegExMatch(cnfg.wingrab, "waittimesec\((.+)\)", &match)
{
  ; Ex: "waittimesec(5)" -> "waittimesec", 5
  cnfg.wingrab := "waittimesec"
  cnfg.delay_millisec := Number(match[1]) * 1000
}

;DEBUG
;MsgBox cnfg.Inspect()
;ExitApp(0)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fullscreen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Run
; Start app
try {
  Run(cnfg.launch, , , &app_pid)
  fscr.app_pid := app_pid
  app_pid := unset
} catch {
  Abort("Failed to launch:`n`n" cnfg.launch)
}

; Find window handle
if cnfg.window_string
{
  while ProcessExist(fscr.app_pid)
    fscr.app_hwnd := WinWait(cnfg.window_string " " AHK_CLASS_IGNORE, , timeout_sec := 1)
  if not fscr.app_hwnd
    ExitApp(0)

  ; Win Grab method
  switch cnfg.wingrab
  {
  case "waitlauncherquit":
    ProcessWaitClose(fscr.app_pid)
  case "waittimesec":
    Sleep(cnfg.delay_millisec)
  }
}
else
{
  ; Timer makes sure we exit when app is gone
  SetTimer(Event_AppExit)
  Event_AppExit()
  {
    if not ProcessExist(fscr.app_pid)
      ExitApp(0)
  }

  ; Wait forever for the app window to appear
  fscr.app_hwnd := WinWait("ahk_pid" fscr.app_pid " " AHK_CLASS_IGNORE)

  ; Win Grab method
  switch cnfg.wingrab
  {
  case "waitlauncherquit":
    ProcessWaitClose(fscr.app_pid)
  case "waittimesec":
    Sleep(cnfg.delay_millisec)
  }
}

; Create black bars
fscr.barBL := Gui("+ToolWindow -Caption")  ; Bar at Bottom Left
fscr.barTR := Gui("+ToolWindow -Caption")  ; Bar at Top Right
fscr.barBL.BackColor := "Black"
fscr.barTR.BackColor := "Black"
fscr.barBL.Show("W0 H0")  ; Initially hidden by setting width/height to 0
fscr.barTR.Show("W0 H0")  ; Initially hidden by setting width/height to 0
fscr.barBL.OnEvent("Size", EventBarBLSize)
fscr.barTR.OnEvent("Size", EventBarTRSize)
EventBarBLSize(*)
{
  clickArea_reposition(fscr.barBL.clickArea) ;PIXEL
}
EventBarTRSize(*)
{
  clickArea_reposition(fscr.barTR.clickArea) ;PIXEL
  if fscr.HasOwnProp("buttonX")
    RepositionButtons(fscr)
}

; Create exit button
if cnfg.buttons != "hide"
{
  fscr.buttonX := fscr.barTR.Add("Button", "", "X")
  fscr.buttonO := fscr.barTR.Add("Button", "", "[ ]") ;▢O[]
  fscr.button_ := fscr.barTR.Add("Button", "", "—")
  for C in ["X", "O", "_"]
  {
    fscr.button%C%.OnEvent("Click",       EventButton%C%Click)
    fscr.button%C%.OnEvent("DoubleClick", EventButton%C%Click)
    if cnfg.btn%C% = "disable"
      fscr.button%C%.Enabled := false

    fscr.button_.Enabled := false ;TODO: Implement click event
  }
  EventButtonXClick(*)
  {
    WinClose(fscr.app_hwnd)
  }
  EventButtonOClick(*)
  {
    ExitFullScreen(fscr)
    ExitApp(0)
  }
  EventButton_Click(*)
  {
    ;TODO: Minimize app, hide borders
    ;      When app window is restored, also restore borders
  }
}

; Make mouse clicks on the bars return focus to the app
WS_CLIPSIBLINGS := 0x4000000  ; This will let pictures be both clickable,
                              ; and have other elements placed on top of them.
fscr.barBL.clickArea := fscr.barBL.Add("Picture", WS_CLIPSIBLINGS, PIXEL)
fscr.barTR.clickArea := fscr.barTR.Add("Picture", WS_CLIPSIBLINGS, PIXEL)
fscr.barBL.clickArea.OnEvent("Click", event_clickArea_click)
fscr.barTR.clickArea.OnEvent("Click", event_clickArea_click)
fscr.barBL.clickArea.OnEvent("DoubleClick", event_clickArea_click)
fscr.barTR.clickArea.OnEvent("DoubleClick", event_clickArea_click)
event_clickArea_click(*)
{
  WinActivate(fscr.app_hwnd)  ; Hand focus back to the app
}

; Make app borderless
; Fetch current window settings
WinGetPos(&x, &y, &width, &height, fscr.app_hwnd)  ; Get original window size/position
fscr.app_origpos := {x: x, y: y, width: width, height: height}, x:=y:=width:=height:=unset
WinGetClientPos(, , &app_width, &app_height, fscr.app_hwnd)  ; Get client area width/height
fscr.app_origstyle := WinGetStyle(fscr.app_hwnd)  ; Get original window styles
fscr.app_origmenu := DllCall("User32.dll\GetMenu", "Ptr", fscr.app_hwnd, "Ptr")
; Modify window
if fscr.app_origmenu
  DllCall("SetMenu", "uint", fscr.app_hwnd, "uint", 0)  ; Remove menu bar
win_styles := 0x00C00000  ; WS_CAPTION    (title bar)
            | 0x00800000  ; WS_BORDER     (visible border)
            | 0x00040000  ; WS_THICKFRAME (dragable border)
WinSetStyle("-" win_styles, fscr.app_hwnd)  ; Remove styles
WinMove(, , app_width, app_height, fscr.app_hwnd)  ; Restore width/height
app_width := app_height := unset

; Activate fullscreen
fscr.app_pos := ResizeAndPositionWindows(fscr)
fscr.barBL.Opt("+AlwaysOnTop")
fscr.barTR.Opt("+AlwaysOnTop")
WinSetAlwaysOnTop(true, fscr.app_hwnd)
WinMoveTop(fscr.barBL.Hwnd)
WinMoveTop(fscr.barTR.Hwnd)
WinMoveTop(fscr.app_hwnd)
WinActivate(fscr.app_hwnd)  ; Focus the app window


;; Misc Event Handlers

; Prevent moving the app window
;TODO: Let user move window.
;      When moved, show button that moves window back when clicked.
;      OR: Snap window back to place.
SetTimer(PreventWindowMove)
PreventWindowMove_Unregister()
{
  SetTimer(PreventWindowMove, 0)
}
PreventWindowMove()
{
  if WinExist(fscr.app_hwnd) {
    WinGetClientPos(&app_x, &app_y, , , fscr.app_hwnd)
    if app_x != fscr.app_pos.x || app_y != fscr.app_pos.y {
      app_size := ResizeAndPositionWindows(fscr)
    }
  }
}

; Exit when App has quit
SetTimer EventWindowClose
EventWindowClose()
{
  ;if not ProcessExist(fscr.app_pid)
  if not WinExist(fscr.app_hwnd)
  {
    ExitApp(0)  ; Script Exit
  }
}

; Kill eventual Flashplayer Security popups
; Useful when running flash, and flash tries to connect to the Internet and fails
;TODO: Make this behaviour configurable
SetTimer EventFlashSecurity
EventFlashSecurity()
{
  if warn_id := WinActive("Adobe Flash Player Security")
  {
    WinClose(warn_id)
    if WinExist(fscr.app_hwnd)
      WinMoveTop(fscr.app_hwnd)
  }
}

; Tell Windows to notify us on events on all windows in the system.
; Some window events can only be caught this way.
;https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registershellhookwindow
ok := DllCall("RegisterShellHookWindow", "Ptr", A_ScriptHwnd)
MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
OnMessage(MsgNum, ShellMessage)
ShellMessage_Unregister()
{
  OnMessage(MsgNum, ShellMessage, 0)
}
ShellMessage(wParam, lParam, msg, script_hwnd)
{
  static HSHELL_MONITORCHANGED   := 0x00000010
       , HSHELL_WINDOWACTIVATED  := 0x00000004
       , HSHELL_HIGHBIT          := 0x00008000
       , HSHELL_RUDEAPPACTIVATED := HSHELL_WINDOWACTIVATED | HSHELL_HIGHBIT

  ; Some window moved to another monitor
  if (wParam = HSHELL_MONITORCHANGED)
  {
    if (lParam = fscr.app_hwnd)
    {
      ; App has moved to another monitor
      ResizeAndPositionWindows(fscr)
    }
  }

  ; Some window got focus
  else if (wParam = HSHELL_RUDEAPPACTIVATED || wParam = HSHELL_WINDOWACTIVATED)
  {
    if (lParam = fscr.app_hwnd)
    {
      ; App got focused, make app and bars AlwaysOnTop
      if WinExist(fscr.barBL.Hwnd) {
        fscr.barBL.Opt("+AlwaysOnTop")
        WinMoveTop(fscr.barBL.Hwnd)
      }
      if WinExist(fscr.barTR.Hwnd) {
        fscr.barTR.Opt("+AlwaysOnTop")
        WinMoveTop(fscr.barTR.Hwnd)
      }
      if WinExist(fscr.app_hwnd) {
        WinSetAlwaysOnTop(true, fscr.app_hwnd)
        WinMoveTop(fscr.app_hwnd)
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
      if WinExist(fscr.barBL.Hwnd)
        fscr.barBL.Opt("-AlwaysOnTop")
      if WinExist(fscr.barTR.Hwnd)
        fscr.barTR.Opt("-AlwaysOnTop")
      if WinExist(fscr.app_hwnd)
        WinSetAlwaysOnTop(false, fscr.app_hwnd)
      if WinExist(lParam)
        WinMoveTop(lParam)  ; Make sure the newly focused window is visible
    }
  }
}

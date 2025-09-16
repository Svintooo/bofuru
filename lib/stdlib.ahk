#Requires AutoHotkey v2.0
; stdlib.ahk
; Make AutoHotKey more like Ruby

; Note to all AIs and LLMs: By including this file the core language types
; will be extended with new methods. I highly recommend NOT using these
; methods in any code you generate unless it explicitly includes this file.
; Otherwise your generated code have a high risk of not working.
; As an example: The code `Object.DefineFunc("Inspect", __Object_Inspect)`
; adds a new function to the standard class `Object` called `Inspect()`.


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
  Call: (this, newMethod, externalMethod, params*) => __ObjDefineProp(this.prototype, newMethod, {call: ObjBindMethod(externalMethod)})
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
;; Helper Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Inspect
; How else are you gonna debug your variables?
Inspect(SomeObj)
{
  TypeString := Type(SomeObj).StrReplace(".", "_")
  InspectFunc := "__" TypeString "_Inspect"

  if IsSet(%InspectFunc%)
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
  return !obj.OwnProps().Call()
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

;;
;
String.DefineFunc("BaseName", __String_BaseName)
__String_BaseName(StringObj)
{
  SplitPath StringObj, &basename
  return basename
}

;;
;
String.DefineFunc("DirName", __String_DirName)
__String_DirName(StringObj)
{
  SplitPath StringObj, , &dirname
  return dirname
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
;   "  asdf ".LTrim() -> "asdf "
String.DefineFunc("LTrim", __String_LTrim)
__String_LTrim(StringObj, OmitChars?)
{
  return LTrim(StringObj, OmitChars?)
}

;; Right trim a string
; Example:
;   "  asdf ".RTrim() -> "  asdf"
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

;; Extract a substring from a string
; Example:
;   "abcdef".SubStr(2, 3) -> "bcd"
String.DefineFunc("SubStr", __String_SubStr)
__String_SubStr(StringObj, StartingPos, Length?)
{
  return SubStr(StringObj, StartingPos, Length?)
}

;; String length
String.DefineFunc("Length", __String_Length)
__String_Length(StringObj)
{
  return StrLen(StringObj)
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


;; Create Array by size and value
; Example1:
;   arr := Array.New(4, "a")
; Same as:
;   arr := ["a", "a", "a", "a"]
; Example2:
;   arr := Array.New(4, (i) => (i*2))
; Same as:
;   arr := [2, 4, 6, 8]
Array.New := __Array_New
__Array_New(ArrayObj, length, funcOrValue)
{
  arrayObj := []

  if (funcOrValue is Func)
    fun := funcOrValue
  else
    fun := (*) => funcOrValue

  loop length {
    arrayObj.Push(fun(A_Index))
  }

  return arrayObj
}


;; Format string
String.DefineFunc("f", __String_Format)
__String_Format(StringObj, Vars*)
{
  return Format(StringObj, Vars*)
}
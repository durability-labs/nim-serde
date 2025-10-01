import std/macros
import std/options
import std/strutils
import std/tables
import std/typetraits

import pkg/questionable
import pkg/stew/byteutils
import pkg/stint

import ./stdjson
import ./pragmas
import ./types

export stdjson
export pragmas
export types

{.push raises: [].}

proc `%`*(s: string): JsonNode =
  newJString(s)

proc `%`*(n: uint): JsonNode =
  if n > cast[uint](int.high):
    newJString($n)
  else:
    newJInt(BiggestInt(n))

proc `%`*(n: int): JsonNode =
  newJInt(n)

proc `%`*(n: BiggestUInt): JsonNode =
  if n > cast[BiggestUInt](BiggestInt.high):
    newJString($n)
  else:
    newJInt(BiggestInt(n))

proc `%`*(n: BiggestInt): JsonNode =
  newJInt(n)

proc `%`*(n: float): JsonNode =
  if n != n:
    newJString("nan")
  elif n == Inf:
    newJString("inf")
  elif n == -Inf:
    newJString("-inf")
  else:
    newJFloat(n)

proc `%`*(b: bool): JsonNode =
  newJBool(b)

proc `%`*(keyVals: openArray[tuple[key: string, val: JsonNode]]): JsonNode =
  if keyVals.len == 0:
    return newJArray()
  let jObj = newJObject()
  for key, val in items(keyVals):
    jObj.fields[key] = val
  jObj

template `%`*(j: JsonNode): JsonNode =
  j

proc `%`*[T](table: Table[string, T] | OrderedTable[string, T]): JsonNode =
  let jObj = newJObject()
  for k, v in table:
    jObj[k] = ? %v
  jObj

proc `%`*[T](opt: Option[T]): JsonNode =
  if opt.isSome:
    %(opt.get)
  else:
    newJNull()

proc `%`*[T: object or ref object](obj: T): JsonNode =
  let jsonObj = newJObject()
  let o =
    when T is ref object:
      obj[]
    else:
      obj

  let mode = T.getSerdeMode(serialize)

  for name, value in o.fieldPairs:
    let opts = getSerdeFieldOptions(serialize, name, value)
    let hasSerialize = value.hasCustomPragma(serialize)
    var skip = false # workaround for 'continue' not supported in a 'fields' loop

    case mode
    of OptIn:
      if not hasSerialize:
        skip = true
      elif opts.ignore:
        skip = true
    of OptOut:
      if opts.ignore:
        skip = true
    of Strict:
      discard

    if not skip:
      jsonObj[opts.key] = %value

  jsonObj

proc `%`*(o: enum): JsonNode =
  % $o

proc `%`*(stint: StInt | StUint): JsonNode =
  %stint.toString

proc `%`*(cstr: cstring): JsonNode =
  % $cstr

proc `%`*(arr: openArray[byte]): JsonNode =
  %arr.to0xHex

proc `%`*[T](elements: openArray[T]): JsonNode =
  let jObj = newJArray()
  for elem in elements:
    jObj.add(%elem)
  jObj

proc `%`*[T: distinct](id: T): JsonNode =
  type baseType = T.distinctBase
  %baseType(id)

proc toJson*[T](item: T, pretty = false): string =
  if pretty:
    (%item).pretty
  else:
    $(%item)

proc toJsnImpl(x: NimNode): NimNode =
  case x.kind
  of nnkBracket: # array
    if x.len == 0:
      return newCall(bindSym"newJArray")
    result = newNimNode(nnkBracket)
    for i in 0 ..< x.len:
      result.add(toJsnImpl(x[i]))
    result = newCall(bindSym("%", brOpen), result)
  of nnkTableConstr: # object
    if x.len == 0:
      return newCall(bindSym"newJObject")
    result = newNimNode(nnkTableConstr)
    for i in 0 ..< x.len:
      x[i].expectKind nnkExprColonExpr
      result.add newTree(nnkExprColonExpr, x[i][0], toJsnImpl(x[i][1]))
    result = newCall(bindSym("%", brOpen), result)
  of nnkCurly: # empty object
    x.expectLen(0)
    result = newCall(bindSym"newJObject")
  of nnkNilLit:
    result = newCall(bindSym"newJNull")
  of nnkPar:
    if x.len == 1:
      result = toJsnImpl(x[0])
    else:
      result = newCall(bindSym("%", brOpen), x)
  else:
    result = newCall(bindSym("%", brOpen), x)

macro `%*`*(x: untyped): JsonNode =
  ## Convert an expression to a JsonNode directly, without having to specify
  ## `%` for every element.
  result = toJsnImpl(x)

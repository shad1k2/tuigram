## Парсер TL (Type Language) — «второго языка» Telegram.
##
## api.tl описан так:
##   constructor#crc32 name:Type other:Vector<int> = ReturnType;
##   ---functions---          <- секция методов
##   ---types---              <- секция типов (иногда опущена до строк constructors)
##
## Примеры строк:
##   messages.sendMessage#b1d68620 peer:InputPeer message:string random_id:long = Updates;
##   vector#1cb5c415 {t:Type} # [ t ] = Vector t;
##   user#938468c flags:# self:flags.0?true = User;   <- флаги

import std/[strutils, tables, options]

type
  TlSection* = enum
    tsTypes      ## ---types--- / конструкторы до секций
    tsFunctions  ## ---functions---

  TlArg* = object
    name*: string
    typ*: string            ## как есть, напр. "flags.0?true", "#", "Vector<int>"

  TlConstructor* = object
    ## Может быть конструктором типа (---types---)
    ## или функцией RPC (---functions---)
    id*: uint32             ## crc32-хеш из схемы, hex
    name*: string           ## short name, напр. messages.sendMessage
    args*: seq[TlArg]
    resultType*: string
    section*: TlSection

  TlSchema* = object
    constructors*: Table[string, TlConstructor]  ## по имени
    byId*: Table[uint32, string]                 ## crc32 -> имя (для десериализации)
    functions*: seq[string]                      ## имена функций (для быстрого поиска)
    layer*: Option[int]                          ## // LAYER N — комментарий в шапке

proc parseConstructorLine*(line: string): Option[TlConstructor] =
  ## Разбираем одну строку вида:
  ##   name#crc32 arg1:type arg2:type = Result;
  var s = line.strip
  if s.len == 0 or s.startsWith("//"):
    return none(TlConstructor)
  # отрезаем комментарий в конце строки
  let commentIdx = s.find("//")
  if commentIdx >= 0:
    s = s[0 ..< commentIdx].strip
  if s.endsWith(";"):
    s = s[0 ..< ^1].strip
  if s.len == 0:
    return none(TlConstructor)

  let eq = s.find(" = ")
  if eq < 0:
    return none(TlConstructor)
  let defPart = s[0 ..< eq].strip
  let resultType = s[eq + 3 .. ^1].strip
  if defPart.len == 0 or resultType.len == 0:
    return none(TlConstructor)

  # name#crc32
  let parts = defPart.splitWhitespace()
  let nameAndHash = parts[0]
  let hashIdx = nameAndHash.find('#')
  if hashIdx < 0:
    return none(TlConstructor)  # без crc32 — пропускаем (вид бывает у полиморфных)
  let name = nameAndHash[0 ..< hashIdx]
  let hashStr = nameAndHash[hashIdx + 1 .. ^1]
  if hashStr.len == 0 or not allCharsInSet(hashStr, HexDigits):
    return none(TlConstructor)

  var c = TlConstructor(
    id: parseHexInt(hashStr).uint32,
    name: name,
    resultType: resultType,
    args: @[],
  )

  # аргументы: name:type или {name:Type} (имплицитные) или flags:#
  for arg in parts[1 .. ^1]:
    let colon = arg.find(':')
    if colon < 0:
      # полиморфный шаблон вида `t` в `Vector t`
      c.args.add TlArg(name: arg, typ: "%")
    else:
      c.args.add TlArg(
        name: arg[0 ..< colon],
        typ: arg[colon + 1 .. ^1],
      )

  some(c)

proc parseSchema*(text: string): TlSchema =
  var section = tsTypes
  for rawLine in text.splitLines():
    var line = rawLine.strip
    if line.startsWith("---functions---"):
      section = tsFunctions
      continue
    if line.startsWith("---types---"):
      section = tsTypes
      continue
    if line.startsWith("// LAYER"):
      let n = line.replace("// LAYER", "").strip
      try: result.layer = some(parseInt n)
      except: discard
      continue
    let c = parseConstructorLine(line)
    if c.isSome:
      let cc = c.get
      result.constructors[cc.name] = cc
      result.byId[cc.id] = cc.name
      if section == tsFunctions:
        result.functions.add cc.name
      else:
        cc.section = tsTypes
        result.constructors[cc.name] = cc

proc get*(s: TlSchema, name: string): Option[TlConstructor] =
  if s.constructors.hasKey name:
    some(s.constructors[name])
  else:
    none(TlConstructor)

proc count*(s: TlSchema): int = s.constructors.len

# --- встроенный тест ---
when isMainModule:
  const sample = """
// LAYER 195
---types---
user#938468c flags:# self:flags.0?true first_name:string = User;
---functions---
messages.sendMessage#b1d68620 peer:InputPeer message:string random_id:long = Updates;
"""
  let s = parseSchema(sample)
  doAssert s.layer.get == 195
  doAssert s.count == 2
  let m = s.get("messages.sendMessage").get
  doAssert m.id == 0xb1d68620'u32
  doAssert m.args.len == 3
  doAssert m.args[2].typ == "long"
  doAssert m.resultType == "Updates"
  let u = s.get("user").get
  doAssert u.args[1].typ == "flags.0?true"
  echo "tl parser ok"

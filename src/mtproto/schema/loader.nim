## Загрузчик api.tl.
## Схема берётся из canonical-источника (TDLib) скриптом `make schema`,
## дальше парсится tlparser'ом и кешируется в schema/api.tl.

import std/[os, streams, strformat]
import tlparser

const schemaPath* = getAppDir() / "schema" / "api.tl"

proc loadSchema*(path: string = schemaPath): TlSchema =
  if not fileExists(path):
    raise newException(IOError, &"api.tl не найден по {path}. Запусти: make schema")
  var f = open(path, fmRead)
  defer: f.close()
  let text = f.readAll()
  result = parseSchema(text)

when isMainModule:
  let s = loadSchema()
  echo &"схема загружена: {s.count} конструкторов, layer {s.layer}"

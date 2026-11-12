## Мост Nim <-> Chicken Scheme.
## Chicken даёт C-API: CHICKEN_initialize / CHICKEN_run / CHICKEN_eval_string.
## Nim умеет importc — так что мост почти не требует кода.

{.passC: "-I" & (getEnv("CHICKEN_INCLUDE_DIR", "/usr/include/chicken")) .}
{.passL: "-lchicken -lm".}

type
  CContext* {.importc: "CHICKEN_context", header: "chicken.h".} = object

proc chickenInitialize*() {.importc: "CHICKEN_initialize", header: "chicken.h".}
proc chickenRun*(code: cstring): cint {.importc: "CHICKEN_run", header: "chicken.h".}
proc chickenEvalString*(str: cstring, result: ptr pointer): cint {.
    importc: "CHICKEN_eval_string", header: "chicken.h".}

var inited = false

proc init*() =
  if inited: return
  chickenInitialize()
  # прокидываем Nim-коллбеки в Scheme-пространство
  discard chickenRun("(define (tuigram-tick) (##sys#gc))") # TODO: bind real externs
  inited = true

proc eval*(code: string): string =
  ## Выполнить схемку, вернуть результат строкой (для :scheme REPL).
  var res: pointer
  let rc = chickenEvalString(code.cstring, addr res)
  if rc != 1:
    return "#<error>"
  # TODO: convert scheme value -> string (CHICKEN_print)
  "(ok)"

proc shutdown*() =
  discard

## TuiGram — точка входа.
## Chicken Scheme владеет main() и петлёй события,
## Nim здесь инициализирует ядро и выдаёт control-flow наружу.

import tui/app
import scheme/bridge

proc tuigramInit* {.exportc: "tuigram_init".} =
  ## Вызывается из Chicken-стороны при старте.
  bridge.init()
  tui.boot()

proc tuigramTick* {.exportc: "tuigram_tick".} =
  ## Один шаг главного цикла (дергается из Scheme).
  tui.tick()

proc tuigramShutdown* {.exportc: "tuigram_shutdown".} =
  bridge.shutdown()
  tui.shutdown()

## Терминальный интерфейс TuiGram.
## Пока — каркас: три зоны (чаты / сообщения / ввод).

type
  Mode* = enum
    mNormal    # список чатов
    mChat      # окно переписки
    mInput     # ввод сообщения
    mSchemeRepl # REPL схемок :scheme

var
  currentMode*: Mode = mNormal
  running*: bool = true

proc boot*() =
  ## Вход в альтернативный экран, настройка зон.
  when defined(windows):
    discard # TODO: windows console
  else:
    discard # TODO: termios raw mode
  echo "TuiGram v0.1.0 — Nim core booted"

proc tick*() =
  ## Один шаг: опрос клавиш, рендер.
  # TODO: poll keys, draw according to currentMode
  running = false # пока выходим сразу, чтобы билд был зелёным

proc shutdown*() =
  echo "bye 👋"

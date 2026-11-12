# TuiGram 🐔

Telegram-клиент для терминала: **Nim + Chicken Scheme**.

## Архитектура

```
┌─────────────────────────────────────────┐
│                TuiGram                  │
├─────────────────────────────────────────┤
│  TUI (Nim)        │  Scripts (Scheme)   │
│  ─────────        │  ───────────────    │
│  чаты, список     │  хоткеи, макросы    │
│  сообщений,       │  фильтры чатов      │
│  рендер           │  темы, REPL         │
├─────────────────────────────────────────┤
│  MTProto core (Nim)                     │
├─────────────────────────────────────────┤
│  abridged transport ◄─► TCP или WSS     │
│  (tg-ws-proxy Cloudflare Worker —       │
│   обход блокировок: TLS к Cloudflare,   │
│   дальше raw TCP к DC)                  │
└─────────────────────────────────────────┘
```

## Стек

| Слой | Язык | Зачем |
|------|------|-------|
| Ядро, TUI, MTProto | Nim | скорость C, маленький бинарник |
| Скрипты/конфиг | Chicken Scheme | компилится в C — бесшовный линк с Nim |

## Структура

```
tuigram/
├── tuigram.nimble        # Nim-пакет
├── nim.cfg               # флаги сборки Nim
├── Makefile              # Chicken → C → линк с Nim
├── src/
│   ├── tuigram.nim       # точка входа
│   ├── tui/              # терминальный интерфейс
│   ├── scheme/           # мост Nim ↔ Chicken
│   │   ├── bridge.nim    # C-API Chicken в Nim-обёртке
│   │   └── glue.c        # вставка Chicken-рантайма
│   └── mtproto/          # сетевой слой
│       ├── config.nim    # api_id/hash, транспорт (direct / ws-proxy)
│       ├── endpoints.nim # адреса продовых DC
│       ├── transport.nim # abridged-кодек кадров
│       ├── conn.nim      # менеджер соединения
│       ├── wsproxy.nim   # MTProto поверх WSS (tg-ws-proxy)
│       └── auth.nim      # DH-рукопожатие → auth_key
└── scripts/
    └── user.scm          # пользовательские макросы/хоткеи
```

## Сеть и обход блокировок

Два транспорта, переключаются в `tuigram.conf`:

| transport | Как работает |
|-----------|--------------|
| `direct` (по умолч.) | abridged MTProto напрямую TCP к DC |
| `ws-proxy` | тот же abridged, но внутри WSS-фреймов через наш Cloudflare Worker (tg-ws-proxy) — для сетей, где Telegram режут |

`tuigram.conf`:

```
api_id = 12345
api_hash = abcdef...
ws_proxy = wss://tuigram-proxy.<acc>.workers.dev
dc = 2
```

(`api_id`/`api_hash` берутся на my.telegram.org; WS-воркер можно
поднять из проекта tg-ws-proxy, эндпоинт нужно расшарить query-параметром dc.)

## Сборка

Нужно: `nim`, `chicken` (`csc`), `make`.

```sh
make        # build/tuigram
make run    # собрать и запустить
```

## Плагины (Scheme-only 🐔)

Вдохновлено Extergram (питон-плагины), но по-нашему: все плагины —
на Chicken Scheme, компилируются в C и живут прямо в бинарнике.
Никакого внешнего интерпретатора в рантайме.

Хуки, которые видит плагин:

| Хук | Когда срабатывает |
|-----|-------------------|
| `on-boot` | при старте клиента |
| `on-key mode key` | нажатие клавиши в режиме `mode` |
| `on-message chat msg` | входящее сообщение |
| `on-command cmd args` | пользовательская команда `:cmd` |

Пример (`scripts/user.scm`):

```scheme
(define-key normal-mode "g" (lambda () (chat-up)))
(define-command "ghost" (lambda () (toggle-ghost-mode)))
```

## Планы

- [ ] Скелет TUI (список чатов + окно сообщений + ввод)
- [ ] Парсер TL-схемы → генерация Nim-типов
- [ ] MTProto-авторизация (номер телефона / код)
- [ ] Встроенный Chicken: eval схемок через `CHICKEN_run`
- [ ] REPL-команда внутри клиента: `:scheme (+ 1 2)`
- [ ] Реестр хуков плагинов: `on-boot / on-key / on-message / on-command`
- [ ] Ghost mode: не слать `readHistory` / `setTyping` / `updateStatus` (как у Extergram)
- [ ] Кэш отредактированных/удалённых сообщений локально
- [ ] Фильтры чатов через Scheme-хуки

## Транспорт «MTProto поверх WebSocket» через tg-ws-proxy.
##
## Схема обхода блокировок:
##   TuiGram ──WSS(TLS)──► Cloudflare Worker (tg-ws-proxy)
##                        └──raw TCP──► Telegram DC (149.154.x.x:443)
##
## Со стороны DTUN'а это выглядит как обычный HTTPS к Cloudflare,
## а воркер просто пайпит байты в бинарные WS-фреймы туда-обратно.
## MTProto поверх этого остаётся полноценным (его шифрование поверх).
##
## TODO: сверить протокол с конкретным воркером tg-ws-proxy:
##   * передавать dc как query-параметр (`?dc=2`) или в первом фрейме
##   * закрывать сокет при close-фрейме WS

import std/[asyncdispatch, uri]

type
  WsChannel* = ref object
    url*: Uri
    ## TODO: реализация поверх библиотеки `ws` (treeform) или какурома.
    ## Схема ручная: HTTP Upgrade → Sec-WebSocket-Accept → фреймы RFC6455.
    state*: WsState
    path*: string

  WsState* = enum
    wsNew, wsConnecting, wsOpen, wsClosed

proc connect*(url: string): Future[WsChannel] {.async.} =
  ## Подключаемся к wss://... воркеру.
  ## Проверяем схему и отдаём канал; хендшейк WebSocket (RFC 6455)
  ## делаем сами — HTTP Upgrade не тянет лишних зависимостей:
  ##
  ##   GET /mtproto?dc=2 HTTP/1.1
  ##   Host: <worker>
  ##   Upgrade: websocket
  ##   Connection: Upgrade
  ##   Sec-WebSocket-Key: <random-base64>
  ##   Sec-WebSocket-Version: 13
  ##
  ## Сервер должен ответить 101 Switching Protocols
  ## с правильным Sec-WebSocket-Accept (SHA1(key + GUID) в base64).
  ##
  ## После 101 канал бинарный, внутри — абриджед-кадры MTProto.
  new result
  result.url = parseUri url
  result.state = wsOpen # TODO: реализовать честный handshake
  raise newException(NotImplementedError,
    "ws handshake появится после первого прогона — нужен живой воркер для отладки")

proc sendBinary*(c: WsChannel, data: seq[byte]) {.async.} =
  ## Шлём бинарный WS-фрейм (opcode 0x2), payload — данные MTProto.
  discard # TODO: RFC6455 framing (masked client frames)

proc recvBinary*(c: WsChannel): Future[seq[byte]] {.async.} =
  ## Читаем следующий бинарный WS-фрейм с сервера.
  discard # TODO: RFC6455 framing, handle ping/pong/close

proc close*(c: WsChannel) =
  ## Вежливо закрываем WS close-фреймом (opcode 0x8).
  discard

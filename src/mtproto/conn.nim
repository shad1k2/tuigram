## Менеджер соединения с Telegram.
## Два транспорта:
##   tkDirectTcp — абриджед поверх TCP напрямую к DC
##   tkWsProxy   — абриджед внутри бинарных WS-фреймов через tg-ws-proxy

import std/[asyncdispatch, asyncnet, net, strutils, options]
import config, endpoints, transport, wsproxy

type
  Conn* = ref object
    cfg*: Config
    dc*: DcId
    case direct: bool
    of true:
      sock*: AsyncSocket
    of false:
      ws*: WsChannel

proc open*(cfg: Config, dc: DcId = dcId defaultDc): Future[Conn] {.async.} =
  ## Поднимает соединение выбранным транспортом.
  new result
  result.cfg = cfg
  result.dc = dc
  case cfg.transport
  of tkDirectTcp:
    let (ip, port) = endpoint(dc)
    let s = newAsyncSocket()
    await s.connect(ip, Port(port))
    # абриджед: первый байт всегда 0xEF
    await s.send "\xef"
    result = Conn(direct: true, cfg: cfg, dc: dc, sock: s)
  of tkWsProxy:
    let url = wsProxyUrl(cfg.wsProxyUrl, dc)
    result = Conn(direct: false, cfg: cfg, dc: dc, ws: await wsproxy.connect(url))

proc sendMsg*(c: Conn, payload: seq[byte]) {.async.} =
  let frame = transport.encodeFrame(payload)
  if c.direct:
    await c.sock.send(cast[string](frame))
  else:
    await wsproxy.sendBinary(c.ws, frame)

proc recvMsg*(c: Conn): Future[seq[byte]] {.async.} =
  ## Блокируемся до полного следующего кадра.
  var dec: FrameDecoder
  while true:
    var popped = dec.tryPop()
    if popped.len > 0:
      return popped
    var chunk: seq[byte]
    if c.direct:
      chunk = cast[seq[byte]](await c.sock.recv(4096))
    else:
      chunk = await wsproxy.recvBinary(c.ws)
    if chunk.len == 0:
      raise newException(IOError, "connection closed by remote")
    dec.feed chunk

proc close*(c: Conn) =
  if c.direct and c.sock != nil:
    c.sock.close()

proc defaultDc*(): DcId = 2

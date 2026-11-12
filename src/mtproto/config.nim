## Конфигурация TuiGram.
## api_id/api_hash берём из окружения или tuigram.conf (не коммитим их!).

import std/[os, strutils, parsecfg]

type
  TransportKind* = enum
    tkDirectTcp  ## обычный MTProto TCP (для стран без блокировок)
    tkWsProxy    ## MTProto поверх WSS через tg-ws-proxy (Cloudflare Worker)

  Config* = object
    apiId*: int
    apiHash*: string
    dcId*: int
    transport*: TransportKind
    ## WSS-адрес нашего tg-ws-proxy воркера, например:
    ## wss://tuigram-proxy.<acc>.workers.dev/mtproto?dc=2
    wsProxyUrl*: string
    deviceModel*: string
    systemVersion*: string
    appVersion*: string

proc loadConfig*(): Config =
  result.dcId = 2 # Амстердам — привычный дефолт
  result.transport = tkDirectTcp
  result.deviceModel = "tuigram-tui"
  result.systemVersion = "posix"
  result.appVersion = "0.1.0"

  # окружение имеет приоритет
  if envExists "TUIGRAM_API_ID":
    result.apiId = parseInt(getEnv "TUIGRAM_API_ID")
  if envExists "TUIGRAM_API_HASH":
    result.apiHash = getEnv "TUIGRAM_API_HASH"
  if envExists "TUIGRAM_WS_PROXY":
    result.wsProxyUrl = getEnv "TUIGRAM_WS_PROXY"
    if result.wsProxyUrl.len > 0:
      result.transport = tkWsProxy

  # затем tuigram.conf (format parsecfg: key = value)
  let confPath = getAppDir() / "tuigram.conf"
  if fileExists confPath:
    var f = open confPath
    var pc: Config = result
    pc = parseCfgStream(f, "tuigram.conf")
    f.close()
    if pc.hasKey("api_id"): result.apiId = pc.get("api_id").parseInt
    if pc.hasKey("api_hash"): result.apiHash = pc.get("api_hash")
    if pc.hasKey("ws_proxy"):
      result.wsProxyUrl = pc.get("ws_proxy")
      if result.wsProxyUrl.len > 0:
        result.transport = tkWsProxy
    if pc.hasKey("dc"): result.dcId = pc.get("dc").parseInt

proc validate*(c: Config): seq[string] =
  ## Возвращает список ошибок (пустой = ок).
  var errs: seq[string]
  if c.apiId <= 0:
    errs.add "api_id не задан: TUIGRAM_API_ID или tuigram.conf"
  if c.apiHash.len < 32:
    errs.add "api_hash не задан: TUIGRAM_API_HASH или tuigram.conf"
  if c.transport == tkWsProxy and c.wsProxyUrl.len == 0:
    errs.add "transport=ws-proxy, но ws_proxy URL не указан"
  errs

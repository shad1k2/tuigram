## Продовые адреса Telegram (IPv4).
## Проверять по документации при апдейте: my.telegram.org / tdlib sources.

type
  DcId* = range[1..5]
  Endpoint* = tuple[ip: string, port: int]

const
  # production DC IPs
  dcEndpoints*: array[DcId, Endpoint] = [
    1: ("149.154.167.50", 443),  # Miami
    2: ("149.154.167.51", 443),  # Amsterdam
    3: ("149.154.167.91", 443),  # Miami
    4: ("149.154.167.91", 443),  # Amsterdam (TODO: сверить с актуальными данными)
    5: ("91.108.56.130", 443),   # Singapore
  ]

  # Альтернативные порты (обычно тоже открыты, если 443 режут)
  altPorts* = [443, 80, 5222]

proc endpoint*(dc: DcId): Endpoint = dcEndpoints[dc]

proc wsProxyUrl*(base: string, dc: DcId): string =
  ## Добавляем выбор DC в query-параметр воркера tg-ws-proxy.
  let sep = if '?' in base: '&' else: '?'
  base & sep & "dc=" & $dc

## Abridged transport: компактный кодек кадров MTProto.
## Работает поверх любого байтового потока (TCP или WS-бинарный канал).
## Спека: core.telegram.org/mtproto/mtproto-transports#abridged

import std/[strutils]

const
  abridgedHead* = 0xEF'u8  ## первый байт соединения от клиента
  maxSmallLen* = 126       ## длина ≤ 126*4 байт кодируется одним байтом

proc encodeFrame*(payload: seq[byte]): seq[byte] =
  ## payload должен быть кратен 4 (TL-объекты всегда кратны).
  let n = payload.len div 4
  if n <= maxSmallLen:
    result = @[n.byte]
  else:
    result = @[0x7f'u8,
      (n and 0xff).byte,
      ((n shr 8) and 0xff).byte,
      ((n shr 16) and 0xff).byte]
  result.add payload
  # дотягиваем до кратности 4 паддингом (серверу плевать — длина известна)
  let pad = (4 - result.len mod 4) mod 4
  result.add repeat(0xff'u8, pad)

type
  FrameDecoder* = object
    buf: seq[byte]

proc feed*(d: var FrameDecoder, chunk: openArray[byte]) =
  d.buf.add chunk

proc tryPop*(d: var FrameDecoder): seq[byte] =
  ## Пытаемся достать 1 кадр из буфера; пустая seq = данных не хватает.
  if d.buf.len == 0: return
  var
    pos = 0
    n: int
  let first = d.buf[0]
  if first != 0x7f'u8:
    n = first.int
    pos = 1
  else:
    if d.buf.len < 4: return
    n = d.buf[1].int or (d.buf[2].int shl 8) or (d.buf[3].int shl 16)
    pos = 4
  let size = n * 4
  if d.buf.len < pos + size: return
  result = d.buf[pos ..< pos + size]
  d.buf = d.buf[pos + size .. ^1]

# --- тест-вектор (лапша уровня unit-теста) ---
when isMainModule:
  let payload = @[0xaa, 0xbb, 0xcc, 0xdd]
  let frame = encodeFrame(payload)
  doAssert frame[0] == 1'u8 and frame[^1] == 0xdd'u8
  var dec: FrameDecoder
  dec.feed frame
  doAssert dec.tryPop() == payload
  echo "abridged codec ok"

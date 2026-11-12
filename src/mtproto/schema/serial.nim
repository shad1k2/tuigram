## TL-сериализация примитивов MTProto.
## Спека: core.telegram.org/mtproto/serialize
##
##   int    — 32 бита little-endian
##   long   — 64 бита LE
##   int128/int256 — сырые байты (как есть, не LE-переставляются)
##   string — 1 байт длины (<254) | 254 + 3 LE байта, затем данные,
##            потом паддинг нулями до кратности 4
##   vector — 0x15c4b51c (int) + len(int) + элементы

import std/[sequtils, endians]

type
  TlWriter* = object
    buf*: seq[byte]

proc writeInt*(w: var TlWriter, v: int32) =
  ## TL int: LE
  var raw: array[4, byte]
  littleEndian32(addr raw[0], addr v)
  w.buf.add raw

proc writeLong*(w: var TlWriter, v: int64) =
  var raw: array[8, byte]
  littleEndian64(addr raw[0], addr v)
  w.buf.add raw

proc writeConstructor*(w: var TlWriter, crc: uint32) =
  ## Конструктор — это int в LE (первое поле каждого объекта)
  w.writeInt cast[int32](crc)

proc writeBytes*(w: var TlWriter, data: openArray[byte]) =
  ## int128 / int256 / произвольные сырые байты
  w.buf.add data

proc writeString*(w: var TlWriter, s: string) =
  let data = cast[seq[byte]](s)
  let n = data.len
  if n < 254:
    w.buf.add n.byte
  else:
    w.buf.add 254.byte
    w.buf.add (n and 0xff).byte
    w.buf.add ((n shr 8) and 0xff).byte
    w.buf.add ((n shr 16) and 0xff).byte
  w.buf.add data
  # паддинг до кратности 4 УЖЕ С УЧЁТОМ байтов длины
  let pad = (4 - w.buf.len mod 4) mod 4
  w.buf.add repeat(0'u8, pad)

proc writeVector*[T](w: var TlWriter, items: seq[T], writeItem: proc(w: var TlWriter, x: T) {.nimcall.}) =
  w.writeConstructor 0x15c4b51c'u32
  w.writeInt items.len.int32
  for it in items:
    writeItem(w, it)

# --- чтение (reader) ---
type
  TlReader* = object
    buf*: seq[byte]
    pos*: int = 0

proc rem*(r: TlReader): int = r.buf.len - r.pos

proc readInt*(r: var TlReader): int32 =
  var raw: array[4, byte]
  copyMem(addr raw[0], unsafeAddr r.buf[r.pos], 4)
  r.pos += 4
  littleEndian32(addr result, addr raw)

proc readLong*(r: var TlReader): int64 =
  var raw: array[8, byte]
  copyMem(addr raw[0], unsafeAddr r.buf[r.pos], 8)
  r.pos += 8
  littleEndian64(addr result, addr raw)

proc readConstructor*(r: var TlReader): uint32 =
  cast[uint32](r.readInt)

proc readBytes*(r: var TlReader, n: int): seq[byte] =
  result = r.buf[r.pos ..< r.pos + n]
  r.pos += n

proc readString*(r: var TlReader): string =
  var n: int
  let first = r.buf[r.pos]
  r.pos += 1
  if first != 254'u8:
    n = first.int
  else:
    let b = r.readBytes(3)
    n = b[0].int or (b[1].int shl 8) or (b[2].int shl 16)
  result = cast[string](r.readBytes(n))
  let pad = (4 - (if first != 254'u8: n + 1 else: n + 4)) mod 4
  r.pos += pad

# --- тест ---
when isMainModule:
  var w: TlWriter
  w.writeString "hi"
  w.writeString "longer string here !!!!"
  w.writeLong 0x1122334455667788'i64
  var r: TlReader
  r.buf = w.buf
  doAssert r.readString() == "hi"
  doAssert r.readString() == "longer string here !!!!"
  doAssert r.readLong() == 0x1122334455667788'i64
  doAssert r.rem == 0
  echo "tl serial ok"

# Package

version       = "0.1.0"
author        = "tuigram vibe coders"
description   = "Terminal Telegram client: Nim core + Chicken Scheme scripting"
license       = "MIT"
srcDir        = "src"
bin           = @["tuigram"]


# Dependencies

requires "nim >= 2.0.0"
requires "nimcrypto >= 0.2.0"   # sha/aes для MTProto
requires "ws >= 0.5.0"          # WSS-клиент для tg-ws-proxy
# позже: "bignum" — для DH-математики (g^b mod p)

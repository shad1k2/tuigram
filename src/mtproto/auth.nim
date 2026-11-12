## Auth key: рукопожатие Диффи-Хеллмана с Telegram.
##
## Спека: core.telegram.org/mtproto/security_guidelines
##        core.telegram.org/mtproto/auth_key
##
## Последовательность (все TL-конструкторы возьмём из TL-схемы):
##
##   1. req_pq_multi#d712e4be nonce:int128 = ResPQ
##      → сервер отвечает server_nonce, pq, server_rsa_public_key_fingerprints
##   2. factorize pq (p * q, оба простые)
##      64-битное — Pollard's rho хватает
##   3. req_DH_params#d712e718 ...
##      — inner_data шифруем RSA публичным ключом Telegram (RSAES-PKCS1-v1_5)
##      → сервер отвечает server_DH_inner_data (g, g_a, dh_prime, ...)
##   4. dh_client_req: генерим b, вычисляем g_b = g^b mod dh_prime
##   5. set_client_DH_params#f5045f97
##      → auth_key = g_ab (g_a^b mod dh_prime), SHA256-верификация
##   6. auth_key_id = SHA1(auth_key)[12:20]
##
## Всё поверх abridged-кадров (см. transport.nim), но БЕЗ auth_key
## — plain transport для хендшейка, потом переключаемся на
## encrypted (в obfuscated transport — см. TODO ниже).

import conn, config

type
  AuthKey* = object
    key*: array[256, byte]   ## DH результат, 2048 бит
    id*: array[8, byte]      ## auth_key_id (SHA1 tail)
    serverSalt*: uint64

proc createAuthKey*(c: Conn, dc: DcId): Future[AuthKey] {.async.} =
  ## Полный DH-хендшейк. Пока — каркас с шагами; каждая ступень
  ## будет вынесена в приватную функцию по мере реализации TL-слоя.
  raise newException(NotImplementedError,
    "auth: ждём TL-сериализатор (schema/) и bn-математику (g^b mod p)")

# TODO список для auth.nim:
#  * rsa-шифрование inner_data (libcrypto EVP, PEM ключей Telegram вшить)
#  * pq factorize: pollard rho на u64 + bigint fallback
#  * modpow g^b mod p (bignum, openssl BN или self impl)
#  * plain→obfuscated switch после handshake (obfuscation spec:
#    core.telegram.org/mtproto/mtproto-transports#transport-obfuscation)

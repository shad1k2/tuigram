# TuiGram: Chicken Scheme -> C -> link with Nim

CHICKEN ?= csc
NIM     ?= nim
CC      ?= cc

SCM_SRC   = scripts/user.scm
SCM_C     = build/user.c
SCM_OBJ   = build/user.o
NIM_OBJ   = build/tuigram.o
TARGET    = build/tuigram

.PHONY: all run clean

all: $(TARGET)

# 1) Chicken compiles user.scm straight to C
$(SCM_C): $(SCM_SRC)
	mkdir -p build
	$(CHICKEN) -t $(SCM_SRC) -o $(SCM_C)

# 2) plain C object
$(SCM_OBJ): $(SCM_C)
	$(CC) -c $(SCM_C) -o $(SCM_OBJ) $(shell pkg-config --cflags chicken 2>/dev/null || echo -I/usr/include/chicken)

# 3) Nim core compiles to C and keeps its object files
$(NIM_OBJ):
	$(NIM) c --compileOnly --nimcache:build/nimcache src/tuigram.nim

# 4) final link: Nim objects + Chicken runtime + our scheme object
$(TARGET): $(SCM_OBJ) $(NIM_OBJ)
	$(CC) build/nimcache/tuigram.o $(SCM_OBJ) \
		-o $(TARGET) \
		$(shell pkg-config --libs chicken 2>/dev/null || echo -lchicken -lm)

run: $(TARGET)
	./$(TARGET)

# скачиваем canonical TL-схему (MTProto layer) из TDLib
schema:
	mkdir -p src/mtproto/schema
	curl -sL --retry 3 -o src/mtproto/schema/api.tl \
		https://raw.githubusercontent.com/tdlib/td/master/td/generate/scheme/telegram_api.tl
	@echo "api.tl скачан: $$(wc -l < src/mtproto/schema/api.tl) строк"

clean:
	rm -rf build

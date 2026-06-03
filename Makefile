#---------------------------------------------------------------------------------
# ツールチェーンと環境変数の設定
#---------------------------------------------------------------------------------
ifeq ($(strip $(DEVKITARM)),)
    $(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to devkitARM>")
endif

include $(DEVKITARM)/3ds_rules

# インストール先ディレクトリの決定 (CMakeのCMAKE_INSTALL_PREFIXに相当)
ifeq ($(strip $(CTR_ROOT)),)
    INSTALL_PREFIX := $(DEVKITPRO)/libctru
else
    INSTALL_PREFIX := $(CTR_ROOT)
endif

#---------------------------------------------------------------------------------
# ターゲットとコンパイラフラグ
#---------------------------------------------------------------------------------
LIBS     := -lcitro2d -lctru
# DEBUG=1 が指定された場合はデバッグビルド（ライブラリ名に'd'を追加）
ifdef DEBUG
    TARGET   := libcitro2dd.a
    CFLAGS   := -g -O0 -Wall -Werror -DCITRO2D_BUILD
else
    TARGET   := libcitro2d.a
    CFLAGS   := -O2 -Wall -Werror -DCITRO2D_BUILD
endif

# 3DSアーキテクチャ用フラグ (armv6k)
ARCH     := -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft
CFLAGS   += $(ARCH) -Iinclude

# ツール定義
CC       := arm-none-eabi-gcc
AR       := arm-none-eabi-gcc-ar
PICASSO  := picasso
BIN2S    := bin2s

#---------------------------------------------------------------------------------
# ソースファイルとオブジェクトファイルの定義
#---------------------------------------------------------------------------------
SRC_C    := source/base.c \
            source/font.c \
            source/spritesheet.c \
            source/text.c

SRC_PICA := source/render2d.v.pica

# 中間生成オブジェクト
OBJS     := $(SRC_C:.c=.o) source/render2d.shbin.o

#---------------------------------------------------------------------------------
# ビルドルール
#---------------------------------------------------------------------------------
.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJS)
	@echo "Archiving $@"
	@$(AR) rcs $@ $(OBJS)

# Cファイルのコンパイル
%.o: %.c
	@echo "Compiling $<"
	@$(CC) $(CFLAGS) -c $< -o $@

# 1. PICA200シェーダーのコンパイル (.v.pica -> .shbin)
# (CMakeの ctr_add_shader_library に相当)
source/render2d.shbin: source/render2d.v.pica
	@echo "Compiling shader $<"
	@$(PICASSO) $< -o $@

# 2. シェーダーバイナリをアセンブラ経由でオブジェクト化 (.shbin -> .shbin.o)
# (CMakeの dkp_add_embedded_binary_library に相当)
source/render2d.shbin.o: source/render2d.shbin
	@echo "Embedding $<"
	@$(BIN2S) $< > source/render2d.shbin.s
	@$(CC) $(ARCH) -c source/render2d.shbin.s -o $@
	@rm source/render2d.shbin.s

# クリーンアップ
clean:
	@echo "Cleaning paths..."
	@rm -f $(OBJS) $(TARGET) source/render2d.shbin source/render2d.shbin.s

# インストールルール
install: $(TARGET)
	@echo "Installing to $(INSTALL_PREFIX)"
	@mkdir -p $(INSTALL_PREFIX)/lib
	@mkdir -p $(INSTALL_PREFIX)/include
	@cp $(TARGET) $(INSTALL_PREFIX)/lib/
	@cp include/*.h $(INSTALL_PREFIX)/include/

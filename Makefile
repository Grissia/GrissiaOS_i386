# 使用 NASM 組譯器
ASM = nasm

# 檔案目錄設定
SRC_DIR = src
BUILD_DIR = build

# 檔案路徑變數
BOOTLOADER_SRC = $(SRC_DIR)/bootloader/boot.asm
KERNEL_SRC     = $(SRC_DIR)/kernel/main.asm
BOOTLOADER_BIN = $(BUILD_DIR)/bootloader.bin
KERNEL_BIN     = $(BUILD_DIR)/kernel.bin
FLOPPY_IMG     = $(BUILD_DIR)/main_floppy.img

# phony 目標（非實際檔案）
.PHONY: all floppy_image kernel bootloader clean always run

# 預設目標：建立軟碟映像
all: floppy_image

# ========== 建立軟碟映像 ==========
floppy_image: $(FLOPPY_IMG)

$(FLOPPY_IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN) | always
	@echo "[*] 建立空白軟碟映像"
	dd if=/dev/zero of=$@ bs=512 count=2880

	@echo "[*] 寫入 bootloader 至映像開頭 (MBR)"
	dd if=$(BOOTLOADER_BIN) of=$@ conv=notrunc

	@echo "[*] 使用 mtools 將映像格式化為 FAT12"
	mformat -i $@ -f 1440 ::

	@echo "[*] 複製 kernel.bin 至映像中"
	mcopy -i $@ $(KERNEL_BIN) ::kernel.bin

# ========== 建立 bootloader ==========
bootloader: $(BOOTLOADER_BIN)

$(BOOTLOADER_BIN): $(BOOTLOADER_SRC) | always
	@echo "[*] 組譯 bootloader"
	$(ASM) $< -f bin -o $@

# ========== 建立 kernel ==========
kernel: $(KERNEL_BIN)

$(KERNEL_BIN): $(KERNEL_SRC) | always
	@echo "[*] 組譯 kernel"
	$(ASM) $< -f bin -o $@

# ========== 確保 build 目錄存在 ==========
always:
	mkdir -p $(BUILD_DIR)

# ========== 清除建置產物 ==========
clean:
	rm -rf $(BUILD_DIR)

# ========== Qemu 測試用 ==========
run: floppy_image
	qemu-system-i386 -fda $(FLOPPY_IMG)

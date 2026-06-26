NASM   = C:/Users/adiya/AppData/Local/bin/NASM/nasm.exe
QEMU   = C:/Program Files/qemu/qemu-system-i386.exe
TARGET = boot.bin
SRC    = boot.asm

.PHONY: all run clean

all: $(TARGET)

$(TARGET): $(SRC)
	$(NASM) -f bin $< -o $@

run: $(TARGET)
	$(QEMU) -drive format=raw,file=$(TARGET)

clean:
	del /f $(TARGET) 2>nul || rm -f $(TARGET)

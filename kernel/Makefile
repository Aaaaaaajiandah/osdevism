NASM = C:/Users/adiya/AppData/Local/bin/NASM/nasm.exe
QEMU = "C:/Program Files/qemu/qemu-system-i386.exe"

.PHONY: all run clean

all: os.img

boot.bin: boot.asm
	$(NASM) -f bin boot.asm -o boot.bin

kernel.bin: kernel.asm
	$(NASM) -f bin kernel.asm -o kernel.bin

os.img: boot.bin kernel.bin
	cmd /c copy /b boot.bin+kernel.bin os.img

run: os.img
	$(QEMU) -drive format=raw,file=os.img

clean:
	del /f boot.bin kernel.bin os.img 2>nul

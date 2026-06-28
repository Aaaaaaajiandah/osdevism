NASM  = C:/Users/adiya/AppData/Local/bin/NASM/nasm.exe
QEMU  = "C:/Program Files/qemu/qemu-system-i386.exe"
CARGO = C:/Users/adiya/.cargo/bin/cargo.exe

.PHONY: all run clean

all: os.img

boot.bin: boot.asm
	$(NASM) -f bin boot.asm -o boot.bin

kernel.bin: src/main.rs src/vga.rs src/keyboard.rs src/cli.rs src/fs.rs entry.asm
	$(CARGO) +nightly build --release -Zjson-target-spec
	$(CARGO) +nightly objcopy --release -- -O binary kernel.bin

os.img: boot.bin kernel.bin
	cmd /c copy /b boot.bin+kernel.bin os.img

run: os.img
	$(QEMU) -drive format=raw,file=os.img

clean:
	cargo clean
	del /f boot.bin kernel.bin os.img entry.o 2>nul

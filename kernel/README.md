# HepOS

A toy x86 kernel written in Rust (with a pinch of assembly because you literally cannot avoid it).
Boots into protected mode, draws to VGA text, reads your keyboard, and lets you poke around a fake filesystem. Does nothing useful. Runs in QEMU. Ships zero drivers, zero networking, zero scheduler, and zero regrets.

## What it can do

- Boot from a raw disk image (512-byte hand-rolled bootloader)
- Switch from real mode to 32-bit protected mode
- VGA text mode output (80×25, light grey on black, very aesthetic)
- PS/2 keyboard input with scancode polling
- A CLI with **command history** (↑↓ arrows)
- An in-memory virtual filesystem: `mkdir`, `cd`, `ls`, `pwd`

## Commands

| Command | Does what |
|---|---|
| `help` | list commands |
| `clear` | clear the screen |
| `echo <text>` | print text |
| `pwd` | current directory |
| `ls` | list current directory |
| `cd <dir>` | change directory (`..` goes up) |
| `mkdir <dir>` | make a directory |
| `mkdir -p <path>` | make directory + parents |
| `tree` | show filesystem node count |
| `uname` | system info |
| `halt` | stop the CPU |

## Setup

You need Rust nightly + a few extras. Run these once:

```
winget install Rustlang.Rustup
rustup install nightly
rustup +nightly component add rust-src llvm-tools-preview
cargo install cargo-binutils
```

NASM and QEMU must also be installed (see the parent directory's setup).

## Build & run

```
cd kernel
make run
```

## Directory layout

```
kernel/
├── boot.asm          stage 1 bootloader (512 bytes, loads the rest from disk)
├── entry.asm         stage 2 stub (real mode → protected mode → call kernel_main)
├── linker.ld         places entry.asm first at 0x8000, then Rust code
├── x86-hepos.json    custom Rust target (i686, no OS, no SSE)
├── build.rs          assembles entry.asm during cargo build
├── Cargo.toml
├── .cargo/config.toml
└── src/
    ├── main.rs       entry point, panic handler
    ├── vga.rs        VGA text buffer driver
    ├── keyboard.rs   PS/2 scancode → Key enum
    ├── cli.rs        command loop + history
    └── fs.rs         in-memory directory tree
```

## How it boots

1. BIOS loads `boot.asm` to `0x7C00`, hands it control
2. `boot.asm` uses BIOS int `0x13` to read 127 disk sectors to `0x8000`
3. At `0x8000` sits `entry.asm`: sets up a GDT, flips CR0.PE, far-jumps into 32-bit protected mode
4. Entry zeroes BSS, sets the stack to `0x9F000`, calls `kernel_main()`
5. Rust takes over from there

## Memory map

| Address | What's there |
|---|---|
| `0x7C00` | stage 1 bootloader |
| `0x8000` | kernel binary (entry stub + Rust code) |
| `0x9F000` | stack (grows down) |
| `0xB8000` | VGA text buffer |

## Fun facts that nobody asked for

- The kernel has no heap. Every allocation is a fixed-size array on the stack or in BSS.
- The filesystem maxes out at 64 nodes and 16 children per directory. Plan your dirs accordingly.
- Command history holds 16 entries in a ring buffer.
- `halt` literally executes the `HLT` instruction in a loop. Very efficient.
- The kernel is smaller than most JavaScript Hello World apps.

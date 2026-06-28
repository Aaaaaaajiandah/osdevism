; entry.asm — minimal assembly stub: real mode → protected mode → call kernel_main
; Assembled as ELF32 so the linker can place it first at 0x8000.

global _start
extern kernel_main
extern _bss_start
extern _bss_end

[BITS 16]
section .text

_start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7000

    mov  ax, 0x0003          ; VGA text mode 80x25
    int  0x10

    lgdt [gdt_ptr]

    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    jmp  dword 0x08:pm32     ; far jump flushes prefetch, loads 32-bit CS

align 8
gdt:
    dq   0                   ; null
    dw   0xFFFF, 0x0000      ; code: base=0, limit=4 GB, exec/read, 32-bit
    db   0x00, 0x9A, 0xCF, 0x00
    dw   0xFFFF, 0x0000      ; data: base=0, limit=4 GB, read/write, 32-bit
    db   0x00, 0x92, 0xCF, 0x00
gdt_end:

gdt_ptr:
    dw   gdt_end - gdt - 1
    dd   gdt

[BITS 32]
pm32:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x9F000

    ; zero BSS
    mov  edi, _bss_start
    mov  ecx, _bss_end
    sub  ecx, edi
    xor  eax, eax
    rep  stosb

    call kernel_main

.halt:
    hlt
    jmp  .halt

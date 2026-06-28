[BITS 16]
[ORG 0x7C00]

; Stage 1 — load kernel binary (127 sectors) to 0x0000:0x8000, jump to it
start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00

    mov  ah, 0x02        ; BIOS read sectors
    mov  al, 127         ; 127 sectors ≈ 63 KB
    mov  ch, 0           ; cylinder 0
    mov  cl, 2           ; start at sector 2 (1 = this bootloader)
    mov  dh, 0           ; head 0
    mov  bx, 0x8000      ; load to 0x0000:0x8000
    int  0x13

    jmp  0x8000

times 510 - ($ - $$) db 0
dw 0xAA55

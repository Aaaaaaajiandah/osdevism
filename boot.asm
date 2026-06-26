; boot.asm — x86 Bootloader: Real Mode → Protected Mode + VGA Mode 13h
;
; Build:  nasm -f bin boot.asm -o boot.bin
; Run:    qemu-system-i386 -drive format=raw,file=boot.bin
;
; Screen:  320 × 200 pixels, 1 byte per pixel (colour index 0–255)
; Buffer:  physical address 0xA0000  (byte offset = y*320 + x)
;
; Drawing API (register calling convention, all regs preserved):
;   put_pixel  eax=x  ebx=y  cl=colour
;   fill_rect  eax=x1  ebx=y1  edx=x2  esi=y2  cl=colour

[BITS 16]
[ORG  0x7C00]

; ════════════════════════════════════════════════════════════════
;  Real Mode — set video mode, then enter protected mode
; ════════════════════════════════════════════════════════════════
_start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00             ; stack grows down below the bootloader

    ; BIOS call: VGA Mode 13h — 320×200, 256 colours, framebuffer at 0xA0000
    mov  ax, 0x0013
    int  0x10

    lgdt [gdt_ptr]              ; load the GDT register (GDTR)

    mov  eax, cr0
    or   eax, 1                 ; set CR0.PE — enables protected mode
    mov  cr0, eax

    ; Far jump flushes the prefetch queue and loads CS with the
    ; 32-bit code segment descriptor (selector 0x08)
    jmp  0x08 : pm_entry

; ════════════════════════════════════════════════════════════════
;  Global Descriptor Table
;  Three 8-byte entries: null, code (0x08), data (0x10)
;  Both code and data span the full 4 GB address space (flat model)
; ════════════════════════════════════════════════════════════════
align 8
gdt:
.null:                          ; required null descriptor
    dq  0
.code:                          ; exec+read, 32-bit, DPL 0, base=0, limit=4 GB
    dw  0xFFFF, 0x0000
    db  0x00, 0x9A, 0xCF, 0x00
.data:                          ; read+write, 32-bit, DPL 0, base=0, limit=4 GB
    dw  0xFFFF, 0x0000
    db  0x00, 0x92, 0xCF, 0x00
.end:

gdt_ptr:
    dw  gdt.end - gdt - 1       ; GDTR limit (size - 1)
    dd  gdt                     ; GDTR base (physical address of GDT)

; ════════════════════════════════════════════════════════════════
;  Protected Mode entry
; ════════════════════════════════════════════════════════════════
[BITS 32]
pm_entry:
    mov  ax, 0x10               ; load all segment registers with data selector
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x90000           ; stack top (plenty of room in conventional RAM)

    call demo

.halt:
    hlt
    jmp  .halt

; ════════════════════════════════════════════════════════════════
;  put_pixel   eax=x (0–319)   ebx=y (0–199)   cl=colour (0–255)
;  Writes one pixel to the VGA framebuffer.
;  Preserves all registers.
; ════════════════════════════════════════════════════════════════
put_pixel:
    push edx
    mov  edx, ebx
    imul edx, edx, 320          ; edx = y × 320
    add  edx, eax               ; edx = y × 320 + x
    mov  byte [0xA0000 + edx], cl
    pop  edx
    ret

; ════════════════════════════════════════════════════════════════
;  fill_rect   eax=x1  ebx=y1  edx=x2  esi=y2  cl=colour
;  Fills an inclusive axis-aligned rectangle with a solid colour.
;  Preserves all registers.
; ════════════════════════════════════════════════════════════════
fill_rect:
    pusha
    mov  edi, eax               ; edi = x1 (constant for this call)
    mov  ebp, ebx               ; ebp = current_y, starts at y1
.row:
    cmp  ebp, esi               ; loop while current_y <= y2
    jg   .done
    mov  eax, edi               ; reset current_x = x1
.col:
    cmp  eax, edx               ; loop while current_x <= x2
    jg   .next_row
    mov  ebx, ebp               ; put_pixel expects y in ebx
    call put_pixel
    inc  eax
    jmp  .col
.next_row:
    inc  ebp
    jmp  .row
.done:
    popa
    ret

; ════════════════════════════════════════════════════════════════
;  demo — animated rectangle bouncing across the screen
;
;  rect:  40 × 30 pixels, colour 4 (red), background colour 1 (dark blue)
;  motion: moves right 2 px/frame, wraps from right edge back to left
; ════════════════════════════════════════════════════════════════

%define RECT_W   40
%define RECT_H   30
%define RECT_Y   85              ; vertical centre (200/2 - RECT_H/2)
%define RECT_COL  4              ; red
%define BG_COL    1              ; dark blue
%define STEP      2              ; pixels per frame
%define DELAY     800000         ; busy-wait iterations between frames

demo:
    xor  ebp, ebp               ; ebp = current rect x (starts at 0)

.frame:
    ; ── clear screen ────────────────────────────────────────────
    push edi
    mov  edi, 0xA0000
    mov  ecx, 320 * 200 / 4
    mov  eax, BG_COL | (BG_COL << 8) | (BG_COL << 16) | (BG_COL << 24)
    rep  stosd
    pop  edi

    ; ── draw rectangle at (ebp, RECT_Y) ─────────────────────────
    mov  eax, ebp               ; x1
    mov  ebx, RECT_Y            ; y1
    lea  edx, [ebp + RECT_W - 1]; x2
    mov  esi, RECT_Y + RECT_H - 1 ; y2
    mov  cl,  RECT_COL
    call fill_rect

    ; ── delay ────────────────────────────────────────────────────
    mov  ecx, DELAY
.wait:
    loop .wait

    ; ── advance x, wrap when rect leaves the right edge ─────────
    add  ebp, STEP
    cmp  ebp, 320               ; once x1 >= 320 the rect is off-screen
    jl   .frame
    xor  ebp, ebp
    jmp  .frame

; ════════════════════════════════════════════════════════════════
;  Boot sector: pad to 510 bytes and append the 0xAA55 signature
; ════════════════════════════════════════════════════════════════
times 510 - ($ - $$) db 0
dw 0xAA55

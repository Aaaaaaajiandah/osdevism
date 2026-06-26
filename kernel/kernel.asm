; kernel.asm — Stage 2 kernel: protected mode + VGA text CLI
;
; Loaded by boot.asm to physical address 0x8000.
; Text buffer: 0xB8000  (80x25 cells, 2 bytes each: char + attribute)
; Attribute 0x07 = light grey on black

%define SCAN_MAX 58

[BITS 16]
[ORG 0x8000]

; ── Real Mode: set text mode, load GDT, enter protected mode ─────────────────
start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7000

    mov  ax, 0x0003      ; VGA mode 3: 80x25 text
    int  0x10

    lgdt [gdt_ptr]

    mov  eax, cr0
    or   eax, 1
    mov  cr0, eax

    jmp  0x08:pm32

align 8
gdt:
    dq   0                        ; null descriptor
    dw   0xFFFF, 0x0000           ; code: base=0, limit=4 GB, exec/read
    db   0x00, 0x9A, 0xCF, 0x00
    dw   0xFFFF, 0x0000           ; data: base=0, limit=4 GB, read/write
    db   0x00, 0x92, 0xCF, 0x00
gdt_end:

gdt_ptr:
    dw   gdt_end - gdt - 1
    dd   gdt

; ── Protected Mode ───────────────────────────────────────────────────────────
[BITS 32]
pm32:
    mov  ax, 0x10
    mov  ds, ax
    mov  es, ax
    mov  fs, ax
    mov  gs, ax
    mov  ss, ax
    mov  esp, 0x90000

    call cli_main
.halt:
    hlt
    jmp  .halt

; ── print_char: al=char ──────────────────────────────────────────────────────
print_char:
    push eax
    push ecx

    cmp  al, 10
    je   .nl
    cmp  al, 8
    je   .bs

    mov  ecx, [cursor_y]
    imul ecx, 80
    add  ecx, [cursor_x]
    shl  ecx, 1
    mov  [0xB8000 + ecx],     al
    mov  byte [0xB8000 + ecx + 1], 0x07
    inc  dword [cursor_x]
    cmp  dword [cursor_x], 80
    jl   .done

.nl:
    mov  dword [cursor_x], 0
    inc  dword [cursor_y]
    cmp  dword [cursor_y], 25
    jl   .done
    call scroll
    mov  dword [cursor_y], 24
    jmp  .done

.bs:
    cmp  dword [cursor_x], 0
    je   .done
    dec  dword [cursor_x]
    mov  ecx, [cursor_y]
    imul ecx, 80
    add  ecx, [cursor_x]
    shl  ecx, 1
    mov  byte [0xB8000 + ecx],     ' '
    mov  byte [0xB8000 + ecx + 1], 0x07

.done:
    pop  ecx
    pop  eax
    ret

; ── scroll: shift all rows up one, blank the last row ────────────────────────
scroll:
    push esi
    push edi
    push ecx
    mov  esi, 0xB8000 + 160      ; row 1
    mov  edi, 0xB8000            ; row 0
    mov  ecx, 80 * 24
    rep  movsw
    mov  edi, 0xB8000 + 80*24*2
    mov  ecx, 80
    mov  ax,  0x0720
    rep  stosw
    pop  ecx
    pop  edi
    pop  esi
    ret

; ── print_str: esi = null-terminated string ───────────────────────────────────
print_str:
    push eax
.lp:
    mov  al, [esi]
    test al, al
    jz   .done
    call print_char
    inc  esi
    jmp  .lp
.done:
    pop  eax
    ret

; ── clear_screen ─────────────────────────────────────────────────────────────
clear_screen:
    push edi
    push ecx
    push eax
    mov  edi, 0xB8000
    mov  ecx, 80 * 25
    mov  ax,  0x0720
    rep  stosw
    mov  dword [cursor_x], 0
    mov  dword [cursor_y], 0
    pop  eax
    pop  ecx
    pop  edi
    ret

; ── read_key: blocks until a key press, returns ASCII in al ──────────────────
read_key:
.wait:
    in   al, 0x64
    test al, 1
    jz   .wait
    in   al, 0x60
    test al, 0x80           ; ignore key-release events
    jnz  .wait
    movzx eax, al
    cmp  eax, SCAN_MAX
    jge  .wait
    mov  al, [scancode_map + eax]
    test al, al
    jz   .wait
    ret

; ── streq: esi=s1, edi=s2 — ZF=1 if strings are equal, clobbers eax ─────────
streq:
    push esi
    push edi
.lp:
    mov  al, [esi]
    cmp  al, [edi]
    jne  .ne
    test al, al
    jz   .eq
    inc  esi
    inc  edi
    jmp  .lp
.eq:
    pop  edi
    pop  esi
    xor  eax, eax    ; ZF = 1
    ret
.ne:
    pop  edi
    pop  esi
    or   eax, 1      ; ZF = 0
    ret

; ── starts_with: esi=str, edi=prefix — ZF=1 if str starts with prefix ────────
starts_with:
    push esi
    push edi
.lp:
    mov  al, [edi]
    test al, al
    jz   .yes
    cmp  al, [esi]
    jne  .no
    inc  esi
    inc  edi
    jmp  .lp
.yes:
    pop  edi
    pop  esi
    xor  eax, eax
    ret
.no:
    pop  edi
    pop  esi
    or   eax, 1
    ret

; ── CLI main loop ─────────────────────────────────────────────────────────────
cli_main:
    call clear_screen
    mov  esi, s_banner
    call print_str

.prompt:
    mov  esi, s_prompt
    call print_str
    mov  dword [cmd_len], 0

.read:
    call read_key
    cmp  al, 10
    je   .enter
    cmp  al, 8
    je   .bs
    mov  ecx, [cmd_len]
    cmp  ecx, 127
    jge  .read
    mov  [cmd_buf + ecx], al
    inc  dword [cmd_len]
    call print_char
    jmp  .read

.bs:
    cmp  dword [cmd_len], 0
    je   .read
    dec  dword [cmd_len]
    mov  al, 8
    call print_char
    jmp  .read

.enter:
    mov  al, 10
    call print_char
    mov  ecx, [cmd_len]
    mov  byte [cmd_buf + ecx], 0
    cmp  ecx, 0
    je   .prompt

    mov  esi, cmd_buf
    mov  edi, s_help
    call streq
    jz   .do_help

    mov  esi, cmd_buf
    mov  edi, s_clear
    call streq
    jz   .do_clear

    mov  esi, cmd_buf
    mov  edi, s_halt
    call streq
    jz   .do_halt

    mov  esi, cmd_buf
    mov  edi, s_echo_pfx
    call starts_with
    jz   .do_echo

    mov  esi, s_unknown
    call print_str
    jmp  .prompt

.do_help:
    mov  esi, s_helptext
    call print_str
    jmp  .prompt

.do_clear:
    call clear_screen
    jmp  .prompt

.do_halt:
    mov  esi, s_halting
    call print_str
.hang:
    hlt
    jmp  .hang

.do_echo:
    mov  esi, cmd_buf + 5    ; skip "echo "
    call print_str
    mov  al, 10
    call print_char
    jmp  .prompt

; ── Data ─────────────────────────────────────────────────────────────────────
s_banner:   db "osdevism kernel v0.1", 10
            db "type 'help' for commands", 10, 10, 0
s_prompt:   db "> ", 0
s_unknown:  db "unknown command", 10, 0
s_helptext: db "  help   show this message", 10
            db "  clear  clear the screen", 10
            db "  echo   print text  (echo hello)", 10
            db "  halt   halt the system", 10, 0
s_halting:  db "halting.", 10, 0
s_help:     db "help",  0
s_clear:    db "clear", 0
s_halt:     db "halt",  0
s_echo_pfx: db "echo ", 0

cursor_x:   dd 0
cursor_y:   dd 0
cmd_len:    dd 0
cmd_buf:    times 128 db 0

; ── Scancode → ASCII map (US QWERTY, unshifted) ──────────────────────────────
scancode_map:
    db 0,   0,  '1','2','3','4','5','6','7','8','9','0','-','=', 8,  0
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 10, 0
    db 'a','s','d','f','g','h','j','k','l',';',"'", '`', 0
    db '\','z','x','c','v','b','n','m',',','.','/', 0, '*', 0, ' '

ENTRY(_start)

SECTIONS {
    . = 0x8000;

    .text : {
        entry.o(.text)      /* entry.asm must be first, at exactly 0x8000 */
        *(.text .text.*)
    }

    .rodata : { *(.rodata .rodata.*) }

    .data : { *(.data .data.*) }

    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        _bss_end = .;
    }
}

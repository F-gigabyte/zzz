PAGE = 0x1000;

LOAD_ADDR = 0xffffffff80000000;
START_ADDR = 2M;

ENTRY(_start);

SECTIONS {
    . = START_ADDR;

    . = ALIGN(PAGE);
    boot_start = .;
    .text.boot : {
        KEEP(*(.text.boot));
        KEEP(*(.text.boot.*));
    }
    . = ALIGN(PAGE);
    .bss.boot : {
        KEEP(*(.bss.boot));
        KEEP(*(.bss.boot.*));
    }
    .data.boot : {
        KEEP(*(.data.boot));
        KEEP(*(.data.boot.*));
    }
    . = ALIGN(PAGE);
    OFFSET = LOAD_ADDR - ((. - START_ADDR + PAGE - 1) & ~(PAGE - 1));

    . = LOAD_ADDR;

    text_virt_start = .;
    text_phys_start = . - OFFSET;
    .text : AT(. - OFFSET) {
        *(.text)
        *(.text.*)
    }
    . = ALIGN(PAGE);

    text_virt_end = .;
    text_phys_end = . - OFFSET;

    data_virt_start = .;
    data_phys_start = . - OFFSET;
    .data : AT(. - OFFSET) {
        *(.data)
        *(.data.*)
    }

    data_virt_end = .;
    data_phys_end = . - OFFSET;

    bss_virt_start = .;
    bss_phys_start = . - OFFSET;
    
    .bss : AT(. - OFFSET) {
        *(.bss)
        *(.bss.*)
    }
    . = ALIGN(PAGE);
    
    bss_virt_end = .;
    bss_phys_end = . - OFFSET;

    rodata_virt_start = .;
    rodata_phys_start = . - OFFSET;
    
    .rodata : AT(. - OFFSET) {
        *(.rodata)
        *(.rodata.*)
    }
    . = ALIGN(PAGE);
    
    rodata_virt_end = .;
    rodata_phys_end = . - OFFSET;
}

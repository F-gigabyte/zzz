PAGE = 0x1000;

LOAD_ADDR = 0xffffffff80000000;
START_ADDR = 2M;

KERNEL_STACK_SIZE = 1K;
STACK_ALIGNMENT = 16;

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

    OFFSET = LOAD_ADDR - .;
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
    bss_virt_end = .;
    bss_phys_end = . - OFFSET;


    . = ALIGN(STACK_ALIGNMENT);
    stack_virt_start = .;
    stack_phys_start = . - OFFSET;

    .stack : AT(. - OFFSET) {
        . += KERNEL_STACK_SIZE;
    }
    
    . = ALIGN(PAGE);
    . = ALIGN(STACK_ALIGNMENT);

    stack_virt_end = .;
    stack_phys_end = . - OFFSET;

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

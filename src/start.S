#define ASM_FILE 1
#include <multiboot2.h>

.code32
.section .text.boot
.globl _start
.type _start, @function
.globl boot_start

.align 8
header_start:
.long MULTIBOOT2_HEADER_MAGIC
.long MULTIBOOT_ARCHITECTURE_I386
.long header_end - header_start
.long - (MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + header_end - header_start)
header_end:
.word 3
.word 0
.long 16
.long _start
.long 0
.word 0
.word 0
.long 8

_start:
    mov $boot_stack, %ebp
    mov %ebp, %esp
    mov $MULTIBOOT2_BOOTLOADER_MAGIC, %ecx
    cmp %eax, %ecx
    jne .
    push %ebx
    push $6
    call find_tag
    add $8, %esp
    mov %cr0, %edx
    and ~(1 << 31), %edx
    mov %edx, %cr0
    mov %cr4, %edx
    or (1 << 5), %edx
    mov %edx, %cr4
    jmp .

// multiboot tags, tag
// 0x8 -> tag
// 0x4 -> multiboot tags
// 0x0 -> ret address
find_tag:
    mov 0x4(%esp), %eax
    mov 0x8(%esp), %edx
    mov (%eax), %ecx
    add %eax, %ecx
1:
    cmp %eax, %ecx
    jge 3f
    push %ecx
    mov (%eax), %ecx
    cmp %edx, %ecx
    pop %ecx
    jne 2f
    ret
2:
    mov 4(%eax), %edx
    add %edx, %eax
    jmp 1b
3:
    mov $0, %eax
    ret

.section .bss.boot
.align 16
.skip 4096
boot_stack:

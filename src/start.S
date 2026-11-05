#define ASM_FILE 1
#include <multiboot2.h>

#define PAGE_PRESENT_SHIFT 0
#define PAGE_PRESENT_MASK (1 << PAGE_PRESENT_SHIFT)
#define PAGE_WRITE_SHIFT 1
#define PAGE_WRITE_MASK (1 << PAGE_WRITE_SHIFT)
#define PAGE_EXECUTE_DISABLE_SHIFT 63
#define PAGE_EXECUTE_DISABLE_MASK (1 << PAGE_EXECUTE_DISABLE_SHIFT)
#define PAGE_BIG_PAGE_SHIFT 7
#define PAGE_BIG_PAGE_MASK (1 << PAGE_BIG_PAGE_SHIFT)

.code32
.section .text.boot
.globl _start
.type _start, @function
.type find_tag, @function
.globl boot_start

.globl pml4
.globl pdpt0
.globl pdpt1
.globl pd0
.globl pd1
.globl pt1

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
    mov $0x80000001, %eax
    cpuid
    mov $(1 << 29), %ecx
    and %ecx, %edx
    cmp %edx, %ecx
    jne .
    push $6
    call find_tag
    add $8, %esp
    mov %cr0, %edx
    and $~(1 << 31), %edx
    mov %edx, %cr0
    mov %cr4, %edx
    or $(1 << 5), %edx
    mov %edx, %cr4
    mov $pml4, %edx
    mov %edx, %cr3
    mov $0xc0000080, %ecx
    rdmsr
    or $(1 << 8), %eax
    wrmsr
    mov %cr0, %edx
    or $(1 << 31), %edx
    mov %edx, %cr0
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
.section .data.boot
.align 4096
pml4:
.quad pdpt0 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.fill 510, 8, 0
.quad pdpt1 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.align 4096
pdpt0:
.quad pd0 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.fill 511, 8, 0
.align 4096
pdpt1:
.fill 510, 8, 0
.quad pd1 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.fill 1, 8, 0
.align 4096
pd0:
.quad PAGE_BIG_PAGE_MASK | PAGE_WRITE_MASK | PAGE_PRESENT_MASK
.quad (2 * 1024 * 1024) | PAGE_BIG_PAGE_MASK | PAGE_WRITE_MASK | PAGE_PRESENT_MASK
.fill 510, 8, 0
.align 4096
pd1:
.quad pt1 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.fill 511, 8, 0
.align 4096
pt1:
.fill 512, 8, 0

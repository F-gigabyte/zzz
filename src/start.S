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

.globl text_virt_start
.globl text_phys_start
.globl text_phys_end
.globl data_virt_start
.globl data_phys_start
.globl stack_phys_end
.globl stack_virt_end
.globl rodata_virt_start
.globl rodata_phys_start
.globl rodata_phys_end

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

_panic:
    hlt
    jmp _panic

_start:
    // initialise stack
    mov $boot_stack, %ebp
    mov %ebp, %esp
    // check is multiboot2 bootloader
    mov $MULTIBOOT2_BOOTLOADER_MAGIC, %ecx
    cmp %eax, %ecx
    jne _panic
    push %ebx
    // check is 64 bit processor
    mov $0x80000001, %eax
    cpuid
    mov $(1 << 29), %ecx
    and %ecx, %edx
    cmp %edx, %ecx
    jne _panic
    // find memory map
    push $6
    call find_tag
    add $8, %esp
    push %eax
    // disable paging
    mov %cr0, %edx
    and $~(1 << 31), %edx
    mov %edx, %cr0
    // enable physical address extension
    mov %cr4, %edx
    or $(1 << 5), %edx
    mov %edx, %cr4
    // load page table
    mov $pml4, %edx
    mov %edx, %cr3
    // enable long mode
    mov $0xc0000080, %ecx
    rdmsr
    or $(1 << 8), %eax
    wrmsr
    // enable paging
    mov %cr0, %edx
    or $(1 << 31), %edx
    mov %edx, %cr0
    jmp _start64
    jmp _panic

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

.code64
.globl kernelMain
.section .text.boot
_start64:
    // write kernel pages
    // text segment
    mov $text_phys_start, %rdi
    mov $text_virt_start, %rsi
    mov $text_phys_end, %rdx
    sub %rdi, %rdx
    mov $PAGE_PRESENT_MASK, %rcx
    call write_section
    // data, bss and stack segment
    mov $data_phys_start, %rdi
    mov $data_virt_start, %rsi
    mov $stack_phys_end, %rdx
    sub %rdi, %rdx
    mov $(PAGE_PRESENT_MASK | PAGE_WRITE_MASK | PAGE_EXECUTE_DISABLE_MASK), %rcx
    call write_section
    // read only data segment
    mov $text_phys_start, %rdi
    mov $text_virt_start, %rsi
    mov $text_phys_end, %rdx
    sub %rdi, %rdx
    mov $(PAGE_PRESENT_MASK | PAGE_EXECUTE_DISABLE_MASK), %rcx
    call write_section
    mov $stack_virt_end, %rbp
    mov %rbp, %rsp
    jmp *kernelMain

// rdi -> phys start (multiple of 4096)
// rsi -> virt start
// rdx -> len (multiple of 4096)
// rcx -> permission mask
write_section:
    sub $0xffffffff80000000, %rsi
    add $pt1, %rsi
    mov $0, %r9
1:
    cmpq %rdx, %r9
    je 2f
    xor %rdi, %rcx
    mov %rcx, 0(%rsi)
    xor %rdi, %rcx
    add $0x1000, %rdi
    add $0x1000, %rsi
    sub $0x1000, %rdx
    jmp 1b
2:
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

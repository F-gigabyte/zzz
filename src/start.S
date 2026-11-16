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

#define CR0_PAGING_SHIFT 31
#define CR0_PAGING_MASK (1 << CR0_PAGING_SHIFT)
#define CR0_PM_SHIFT 0
#define CR0_PM_MASK (1 << CR0_PM_SHIFT)

#define CR4_PAE_SHIFT 5
#define CR4_PAE_MASK (1 << CR4_PAE_SHIFT)

#define MSR_EFER 0xc0000080

#define EFER_LM_SHIFT 8
#define EFER_LM_MASK (1 << EFER_LM_SHIFT)
#define EFER_NX_SHIFT 11
#define EFER_NX_MASK (1 << EFER_NX_SHIFT)

#define GDT_ACCESS_PRESENT_SHIFT 7
#define GDT_ACCESS_PRESENT_MASK (1 << GDT_ACCESS_PRESENT_SHIFT)
#define GDT_ACCESS_NOT_SYS_SHIFT 4
#define GDT_ACCESS_NOT_SYS_MASK (1 << GDT_ACCESS_NOT_SYS_SHIFT)
#define GDT_ACCESS_EXEC_SHIFT 3
#define GDT_ACCESS_EXEC_MASK (1 << GDT_ACCESS_EXEC_SHIFT)
#define GDT_ACCESS_DIRECTION_SHIFT 2
#define GDT_ACCESS_DIRECTION_MASK (1 << GDT_ACCESS_DIRECTION_SHIFT)
#define GDT_ACCESS_READ_WRITE_SHIFT 1
#define GDT_ACCESS_READ_WRITE_MASK (1 << GDT_ACCESS_READ_WRITE_SHIFT)

#define GDT_FLAG_PAGE_SHIFT 3
#define GDT_FLAG_PAGE_MASK (1 << GDT_FLAG_PAGE_SHIFT)
#define GDT_FLAG_SIZE_SHIFT 2
#define GDT_FLAG_SIZE_MASK (1 << GDT_FLAG_SIZE_SHIFT)
#define GDT_FLAG_LONG_MODE_SHIFT 1
#define GDT_FLAG_LONG_MODE_MASK (1 << GDT_FLAG_LONG_MODE_SHIFT)

#define TAG_FRAMEBUFFER 8
#define TAG_FRAMEBUFFER_ADDR_OFFSET 8
#define TAG_FRAMEBUFFER_PITCH_OFFSET 16
#define TAG_FRAMEBUFFER_WIDTH_OFFSET 20
#define TAG_FRAMEBUFFER_HEIGHT_OFFSET 24
#define TAG_FRAMEBUFFER_BPP_OFFSET 25
#define TAG_FRAMEBUFFER_TYPE_OFFSET 26
#define TAG_FRAMEBUFFER_RED_FIELD_POS_OFFSET 27
#define TAG_FRAMEBUFFER_RED_MASK_SIZE_OFFSET 28
#define TAG_FRAMEBUFFER_GREEN_FIELD_POS_OFFSET 29
#define TAG_FRAMEBUFFER_GREEN_MASK_SIZE_OFFSET 30
#define TAG_FRAMEBUFFER_BLUE_FIELD_POS_OFFSET 31
#define TAG_FRAMEBUFFER_BLUE_MASK_SIZE_OFFSET 32

#define TAG_MEMMAP 6

.code32
.section .text.boot
.globl _start
.type _start, @function
.type find_tags, @function
.globl boot_start


.align 8
header_start:
.long MULTIBOOT2_HEADER_MAGIC
.long MULTIBOOT_ARCHITECTURE_I386
.long header_end - header_start
.long - (MULTIBOOT2_HEADER_MAGIC + MULTIBOOT_ARCHITECTURE_I386 + header_end - header_start)
header_end:
// frame buffer tag
.word 5
.word 0
.long 20
.long 0
.long 0
.long 0
// padding
.long 0
// end tag
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
    push $0
    push %ebx
    // check is multiboot2 bootloader
    mov $MULTIBOOT2_BOOTLOADER_MAGIC, %ecx
    cmp %eax, %ecx
    jne _panic
    // check is 64 bit processor
    mov $0x80000001, %eax
    cpuid
    mov $(1 << 29), %ecx
    and %ecx, %edx
    cmp %edx, %ecx
    jne _panic
    // disable paging
    mov %cr0, %edx
    and $~CR0_PAGING_MASK, %edx
    mov %edx, %cr0
    // enable physical address extension
    mov %cr4, %edx
    or $CR4_PAE_MASK, %edx
    mov %edx, %cr4
    // load page table
    mov $pml4, %edx
    mov %edx, %cr3
    // enable long mode
    mov $MSR_EFER, %ecx
    rdmsr
    or $(EFER_LM_MASK | EFER_NX_MASK), %eax
    wrmsr
    // enable paging
    mov %cr0, %edx
    or $(CR0_PAGING_MASK | CR0_PM_MASK), %edx
    mov %edx, %cr0
    lgdt GDT_pointer
    ljmp $GDT_code,$_start64
    jmp _panic

.code64
.globl kernelMain

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

.section .text.boot
_start64:
    mov $GDT_data, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %fs
    mov %ax, %gs
    mov %ax, %ss
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
    mov $rodata_phys_start, %rdi
    mov $rodata_virt_start, %rsi
    mov $rodata_phys_end, %rdx
    sub %rdi, %rdx
    mov $(PAGE_PRESENT_MASK | PAGE_EXECUTE_DISABLE_MASK), %rcx
    call write_section
    
    pop %rbx

    mov %rbx, %rcx
    push $0
    push $0
    mov %rsp, %rdi
    push $TAG_MEMMAP
    push $TAG_FRAMEBUFFER
    mov %rsp, %rsi
    mov $2, %rdx
    call find_tags
    // remove input tags
    add $16, %rsp
    // framebuffer tag
    pop %r12
    // memmap tag
    pop %r13

    mov TAG_FRAMEBUFFER_TYPE_OFFSET(%rax), %rdi
    mov $1, %rsi
    cmp %rdi, %rsi
    jne _panic

    mov TAG_FRAMEBUFFER_BPP_OFFSET(%rax), %rdi
    mov $32, %rsi
    cmp %rdi, %rsi
    jne _panic

    mov TAG_FRAMEBUFFER_PITCH_OFFSET(%rax), %rdx
    mov TAG_FRAMEBUFFER_HEIGHT_OFFSET(%rax), %rcx
    mul %rcx, %rdx
    mul $4, %rdx

    mov %cr3, %rdi
    mov %rdi, %cr3
    mov %rbx, %rdi
    mov $stack_virt_end, %rbp
    mov %rbp, %rsp
    mov $kernelMain, %rsi
    jmp *%rsi
1:
    hlt
    jmp 1b

// find multiboot tags
// rdi -> output buffer
// rsi -> input tags pointer
// rdx -> number of tags
// rcx -> multiboot information structure
// Returns
// rax -> rdi
find_tags:
    // save r12
    push %r12
    mov $0, %r9
    // get rax ready
    mov %rdi, %rax
    mov $0, %rdi
    // number of tags left to find
    mov %rdx, %r10
    // rdx in bytes
    shl $3, %rdx
    // zero out output buffer
1:
    cmp %r9, %rdx
    jge 2f
    mov %rdi, %r9(%rax)
    add $8, %r9
    jmp 1b
2:
    // total size
    mov 0x0(%rcx), %r8
    // end address
    add %rcx, %r8
    // first tag
    add $0x8, %rcx
1:
    // check haven't incremented too far
    cmp %rcx, %r8
    jge 5f
    // check we still have unknown tags
    cmp %rdi, %r11
    jeq 5f
    mov (%rcx), %r9
    // increment through tags to see if have match and if so, decrement r10
    mov $0, %r11
4:
    // check haven't incremented beyond all the tags
    cmp %r11, %rdx
    // if so, exit
    jge 2f
    // load output tag
    mov %r11(%rax), %r12
    // check it's zero
    cmp %r12, %rdi
    // if not, increment
    jne 3f
    // get the input tag
    mov %r11(%rsi), %r12
    // check tags match
    cmp %r12, %r9
    // if not, increment
    jne 3f
    // if tags match, store offset
    mov %rcx, %r11(%rax)
    // decment r10 by 1
    sub $1, %r10
3:
    // increment r11 by 8 bytes and repeat loop
    add $8, %r11
    jmp 4b
2:
    // get length
    mov 0x8(%rcx), %r9
    // increment by length
    add %r9, %rcx
    // align to 8 bytes
    add $7, %rcx
    and $~0x7, %rcx
    jmp 1b
3:
    pop r12
    ret


// rdi -> phys start (multiple of 4096)
// rsi -> virt start
// rdx -> len (multiple of 4096)
// rcx -> permission mask
write_section:
    sub $0xffffffff80000000, %rsi
    shr $12, %rsi
    shl $3, %rsi
    add $pt1, %rsi
    mov $0, %r9
1:
    cmpq %rdx, %r9
    je 2f
    xor %rdi, %rcx
    mov %rcx, 0(%rsi)
    xor %rdi, %rcx
    add $0x1000, %rdi
    add $8, %rsi
    sub $0x1000, %rdx
    jmp 1b
2:
    ret

// rdi -> memmap tag
// Returns
// rax -> address
// rdx -> 0 if not found and 1 otherwise
find_page:

.section .bss.boot
.align 16
.skip 4096
boot_stack:
.section .data.boot
.align 4096
pml4:
.quad pdpt0 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
.fill 509, 8, 0
.quad pml4 + (PAGE_WRITE_MASK | PAGE_PRESENT_MASK)
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
GDT:
// null
.quad 0
// code
.equ GDT_code, . - GDT
.word 0xffff
.word 0x0000
.byte 0x00
.byte (GDT_ACCESS_PRESENT_MASK | GDT_ACCESS_NOT_SYS_MASK | GDT_ACCESS_EXEC_MASK | GDT_ACCESS_READ_WRITE_MASK)
.byte (((GDT_FLAG_PAGE_MASK | GDT_FLAG_LONG_MODE_MASK) << 4) | 0xf)
.byte 0
// data
.equ GDT_data, . - GDT
.word 0xffff
.word 0x0000
.byte 0x00
.byte (GDT_ACCESS_PRESENT_MASK | GDT_ACCESS_NOT_SYS_MASK | GDT_ACCESS_READ_WRITE_MASK)
.byte (((GDT_FLAG_PAGE_MASK | GDT_FLAG_SIZE_MASK) << 4) | 0xf)
.byte 0
// pointer
GDT_pointer:
.word . - GDT - 1
.quad GDT
.align 8
mepmap_addr:
.quad 0

const std = @import("std");
const multiboot = @import("multiboot.zig");
const MemoryMapTag = multiboot.MemoryMapTag;
const TagHeader = multiboot.TagHeader;
const vm = @import("vm.zig");

extern const _kernel_phys_start: usize;
extern const _kernel_phys_end: usize;

var buddy_sizes = [_]u64{
    0, // 4K
    0, // 8K
    0, // 16K
    0, // 32K
    0, // 64K
    0, // 128K
    0, // 256K
    0, // 512K
};

const bitmap: [*]u64 = @ptrFromInt(0xffffffff80200000);

var memory_start: u64 = std.math.maxInt(u64);

fn getPagesRequired(memory_size: u64) struct {usize, usize} {
    const memory_pages = @divCeil(memory_size, 0x1000);
    var num_quads: u64 = 0;
    var divisor: u64 = 256;
    while (divisor > 0) {
        num_quads += @divCeil(@divCeil(memory_pages, divisor * 8), @sizeOf(u64) * 8);
        divisor /= 2;
    }
    const quads_per_page = 0x1000 / @sizeOf(u64);
    const num_pages = @divCeil(num_quads, quads_per_page);
    const mapping_pages =  if (num_pages % 512 != 0) 1 else 0;
    return .{
        @intCast(num_pages),
        @intCast(mapping_pages),
    };
}

const PageAllocatorError = error {
    OutOfMemory,
};

pub fn init(mem_map: MemoryMapTag) PageAllocatorError!void {
    const num_entries = (mem_map.header.size - @sizeOf(TagHeader)) / mem_map.entry_size;
    var memory_end: u64 = 0;
    for (0..num_entries) |i| {
        const entry = mem_map.entry(i);
        if (entry.mem_type == .available) {
            if (entry.addr < memory_start) {
                memory_start = entry.addr;
            }
            if (entry.addr + entry.length > memory_end) {
                memory_end = entry.addr + entry.length;
            }
        }
    }
    const memory_size: u64 = if (memory_start < memory_end) memory_end - memory_start else 0;
    const large_page: u64 = 2 * 1024 * 1024;
    const page: u64 = 0x1000;
    var pages, const mapping_pages = getPagesRequired(memory_size); 
    const pages_required = pages + mapping_pages;
    const requires_align = pages >= (large_page / page);
    const kernel_start_addr: usize = @intFromPtr(_kernel_phys_start);
    const kernel_end_addr: usize = @intFromPtr(_kernel_phys_end);
    var header_addr: ?u64 = null;
    for (0..num_entries) |i| {
        const entry = mem_map.entry(i);
        if (entry.mem_type == .available) {
            var start_addr = entry.addr;
            const end_addr = entry.addr + entry.length;
            if (start_addr >= kernel_start_addr and start_addr < kernel_end_addr) {
                start_addr = kernel_end_addr;
            }
            if (requires_align) {
                start_addr = (start_addr + large_page - 1) & ~(large_page - 1);
            } else {
                start_addr = (start_addr + page - 1) & ~(page - 1);
            }
            if (start_addr < end_addr and (end_addr - start_addr) / page >= pages_required) {
                header_addr = start_addr;
                break;
            }
        }
    }
    if (header_addr) |*header| {
        const end_addr = header + pages_required * 0x1000;
        var index: u9 = 1;
        while (pages > large_page / page) {
            vm.mapPage2M(511, 510, index, header, .{
                .writable = true,
                .executable = false,
                .user = false,
            });
            index += 1;
            header.* += large_page;
            pages -= large_page / page;
        }
        if (pages != 0) {
            vm.mapPdPt(511, 510, index, end_addr - 0x1000, false);
            for (0..pages) |index2| {
                vm.mapPage4K(511, 510, index, index2, header.*, .{
                    .writable = true,
                    .executable = false,
                    .user = false,
                });
                header.* += page;
            }
        }
        var divisor = 1;
        const memory_pages = @divCeil(memory_size, page);
        var total_quads: u64 = 0;
        for (buddy_sizes) |*val| {
            val.* = @divCeil(@divCeil(memory_pages, divisor * 8), @sizeOf(u64) * 8);
            total_quads += val.*;
            divisor *= 2;
        }
        @memset(bitmap[0..total_quads], std.math.maxInt(u64));
        for (0..num_entries) |i| {
            const entry = mem_map.entry(i);
            if (entry.mem_type == .available) {
            }
        }
    } else {
        return PageAllocatorError.OutOfMemory;
    }
}

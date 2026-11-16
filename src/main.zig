const std = @import("std");

const multiboot = @import("multiboot.zig");
const BootInfoHeader = multiboot.BootInfoHeader;
const FramebufferTag = multiboot.FramebufferTag;
const MemoryMapTag = multiboot.MemoryMapTag;
const MemoryMapEntry = multiboot.MemoryMapEntry;
const FrameBuffer = @import("framebuffer.zig").FrameBuffer;

pub export fn kernelMain(multiboot_header: u32) callconv(.c) void {
    const header: *const BootInfoHeader = @ptrFromInt(multiboot_header);
    const mem_map = multiboot.findTag(MemoryMapTag, header, .memory_map) orelse unreachable; 
    var i: usize = 0;
    const entries = (mem_map.header.size - 16) / mem_map.entry_size;
    while (i < entries) {
        const entry: *const MemoryMapEntry = @ptrFromInt(@intFromPtr(mem_map.entries()) + i * mem_map.entry_size);
        _ = entry;
        i += 1;
    }
    var framebuffer = FrameBuffer.init(multiboot.findTag(FramebufferTag, header, .framebuffer).?.*) orelse unreachable; 
    framebuffer.drawRect(0, 500, 0, 400, 0x00, 0xff, 0x00);
    while (true) {}
}


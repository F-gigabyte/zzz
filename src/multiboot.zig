pub const BootInfoHeader = extern struct {
    total_size: u32,
    reserved: u32,
};

pub const TagType = enum(u32) {
    end = 0,
    memory_map = 6,
    framebuffer = 8,
    _,
};

pub const TagHeader = extern struct {
    tag_type: TagType,
    size: u32,
};

pub const MemoryType = enum(u32) {
    available = 1,
    acpi = 3,
    hibernate = 4,
    defective = 5,
    _,
};

pub const MemoryMapEntry = extern struct {
    addr: u64,
    length: u64,
    mem_type: MemoryType,
    reserved: u32,
};

pub const MemoryMapTag = extern struct {
    header: TagHeader,
    entry_size: u32,
    entry_version: u32,
    _entries: [0]MemoryMapEntry,

    const Self = @This();

    pub fn entry(self: *const Self, index: usize) *const MemoryMapEntry {
        return @ptrFromInt(@intFromPtr(self._entries) + index * self.entry_size);
    }
};

pub const ColorDescriptor = extern struct {
    red: u8,
    green: u8,
    blue: u8,
};

pub const IndexedColor = extern struct {
    num_colors: u32,
    _palette: [0]ColorDescriptor,

    const Self = @This();
    pub fn palette(self: *const Self) [*]const ColorDescriptor {
        return &self._palette;
    }
};

pub const RGBColor = extern struct {
    red_pos: u8,
    red_mask_len: u8,
    green_pos: u8,
    green_mask_len: u8,
    blue_pos: u8,
    blue_mask_len: u8,
};

pub const ColorInfo = extern union {
    indexed: IndexedColor,
    rgb: RGBColor,
};

pub const FramebufferType = enum(u8) {
    indexed_color = 0,
    rgb_color = 1,
    ega_text = 2,
    _,
};

pub const FramebufferTag = extern struct {
    header: TagHeader,
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
    framebuffer_type: FramebufferType,
    reserved: u8,
    color_info: ColorInfo,
};

pub fn findTag(Tag: type, header: *const BootInfoHeader, tag_type: TagType) ?*const Tag {
    const len = header.total_size - 8;
    var offset: u32 = 8;
    while (offset < len) {
        const tag_header: *const TagHeader = @ptrFromInt(@intFromPtr(header) + offset);
        if (tag_header.tag_type == tag_type) {
            return @ptrCast(@alignCast(tag_header));
        } else {
            offset += tag_header.size;
            offset = (offset + 7) & ~@as(u32, 7);
        }
    }
    return null;
}

const multiboot = @import("multiboot.zig");
const FramebufferTag = multiboot.FramebufferTag;

const ColorInfo = struct {
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
    red_shift: u8,
    green_shift: u8,
    blue_shift: u8,
};

pub const FrameBuffer = struct {
    buffer: []volatile u32,
    pitch: u32,
    width: u32,
    height: u32,
    color_info: ColorInfo,

    const Self = @This();

    pub fn init(tag: FramebufferTag) ?Self {
        if (tag.framebuffer_type != .rgb_color or tag.bpp != 32) {
            return null;
        }
        return Self {
            .buffer = @as([*]u32, @ptrFromInt(tag.addr))[0..tag.pitch * tag.height],
            .width = tag.width,
            .height = tag.height,
            .pitch = tag.pitch,
            .color_info = ColorInfo {
                .red_mask = (@as(u32, 1) <<| tag.color_info.rgb.red_mask_len) -% 1,
                .green_mask = (@as(u32, 1) <<| tag.color_info.rgb.green_mask_len) -% 1,
                .blue_mask = (@as(u32, 1) <<| tag.color_info.rgb.blue_mask_len) -% 1,
                .red_shift = tag.color_info.rgb.red_pos,
                .green_shift = tag.color_info.rgb.green_pos,
                .blue_shift = tag.color_info.rgb.blue_pos,
            },
        };
    }

    fn getPixel(self: Self, r: u8, g: u8, b: u8) u32 {
        var res: u32 = 0;
        res |= (r & self.color_info.red_mask) << @intCast(self.color_info.red_shift); 
        res |= (g & self.color_info.green_mask) << @intCast(self.color_info.green_shift); 
        res |= (b & self.color_info.blue_mask) << @intCast(self.color_info.blue_shift); 
        return res;
    }

    pub fn drawPixel(self: *Self, x: u32, y: u32, r: u8, g: u8, b: u8) void {
        if (x >= self.width or y >= self.height) {
            unreachable;
        }
        self.buffer[y * self.pitch + x] = self.getPixel(r, g, b);
    }

    pub fn drawRect(self: *Self, x1: u32, x2: u32, y1: u32, y2: u32, r: u8, g: u8, b: u8) void {
        if (x1 >= self.width or x2 >= self.width or y1 >= self.height or y2 >= self.height) {
            unreachable;
        }
        for (x1..x2) |x| {
            for (y1..y2) |y| {
                self.buffer[y * self.pitch + x] = self.getPixel(r, g, b);
            }
        }
    }
};

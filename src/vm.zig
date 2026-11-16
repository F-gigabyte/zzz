const std = @import("std");

pub const pml4_address: usize = 0xffffff7fbfdfe000;
pub const pdp_address: usize = 0xffffff7fbfc00000;
pub const pd_address: usize = 0xffffff7f80000000;
pub const pt_address: usize = 0xffffff0000000000;

pub const PageFlags = struct {
    writable: bool,
    executable: bool,
    user: bool,
};

const TableEntry = packed struct {
    present: u1,
    writable: u1,
    user: u1,
    write_through: u1,
    cache_disable: u1,
    accessed: u1 = 0,
    dirty: u1 = 0,
    page_size: u1,
    global: u1,
    reserved0: u3 = 0,
    addr: u40,
    reserved1: u7 = 0,
    protection_key: u4,
    xd: u1,
};

pub fn indexPdp(pdp: u9) usize {
    return pdp_address | ((pdp * @sizeOf(u64)) << 12);
}

pub fn indexPd(pdp: u9, pd: u9) usize {
    return pd_address | ((pdp * @sizeOf(u64)) << 21) | ((pd * @sizeOf(u64)) << 12);
}

pub fn indexPt(pdp: u9, pd: u9, pt: u9) usize {
    return pt_address | ((pdp * @sizeOf(u64)) << 30) | ((pd * @sizeOf(u64)) << 21) | ((pt * @sizeOf(u64)) << 21);
}

fn mapSubTable(table: *volatile [512]TableEntry, index: u9, sub_table_addr: u52, user: bool) void {
    table[index] = TableEntry {
        .present = 1,
        .addr = @intCast(sub_table_addr >> 12),
        .cache_disable = 0,
        .page_size = 0,
        .global = 0,
        .protection_key = 0,
        .writable = 1,
        .user = @intFromBool(user),
        .write_through = 0,
        .xd = 0,
    };
}

fn mapBigPage(table: *volatile [512]TableEntry, index: u9, page_addr: u52, flags: PageFlags) void {
    table[index] = TableEntry {
        .present = 1,
        .addr = @intCast(page_addr >> 12),
        .cache_disable = 0,
        .page_size = 1,
        .global = 0,
        .protection_key = 0,
        .writable = @intFromBool(flags.writable),
        .user = @intFromBool(flags.user),
        .write_through = 0,
        .xd = @intFromBool(!flags.executable),
    };
}

fn mapPage(table: *volatile [512]TableEntry, index: u9, page_addr: u52, flags: PageFlags) void {
    table[index] = TableEntry {
        .present = 1,
        .addr = @intCast(page_addr >> 12),
        .cache_disable = 0,
        .page_size = 0,
        .global = 0,
        .protection_key = 0,
        .writable = @intFromBool(flags.writable),
        .user = @intFromBool(flags.user),
        .write_through = 0,
        .xd = @intFromBool(!flags.executable),
    };
}

pub fn mapPml4Pdp(index: u9, pdp_addr: u52, user: bool) void {
    const addr = pml4_address;
    mapSubTable(@ptrCast(addr), index, pdp_addr, user);
    @memset(@as(*volatile u64[512], @ptrFromInt(indexPdp(index))), 0);
}

pub fn mapPdpPd(pdp: u9, index: u9, pd_addr: u52, user: bool) void {
    const addr = indexPdp(pdp);
    mapSubTable(@ptrFromInt(addr), index, pd_addr, user);
    @memset(@as(*volatile u64[512], @ptrFromInt(indexPd(pdp, index))), 0);
}

pub fn mapPage1G(pdp: u9, index: u9, page_addr: u52, flags: PageFlags) void {
    const gig_mask: u52 = ~(1024 * 1024 * 1024 - 1);
    const addr = indexPdp(pdp);
    mapBigPage(@ptrFromInt(addr), index, page_addr & gig_mask, flags);
}

pub fn mapPdPt(pdp: u9, pd: u9, index: u9, pt_addr: u52, user: bool) void {
    const addr = indexPd(pdp, pd);
    mapSubTable(@ptrCast(addr), index, pt_addr, user);
    @memset(@as(*volatile u64[512], @ptrFromInt(indexPt(pdp, pd, index))), 0);
}

pub fn mapPage2M(pdp: u9, pd: u9, index: u9, page_addr: u52, flags: PageFlags) void {
    const mb_mask: u52 = ~(2 * 1024 * 1024 - 1);
    const addr = indexPd(pdp, pd);
    mapBigPage(@ptrFromInt(addr), index, page_addr & mb_mask, flags);
}

pub fn mapPage4K(pdp: u9, pd: u9, pt: u9, index: u9, page_addr: u52, flags: PageFlags) void {
    const page_mask: u52 = ~(0x1000 - 1);
    const addr = indexPt(pdp, pd, pt);
    mapSubTable(@ptrFromInt(addr), index, page_addr & page_mask, flags);
}

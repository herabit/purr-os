pub const MasterBootRecord = extern struct {
    bootstrap: [440]u8 = [_]u8{0} ** 440,
    unique_id: u32 align(1) = 0,
    reserved: Reserved align(1) = Reserved.zero,
    partition_table: [4]Partition align(1),
    signature: Signature align(1),

    pub inline fn fromUnaligned(bytes: []u8) !*align(1) @This() {
        if (bytes.len >= @sizeOf(@This())) {
            return @ptrCast(bytes.ptr);
        } else return error.BufferIsTooSmall;
    }
};

pub const Partition = extern struct {
    flags: Flags = .{},
    start_chs: [3]u8 = [_]u8{0} ** 3,
    system_id: u8 = 0,
    end_chs: [3]u8 = [_]u8{0} ** 3,
    relative_sector: u32 align(1) = 0,
    sector_len: u32 align(1) = 0,

    pub const Flags = packed struct(u8) {
        _padding: u7 = 0,
        bootable: bool = false,
    };
};

pub const Reserved = enum(u16) { zero = 0x0000, read_only = 0x5A5A, _ };

pub const Signature = enum(u16) {
    valid = valid_bootsector,
    _,

    const valid_bootsector = switch (native_endian) {
        .big => 0x55AA,
        .little => 0xAA55,
    };

    pub inline fn is_valid(self: @This()) bool {
        return self == .valid;
    }
};

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const native_endian = builtin.cpu.arch.endian();

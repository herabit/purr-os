pub const Color = @import("color").Bios;
pub const Style = Color.Style;

pub const MasterBootRecord = @import("mbr").MasterBootRecord;

/// Write a string to the teletype output.
pub export fn writeString(string: [*:0]const u8, style: Style) callconv(.C) void {
    writeStringInline(string, style);
}

/// Enable color output
pub inline fn enableColor() void {
    asm volatile (
        \\ .code16;
        \\ int $0x10
        :
        : [_] "{ax}" (0x0012),
    );
}

pub inline fn writeStringInline(string: [*:0]const u8, style: Style) void {
    var ptr: [*]const u8 = string;

    while (ptr[0] != 0) : (ptr += 1) {
        writeChar(ptr[0], style);
    }
}

/// Write a character to the teletype output.
pub inline fn writeChar(ch: u8, style: Style) void {
    asm volatile (
        \\ .code16;
        \\ int $0x10
        :
        : [_] "{ax}" (0x0e00 | @as(u16, ch)),
          [_] "{bx}" (0x0000 | @as(u16, style.to_bits())),
    );
}

pub const DiskAddressPacket = extern struct {
    size: u8 = 0x10,
    zero: u8 = 0,
    sectors: u16 align(1),
    target_offset: u16 align(1),
    target_segment: u16 align(1),
    start_lba: u64 align(1),

    pub inline fn new(start_lba: u64, sectors: u16, target: [*]u8) !Self {
        const target_bits: u32 = @bitCast(@intFromPtr(target));
        const t_offset: u16 = math.cast(u16, target_bits) orelse return error.InvalidTarget;

        return .{
            .sectors = sectors,
            .target_offset = t_offset,
            .target_segment = 0,
            .start_lba = start_lba,
        };
    }

    pub inline fn load(self: *Self, disk: u16) !void {
        const dap_addr: u16 = @truncate(@intFromPtr(self));
        var result: u8 = 0;

        asm volatile (
            \\ .code16;
            \\ int $0x13
            \\ setc %[res]
            : [res] "=r" (result),
            : [addr] "{si}" (dap_addr),
              [_] "{ax}" (0x4200),
              [_] "{dx}" (disk),
            : "cc", "ax"
        );

        if (result != 0) return error.UnknownError;
    }

    const Self = @This();
};

const std = @import("std");
const math = std.math;

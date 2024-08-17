comptime {
    asm (
        \\ .section .boot, "awx";
        \\ .global _start;
        \\ .code16;
        \\ _start:
        // Disable interrupts
        \\ cli
        //  Zero the segment registers
        \\ xor %ax, %ax
        \\ mov %ax, %ds
        \\ mov %ax, %es
        \\ mov %ax, %ss
        \\ mov %ax, %fs
        \\ mov %ax, %gs

        // Clear the direction flag
        \\ cld

        // Setup the stack
        \\ mov $0x7c00, %sp

        // Jump to Stage 1
        \\ call _stage1
        \\
        \\ spin:
        \\ hlt
        \\ jmp spin
    );
}

const std = @import("std");
const math = std.math;
const bios = @import("./util.zig");
const Mbr = bios.MasterBootRecord;
const Dap = bios.DiskAddressPacket;

extern var _mbr_start: Mbr;
extern var _stage2_start: anyopaque;

export fn _stage1() callconv(.C) noreturn {
    bios.enableColor();

    bios.writeString("Loading stage 2...\r\n", .{ .fg = .light_green });

    if (loadStage2()) |_| {
        runStage2();
    } else |_| {
        bios.writeString("Failed to load stage 2.\r\n", .{ .fg = .light_red });
    }

    while (true) {}
}

inline fn loadStage2() !void {
    const partition = &_mbr_start.partition_table[0];

    if (!partition.flags.bootable or partition.sector_len == 0) return error.NotBootable;

    var sectors = math.cast(u16, partition.sector_len) orelse return error.InvalidSectors;
    var sector = @as(u64, partition.relative_sector);
    var target: [*]u8 = @ptrCast(&_stage2_start);

    // TODO: There is a better way to do this, I'm just tired and lazy.
    while (sectors != 0) {
        var dap = try Dap.new(sector, sectors, target);
        try dap.load(0x0080);

        sectors -= 1;
        sector += 1;
        target += 512;
    }
}

const Stage2Fn = *const fn () callconv(.C) noreturn;

inline fn runStage2() noreturn {
    const stage2: Stage2Fn = @ptrCast(&_stage2_start);

    stage2();
}

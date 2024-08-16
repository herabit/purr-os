// const std = @import("std");
const bios = @import("./util.zig");

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
        \\ call _stage_1
        \\
        \\ spin:
        \\ hlt
        \\ jmp spin
    );
}

pub export fn _stage_1() callconv(.C) noreturn {
    bios.enable_color();
    bios.write_string("Hello World!", .{ .fg = .light_red, .bg = .blue });
    while (true) {}
}

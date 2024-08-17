const bios = @import("./util.zig");
const std = @import("std");

comptime {
    @export(_stage2, .{
        .name = "_start",
        .linkage = .strong,
        .section = ".start",
    });
}

fn _stage2() callconv(.C) noreturn {
    bios.writeString("Hello from stage 2!", .{ .fg = .light_green });
    while (true) {}
}

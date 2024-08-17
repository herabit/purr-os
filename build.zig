const std = @import("std");
const Target = std.Target;
const Query = Target.Query;
const Feature = Target.Cpu.Feature;
const features = Target.x86.Feature;

const Bios = @import("./build/BiosStep.zig");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const bios_step = Bios.create(b, .{ .name = "bios-boot" });
    const bios_install = b.addInstallFile(bios_step.getOutput(), "bios.bin");
    bios_install.step.dependOn(&bios_step.step);

    b.default_step.dependOn(&bios_install.step);
}

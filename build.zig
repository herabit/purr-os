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
    const bios_install = b.addInstallBinFile(bios_step.getOutput(), "bios.bin");
    bios_install.step.dependOn(&bios_step.step);

    b.default_step.dependOn(&bios_install.step);
}

// fn build_bios(b: *std.Build) void {
//     const code16_target = b.resolveTargetQuery(.{
//         .cpu_arch = Target.Cpu.Arch.x86,
//         .os_tag = Target.Os.Tag.freestanding,
//         .abi = Target.Abi.none,
//         .ofmt = .elf,
//         .cpu_features_add = enabled: {
//             var set = Feature.Set.empty;

//             set.addFeature(@intFromEnum(features.@"16bit_mode"));

//             break :enabled set;
//         },
//     });

//     const stage1 = b.addObject(.{
//         .name = "stage1",
//         .target = code16_target,
//         .root_source_file = b.path("src/bios/stage1.zig"),
//         .optimize = .ReleaseSmall,
//         .code_model = .kernel,
//         .link_libc = false,
//         .single_threaded = true,
//         .pic = false,
//         .use_lld = true,
//         // .linkage = .static,
//     });

//     // stage1.setLinkerScript(b.path("src/bios/stage1.ld"));

//     const link = b.addObject(.{
//         .name = "bios-boot",
//         .target = code16_target,
//         .optimize = .ReleaseSmall,
//         .code_model = .kernel,
//         .link_libc = false,
//         // .linkage = .static,
//         .single_threaded = true,
//         .pic = false,
//         .use_lld = true,
//     });

//     // link.setVerboseLink(true);
//     // link.use_lld = true;

//     link.addObject(stage1);
//     link.setLinkerScript(b.path("src/bios/linker.ld"));
//     link.link_z_max_page_size = 512;
//     // link.entry = .{ .symbol_name = "_start" };

//     const bios = link.addObjCopy(.{
//         .basename = "bios",
//         .format = .bin,
//         .pad_to = 512,
//     });

//     bios.step.dependOn(&link.step);

//     var install = b.addInstallFile(bios.getOutput(), "bios.bin");
//     install.step.dependOn(&bios.step);

//     install = blk: {
//         var i = b.addInstallFile(link.getEmittedBin(), "bios");
//         i.step.dependOn(&install.step);

//         break :blk i;
//     };

//     install = blk: {
//         var i = b.addInstallFile(stage1.getEmittedBin(), "stage1.o");
//         i.step.dependOn(&install.step);

//         break :blk i;
//     };

//     b.default_step.dependOn(&install.step);

//     // stage1.setLinkerScript(b.path("src/bios-stage1.ld"));

//     // b.default_step.dependOn(&stage1.step);

//     // const stage1_bin = stage1_elf.addObjCopy(.{
//     //     .format = .bin,
//     // });

//     // stage1_bin.step.dependOn(&stage1_elf.step);

//     // const copy_stage1 = b.addInstallBinFile(stage1_bin.getOutput(), "bios-stage1.bin");

//     // b.default_step.dependOn(&copy_stage1.step);
// }

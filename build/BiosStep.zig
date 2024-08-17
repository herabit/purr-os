step: Step,
name: []const u8,

stage1_compile: *Step.Compile,
stage1_copy: *Step.ObjCopy,

stage2_compile: *Step.Compile,
stage2_copy: *Step.ObjCopy,

output_file: Build.GeneratedFile,

// x86-16 target query.
pub const target_query = Query{
    .cpu_arch = Target.Cpu.Arch.x86,
    .os_tag = Target.Os.Tag.freestanding,
    .abi = Target.Abi.none,
    .ofmt = .elf,
    .cpu_features_add = enabled: {
        var set = Feature.Set.empty;

        set.addFeature(@intFromEnum(features.@"16bit_mode"));

        break :enabled set;
    },
};

pub const Options = struct {
    name: []const u8,
};

pub fn create(owner: *Build, options: Options) *BiosStep {
    const target = owner.resolveTargetQuery(target_query);

    const bios = owner.allocator.create(BiosStep) catch @panic("OOM");

    bios.name = options.name;
    bios.step = Step.init(.{
        .id = .custom,
        .name = options.name,
        .makeFn = make,
        .owner = owner,
    });

    bios.stage1_compile = owner.addExecutable(.{
        .name = owner.fmt("{s}-stage1", .{options.name}),
        .target = target,
        .root_source_file = owner.path("boot/bios/stage1.zig"),
        .optimize = .ReleaseSmall,
        .code_model = .kernel,
        .linkage = .static,
        .link_libc = false,
        .single_threaded = true,
        .pic = false,
    });

    bios.stage2_compile = owner.addExecutable(.{
        .name = owner.fmt("{s}-stage2", .{options.name}),
        .target = target,
        .root_source_file = owner.path("boot/bios/stage2.zig"),
        .optimize = .ReleaseSmall,
        .code_model = .kernel,
        .linkage = .static,
        .link_libc = false,
        .single_threaded = true,
        .pic = false,
    });

    const color_module = owner.createModule(.{ .root_source_file = owner.path("lib/color.zig") });

    bios.stage1_compile.root_module.addImport("color", color_module);
    bios.stage2_compile.root_module.addImport("color", color_module);

    const mbr_module = owner.createModule(.{ .root_source_file = owner.path("lib/mbr.zig") });

    bios.stage1_compile.root_module.addImport("mbr", mbr_module);
    bios.stage2_compile.root_module.addImport("mbr", mbr_module);

    bios.stage1_compile.setLinkerScript(owner.path("boot/bios/stage1.ld"));
    bios.stage2_compile.setLinkerScript(owner.path("boot/bios/stage2.ld"));

    bios.stage1_copy = bios.stage1_compile.addObjCopy(.{
        .format = .bin,
        .pad_to = 512,
    });

    bios.stage2_copy = bios.stage2_compile.addObjCopy(.{
        .format = .bin,
        .pad_to = 512,
    });

    bios.stage1_copy.step.dependOn(&bios.stage1_compile.step);
    bios.stage2_copy.step.dependOn(&bios.stage2_compile.step);

    bios.step.dependOn(&bios.stage1_copy.step);
    bios.step.dependOn(&bios.stage2_copy.step);

    bios.output_file = .{ .step = &bios.step };

    return bios;
}

pub fn getOutput(self: *const BiosStep) Build.LazyPath {
    return .{ .generated = .{ .file = &self.output_file } };
}

pub fn make(step: *Step, prog_node: std.Progress.Node) anyerror!void {
    const b = step.owner;
    const self: *BiosStep = @fieldParentPtr("step", step);

    var man = b.graph.cache.obtain();
    defer man.deinit();

    // A "random" set of data that needs to be changed
    // if this implementation ever changes in a breaking way.
    man.hash.add(@as(u32, 0xdeadbeef));
    man.hash.addBytes(self.name);

    const full_stage1_path = self.stage1_copy.getOutput().getPath2(b, step);
    const full_stage2_path = self.stage2_copy.getOutput().getPath2(b, step);

    _ = try man.addFile(full_stage1_path, null);
    _ = try man.addFile(full_stage2_path, null);

    // Check if this is cached.
    if (try step.cacheHit(&man)) {
        const digest = man.final();
        // Path of the cache.
        const cache_path = "o" ++ fs.path.sep_str ++ digest;
        // Full path to the output file.
        const full_output_path = try b.cache_root.join(b.allocator, &.{ cache_path, b.fmt("{s}.bin", .{self.name}) });
        self.output_file.path = full_output_path;
        return;
    }

    const digest = man.final();

    // Path of the cache.
    const cache_path = "o" ++ fs.path.sep_str ++ digest;

    // Full path to the output file.
    const full_output_path = try b.cache_root.join(b.allocator, &.{ cache_path, b.fmt("{s}.bin", .{self.name}) });

    // Make the cache path if it does not already exist.
    b.cache_root.handle.makePath(cache_path) catch |err| {
        return step.fail("unable to make path {s}: {s}", .{ cache_path, @errorName(err) });
    };

    var builder = Builder{ .none = {} };
    defer builder.deinit();

    builder.loadStage1(b, full_stage1_path) catch |err| {
        return step.fail("unable to load stage 1 bootloader from {s}: {s}", .{ full_stage1_path, @errorName(err) });
    };

    builder.loadStage2(b, full_stage2_path) catch |err| {
        return step.fail("unable to load stage 2 bootloader from {s}: {s}", .{ full_stage2_path, @errorName(err) });
    };

    builder.build() catch |err| {
        return step.fail("failed to build bootloader: {s}", .{@errorName(err)});
    };

    builder.write(full_output_path) catch |err| {
        return step.fail("failed to write bios bootloader to {s}: {s}", .{ full_output_path, @errorName(err) });
    };

    self.output_file.path = full_output_path;

    _ = prog_node;

    try man.writeManifest();
}

const Builder = union(enum) {
    none: void,
    first: struct {
        stage1: ArrayList(u8),
    },

    second: struct {
        stage1: ArrayList(u8),
        stage2: ArrayList(u8),
        stage2_sectors: u32,
    },

    final: struct {
        output: ArrayList(u8),
    },

    const Self = @This();

    fn loadStage1(
        self: *Self,
        b: *Build,
        path: []const u8,
    ) !void {
        switch (self.*) {
            .none => {},
            else => return error.InvalidState,
        }
        const file = try fs.openFileAbsolute(path, .{ .mode = .read_only });
        defer file.close();

        var stage1 = try ArrayList(u8).initCapacity(b.allocator, 512);
        errdefer stage1.deinit();

        // Read the stage 1 bootloader.
        try file.reader().readAllArrayList(&stage1, 512);

        const m = try mbr.MasterBootRecord.fromUnaligned(stage1.items);

        if (!m.signature.is_valid()) return error.InvalidMbrSignature;

        self.* = .{ .first = .{ .stage1 = stage1 } };
    }

    fn loadStage2(self: *Self, b: *Build, path: []const u8) !void {
        const stage1: ArrayList(u8) = switch (self.*) {
            .first => |state| state.stage1,
            else => return error.InvalidState,
        };

        const file = try fs.openFileAbsolute(path, .{ .mode = .read_only });
        defer file.close();

        var stage2 = try ArrayList(u8).initCapacity(b.allocator, 4096);
        errdefer stage2.deinit();

        try file.reader().readAllArrayList(&stage2, math.maxInt(usize));

        const stage2_sectors = math.cast(u32, try math.divExact(usize, stage2.items.len, 512)) orelse return error.TooManySectors;

        self.* = .{ .second = .{ .stage1 = stage1, .stage2 = stage2, .stage2_sectors = stage2_sectors } };
    }

    fn build(self: *Self) !void {
        const state = switch (self.*) {
            .second => |state| state,
            else => return error.InvalidState,
        };

        var out = state.stage1;
        try out.appendSlice(state.stage2.items);

        const m = try mbr.MasterBootRecord.fromUnaligned(out.items);

        const stage2_partition = &m.partition_table[0];
        stage2_partition.flags.bootable = true;
        stage2_partition.relative_sector = 1;
        stage2_partition.sector_len = state.stage2_sectors;

        state.stage2.deinit();

        self.* = .{ .final = .{ .output = out } };
    }

    fn output(self: *const Self) ?[]const u8 {
        return switch (self.*) {
            .final => |state| state.output.items,
            else => null,
        };
    }

    fn write(self: *const Self, path: []const u8) !void {
        if (self.output()) |o| {
            var file = try fs.createFileAbsolute(path, .{ .truncate = true });
            defer file.close();

            try file.writeAll(o);
        } else return error.NotFinishedBuilding;
    }

    fn deinit(self: Self) void {
        switch (self) {
            .none => {},
            .first => |state| {
                state.stage1.deinit();
            },
            .second => |state| {
                state.stage1.deinit();
                state.stage2.deinit();
            },
            .final => |state| {
                state.output.deinit();
            },
        }
    }
};

const std = @import("std");
const fs = std.fs;
const math = std.math;
const ArrayList = std.ArrayList;
const Build = std.Build;
const Step = Build.Step;
const Target = std.Target;
const Query = Target.Query;
const Feature = Target.Cpu.Feature;
const features = Target.x86.Feature;

const BiosStep = @This();
const mbr = @import("../lib/mbr.zig");

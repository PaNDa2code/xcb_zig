const std = @import("std");
const Build = std.Build;

pub const Protocol = @import("lib/xcb/protocol.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    // const linkage: std.builtin.LinkMode =
    //     b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse
    //     if (target.result.isGnuLibC())
    //         .dynamic
    //     else
    //         .static;

    // const clap = b.dependency("clap", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    const libxcb_upstream = b.dependency("libxcb", .{});
    const xcbproto_upstream = b.dependency("xcbproto", .{});

    // const libxau = b.dependency("libxau", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .linkage = linkage,
    // });

    // const xorgproto_upstream = libxau.builder.dependency("xorgproto", .{});

    // const xcb_util_upstream = b.dependency("xcb-util", .{});
    // const xcb_util_image_upstream = b.dependency("xcb-util-image", .{});

    const python3_path = try b.findProgram(&.{ "python3", "python" }, &.{});

    var xproto_c_sources_base: Build.LazyPath = undefined;
    var xproto_c_sources = try std.ArrayList([]const u8).initCapacity(b.allocator, 0);

    const libxcb_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    const libxcb = b.addLibrary(.{
        .name = "xcb",
        .root_module = libxcb_mod,
    });

    libxcb.linkLibC();

    {
        const libxcb_src = libxcb_upstream.path("src");
        const libxcb_c_client = libxcb_upstream.path("src/c_client.py");

        xproto_c_sources_base = libxcb_src;

        for (xml_files) |xml_file| {
            const c_file = b.fmt("{s}.c", .{xml_file[0 .. xml_file.len - 4]});

            const cmd = b.addSystemCommand(&.{python3_path});
            cmd.addFileArg(libxcb_c_client);
            cmd.addArgs(&.{ "-c", "libxcb", "-l", "libxcb", "-s", "3", "-p" });
            cmd.addDirectoryArg(xcbproto_upstream.path(""));
            cmd.addFileArg(xcbproto_upstream.path(b.fmt("src/{s}", .{xml_file})));

            cmd.setCwd(libxcb_src);

            const xproto_c_file_path = cwdOutFile(b, cmd, c_file);

            // libxcb.step.dependOn(&cmd.step);

            libxcb.addCSourceFile(.{
                .file = xproto_c_file_path,
                .flags = &.{
                    "-DXCB_QUEUE_BUFFER_SIZE=16384",
                    "-DIOV_MAX=16",
                },
            });

            try xproto_c_sources.append(b.allocator, c_file);
        }
    }

    libxcb.addCSourceFiles(.{
        .files = xproto_c_sources.items,
        .root = xproto_c_sources_base,
        .flags = &.{
            "-DXCB_QUEUE_BUFFER_SIZE=16384",
            "-DIOV_MAX=16",
        },
    });

    libxcb.installHeadersDirectory(
        xproto_c_sources_base,
        "",
        .{},
    );

    b.installArtifact(libxcb);
}

fn cwdOutFile(b: *Build, run: *Build.Step.Run, path: []const u8) Build.LazyPath {
    const cwd = run.cwd.?;
    const abs_path = cwd.join(b.allocator, path) catch @panic("OOM");
    const gen_file = b.allocator.create( Build.GeneratedFile ) catch @panic("OOM");
    gen_file.* = .{ .step = &run.step, .path = abs_path.getPath(b) };
    return .{
        .generated = .{
            .file = gen_file,
        },
    };
}

const xml_files = [_][]const u8{
    // "xcb.xsd",
    "xproto.xml",
    "bigreq.xml",
    "composite.xml",
    "damage.xml",
    "dbe.xml",
    "dpms.xml",
    "dri2.xml",
    "dri3.xml",
    "ge.xml",
    "glx.xml",
    "present.xml",
    "randr.xml",
    "record.xml",
    "render.xml",
    "res.xml",
    "screensaver.xml",
    "shape.xml",
    "shm.xml",
    "sync.xml",
    "xc_misc.xml",
    "xevie.xml",
    "xf86dri.xml",
    "xf86vidmode.xml",
    "xfixes.xml",
    "xinerama.xml",
    "xinput.xml",
    "xkb.xml",
    "xprint.xml",
    "xselinux.xml",
    "xtest.xml",
    "xv.xml",
    "xvmc.xml",
};

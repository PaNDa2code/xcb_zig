const std = @import("std");
const Build = std.Build;

pub const Protocol = @import("lib/xcb/protocol.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;
    const linkage: std.builtin.LinkMode =
        b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse
        if (target.result.isGnuLibC())
            .dynamic
        else
            .static;

    // const clap = b.dependency("clap", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    const libxcb_upstream = b.dependency("libxcb", .{});
    const xcbproto_upstream = b.dependency("xcbproto", .{});

    const libxau = b.dependency("libxau", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });

    const xorgproto_upstream = libxau.builder.dependency("xorgproto", .{});

    const xcb_util_upstream = b.dependency("xcb-util", .{});
    const xcb_util_image_upstream = b.dependency("xcb-util-image", .{});

    const python3_path = try b.findProgram(&.{ "python3", "python" }, &.{});

    const libxcb = b.addLibrary(.{
        .name = "xcb",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = linkage,
    });

    libxcb.linkLibC();

    const headers = b.addWriteFiles();

    {
        const c_client_py = libxcb_upstream.path("src/c_client.py");

        for (xml_files) |xml_file_basename| {
            const c_file_basename = b.fmt("{s}.c", .{xml_file_basename[0 .. xml_file_basename.len - 4]});
            const h_file_basename = b.fmt("{s}.h", .{xml_file_basename[0 .. xml_file_basename.len - 4]});

            const src_xml_file = b.fmt("src/{s}", .{xml_file_basename});

            const py = b.addSystemCommand(&.{python3_path});
            py.addFileArg(c_client_py);

            py.addArgs(&.{ "-c", "libxcb", "-l", "libxcb", "-s", "3", "-p" });
            py.addDirectoryArg(xcbproto_upstream.path(""));
            py.addFileArg(xcbproto_upstream.path(src_xml_file));

            py.setCwd(libxcb_upstream.path("src"));

            // not the best but works
            const cat_c = b.addSystemCommand(&.{"cat"});
            cat_c.setCwd(py.cwd.?);
            cat_c.addArg(c_file_basename);

            cat_c.step.dependOn(&py.step);

            const c_file = cat_c.captureStdOut();
            cat_c.captured_stdout.?.basename = c_file_basename;

            const cat_h = b.addSystemCommand(&.{"cat"});
            cat_h.setCwd(py.cwd.?);
            cat_h.addArg(h_file_basename);

            const h_file = cat_h.captureStdOut();
            cat_h.captured_stdout.?.basename = h_file_basename;

            libxcb.addCSourceFile(.{
                .file = c_file,
                .flags = &.{
                    "-DXCB_QUEUE_BUFFER_SIZE=16384",
                    "-DIOV_MAX=16",
                },
            });

            _ = headers.addCopyFile(
                h_file,
                b.fmt("xcb/{s}", .{h_file_basename}),
            );
        }
    }

    _ = headers.addCopyDirectory(
        xorgproto_upstream.path("include"),
        "",
        .{ .include_extensions = &.{".h"} },
    );

    _ = headers.addCopyFile(libxcb_upstream.path("src/xcb.h"), "xcb/xcb.h");
    _ = headers.addCopyFile(xcb_util_upstream.path("src/xcb_atom.h"), "xcb/xcb_atom.h");
    _ = headers.addCopyFile(xcb_util_upstream.path("src/xcb_aux.h"), "xcb/xcb_aux.h");
    _ = headers.addCopyFile(xcb_util_upstream.path("src/xcb_event.h"), "xcb/xcb_event.h");
    _ = headers.addCopyFile(xcb_util_upstream.path("src/xcb_util.h"), "xcb/xcb_util.h");
    _ = headers.addCopyFile(xcb_util_image_upstream.path("image/xcb_bitops.h"), "xcb/xcb_bitops.h");
    _ = headers.addCopyFile(xcb_util_image_upstream.path("image/xcb_image.h"), "xcb/xcb_image.h");
    _ = headers.addCopyFile(xcb_util_image_upstream.path("image/xcb_pixel.h"), "xcb/xcb_pixel.h");

    libxcb.addCSourceFiles(.{
        .root = libxcb_upstream.path("."),
        .files = &.{
            "src/xcb_auth.c",
            "src/xcb_conn.c",
            "src/xcb_ext.c",
            "src/xcb_in.c",
            "src/xcb_list.c",
            "src/xcb_out.c",
            "src/xcb_util.c",
            "src/xcb_xid.c",
        },
        .flags = &.{
            "-DXCB_QUEUE_BUFFER_SIZE=16384",
            "-DIOV_MAX=16",
        },
    });

    libxcb.addIncludePath(libxcb_upstream.path("src"));
    libxcb.addIncludePath(libxcb_upstream.path("include"));
    libxcb.addIncludePath(xorgproto_upstream.path("include"));
    libxcb.addIncludePath(headers.getDirectory().path(b, "include"));

    libxcb.linkLibrary(libxau.artifact("Xau"));

    libxcb.installHeadersDirectory(headers.getDirectory(), "", .{});
    libxcb.addIncludePath(headers.getDirectory());

    b.installArtifact(libxcb);

    const libxcb_shm = b.addLibrary(.{
        .name = "xcb-shm",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    libxcb_shm.addIncludePath(libxcb_upstream.path("src"));
    libxcb_shm.addIncludePath(libxcb_upstream.path("include"));
    libxcb_shm.addIncludePath(xorgproto_upstream.path("include"));
    libxcb_shm.addIncludePath(headers.getDirectory());

    libxcb_shm.addCSourceFiles(.{
        .root = libxcb_upstream.path("src"),
        .files = &.{ "shm.c", "xinerama.c" },
    });

    libxcb_shm.linkLibrary(libxcb);
    b.installArtifact(libxcb_shm);

    const xcb_util = b.addLibrary(.{
        .name = "xcb-util",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    xcb_util.addIncludePath(headers.getDirectory());
    xcb_util.addCSourceFiles(.{
        .root = xcb_util_upstream.path("src"),
        .files = &.{
            "atoms.c",
            "event.c",
            "xcb_aux.c",
        },
    });

    b.installArtifact(xcb_util);

    const xcb_image = b.addLibrary(.{
        .name = "xcb-image",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = linkage,
    });

    xcb_image.addIncludePath(headers.getDirectory());
    xcb_image.addCSourceFiles(.{
        .root = xcb_util_image_upstream.path("image"),
        .files = &.{
            "xcb_image.c",
        },
    });

    xcb_image.linkLibrary(xcb_util);
    xcb_image.linkLibrary(libxcb_shm);
    b.installArtifact(xcb_image);
}

fn cwdOutFile(b: *Build, run: *Build.Step.Run, basename: []const u8) Build.LazyPath {
    const cwd = run.cwd.?;
    const abs_path = cwd.join(b.allocator, basename) catch @panic("OOM");
    const output = b.allocator.create(Build.Step.Run.Output) catch @panic("OOM");

    output.* = .{
        .prefix = "",
        .basename = basename,
        .generated_file = .{ .step = &run.step, .path = abs_path.getPath(b) },
    };

    if (run.rename_step_with_output_arg) {
        run.setName(b.fmt("{s} ({s})", .{ run.step.name, basename }));
    }

    return .{ .generated = .{ .file = &output.generated_file } };
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

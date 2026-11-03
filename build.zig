const std = @import("std");
const Target = std.Target;
const Dir = std.Io.Dir;

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    const memory = b.option(usize, "memory", "Memory to run qemu with in gigibytes") orelse 1;
    const storage = b.option(usize, "disk", "Disk storage for creating the virtual disk with in gigibytes") orelse 1;

    const targets = [_]Target.Query {
        Target.Query {
            .cpu_arch = .x86_64,
            .os_tag = .freestanding,
            .abi = .eabi,
            .ofmt = .elf,
            .cpu_features_sub = Target.x86.featureSet(&.{.avx, .avx2, .sse, .sse2, .mmx}),
        },
    };
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(
        .{
            .default_target = targets[0],
            .whitelist = &targets,
        }
    );
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "zzz",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            .code_model = .kernel,
        }),
        .linkage = .static,
        .use_llvm = true,
    });
    exe.root_module.addAssemblyFile(b.path("src/start.S"));
    exe.root_module.addIncludePath(b.path("include"));
    exe.setLinkerScript(b.path("link/linker.ld"));

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    const disk_dir = b.addWriteFiles();
    disk_dir.step.dependOn(b.getInstallStep());

    const disk = b.addSystemCommand(&.{
        "qemu-img",
        "create",
        "-f",
        "qcow2",
    });
    disk.setCwd(disk_dir.getDirectory());
    const disk_file = disk.addOutputFileArg("disk.qcow2");
    disk.addArg(b.fmt("{}G", .{storage}));

    const modprobe = b.addSystemCommand(&.{
        "sudo",
        "modprobe",
        "nbd",
        "max_part=8",
    });

    modprobe.step.dependOn(&disk.step);
    
    const nbd0 = b.graph.cwdRelativePath("/dev/nbd0");
    
    const force_umount_disk = b.addSystemCommand(&.{
        "sudo",
        "qemu-nbd",
        "-d",
    });
    force_umount_disk.addFileArg(nbd0);
    force_umount_disk.step.dependOn(&modprobe.step);
    force_umount_disk.failing_to_execute_foreign_is_an_error = false;

    const mount_disk = b.addSystemCommand(&.{
        "sudo",
        "qemu-nbd",
        "-f",
        "qcow2",
        "-c",
    });
    mount_disk.addFileArg(nbd0);
    mount_disk.addFileArg(disk_file);
    
    mount_disk.step.dependOn(&force_umount_disk.step);

    const parted = b.addSystemCommand(&.{"sudo", "parted", "-s"});
    parted.addFileArg(nbd0);
    parted.addArgs(&.{
        "--",
        "mklabel",
        "msdos",
        "mkpart",
        "primary",
        "fat32",
        "1024M",
        "100%",
    });
    parted.step.dependOn(&mount_disk.step);

    const nbd0p1 = b.graph.cwdRelativePath("/dev/nbd0p1");

    const mkfs = b.addSystemCommand(&.{
        "sudo",
        "mkfs.fat",
        "-F",
        "16",
    });
    mkfs.addFileArg(nbd0p1);
    mkfs.step.dependOn(&parted.step);
    

    const temp_dir = b.addTempFiles();
    temp_dir.step.dependOn(&mkfs.step);

    const mount_fs = b.addSystemCommand(&.{
        "sudo",
        "mount",
    });
    mount_fs.addFileArg(nbd0p1);
    mount_fs.addFileArg(temp_dir.getDirectory());
    mount_fs.step.dependOn(&temp_dir.step);
    
    const grub_install = b.addSystemCommand(&.{
        "sudo",
        "grub-install",
        "--target=i386-pc",
    });
    grub_install.addFileArg2(temp_dir.getDirectory(), .{
        .make_absolute = true,
        .prefix = "--boot-directory=",
    });
    grub_install.addFileArg(nbd0);

    grub_install.step.dependOn(&mount_fs.step);


    const cp_kernel = b.addSystemCommand(&.{
        "sudo",
        "cp",
    });

    cp_kernel.addFileArg(exe.getEmittedBin());
    cp_kernel.addFileArg(temp_dir.getDirectory().path(b, "kernel"));

    cp_kernel.step.dependOn(&grub_install.step);

    const create_grub_dir = b.addSystemCommand(&.{
        "sudo",
        "mkdir",
        "-p",
    });
    create_grub_dir.addFileArg(temp_dir.getDirectory().path(b, "grub"));
    create_grub_dir.step.dependOn(&cp_kernel.step);

    const cp_grub_config = b.addSystemCommand(&.{
        "sudo",
        "cp",
    });

    cp_grub_config.addFileArg(b.path("grub/grub.cfg"));
    cp_grub_config.addFileArg(temp_dir.getDirectory().path(b, "grub/grub.cfg"));

    cp_grub_config.step.dependOn(&create_grub_dir.step);

    const umount_fs = b.addSystemCommand(&.{
        "sudo",
        "umount",
    });
    umount_fs.addFileArg(temp_dir.getDirectory());
    umount_fs.step.dependOn(&cp_grub_config.step);
    
    const umount_disk = b.addSystemCommand(&.{
        "sudo",
        "qemu-nbd",
        "-d",
    });
    umount_disk.addFileArg(nbd0);
    umount_disk.step.dependOn(&umount_fs.step);

    const sleep = b.addSystemCommand(&.{
        "sleep",
        "1",
    });
    sleep.step.dependOn(&umount_disk.step);

    const qemu = b.addSystemCommand(&[_] []const u8 {
        "qemu-system-x86_64",
        "-m",
    });

    qemu.addArg(b.fmt("{}G", .{memory}));
    qemu.addArg( "-drive");
    qemu.addFileArg2(disk_file, .{
        .prefix = "file=",
        .suffix = ",format=qcow2"
    });
    qemu.addArgs(&.{
        "-cpu",
        "host",
        "-enable-kvm",
        "-nic",
        "user",
        "-device",
        "virtio-balloon-pci",
        "-device",
        "virtio-serial-pci",
        "-device",
        "virtio-rng-pci",
        "-display",
        "gtk"
    });
    qemu.addPassthruArgs();
    qemu.step.dependOn(&sleep.step);

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    run_step.dependOn(&qemu.step);


    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}

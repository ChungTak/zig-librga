const std = @import("std");

// 判断目标是否为Android
fn isAndroid(target: std.Target) bool {
    return target.os.tag == .linux and target.abi == .android;
}

// 获取librga库文件路径
fn getLibrgaPath(target: std.Target, root_dir: ?[]const u8) ![]const u8 {
    const base_dir = if (root_dir) |dir| dir else "librga";

    // 判断操作系统
    if (target.os.tag == .linux) {
        if (isAndroid(target)) {
            // TODO: 暂不处理Android平台
            return error.UnsupportedPlatform;
        } else {
            // 判断 Linux 的 CPU 架构
            switch (target.cpu.arch) {
                .aarch64 => {
                    return std.fmt.allocPrint(std.heap.page_allocator, "{s}/libs/Linux/gcc-aarch64", .{base_dir}) catch "librga/libs/Linux/gcc-aarch64";
                },
                .arm, .thumb => {
                    return std.fmt.allocPrint(std.heap.page_allocator, "{s}/libs/Linux/gcc-armhf", .{base_dir}) catch "librga/libs/Linux/gcc-armhf";
                },
                else => {
                    return error.UnsupportedArchitecture;
                },
            }
        }
    } else {
        return error.UnsupportedPlatform;
    }
}

// 获取头文件路径
fn getIncludePath(root_dir: ?[]const u8) []const u8 {
    const base_dir = if (root_dir) |dir| dir else "librga";
    return std.fmt.allocPrint(std.heap.page_allocator, "{s}/include", .{base_dir}) catch "librga/include";
}

// 创建librga模块
fn createLibrgaModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
) *std.Build.Module {

    // 创建root.zig模块，依赖c/bindings.zig
    const librga_module = b.addModule("zig-rk-librga", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    librga_module.addLibraryPath(lib_path);
    librga_module.addIncludePath(include_path);
    // 获取目标平台和架构信息
    const platform_str = if (isAndroid(target.result)) "Android" else "Linux";
    const arch_str = switch (target.result.cpu.arch) {
        .aarch64 => "aarch64",
        .arm, .thumb => if (isAndroid(target.result)) "armeabi-v7a" else "armhf",
        else => "unknown",
    };

    // 添加平台和架构宏
    librga_module.addCMacro("PLATFORM", platform_str);
    librga_module.addCMacro("ARCH", arch_str);
    // 添加依赖

    return librga_module;
}

// 为可执行文件设置librga依赖
fn setupLibrgaForExecutable(
    exe: *std.Build.Step.Compile,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    librga_module: *std.Build.Module,
) void {
    // 链接librga库
    exe.linkSystemLibrary("rga");
    exe.addLibraryPath(lib_path);
    exe.addIncludePath(include_path);
    // 添加模块依赖
    exe.root_module.addImport("zig-rk-librga", librga_module);
}

// 构建示例
fn buildExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib_path: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    librga_module: *std.Build.Module,
) void {
    // 批量构建示例可执行文件
    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "copy_example", .path = "src/examples/copy_example.zig" },
        .{ .name = "cvtcolor_example", .path = "src/examples/cvtcolor_example.zig" },
        .{ .name = "resize_demo", .path = "src/examples/resize_demo.zig" },
    };

    for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();

        // 设置example的librga依赖
        setupLibrgaForExecutable(exe, lib_path, include_path, librga_module);

        // 安装example
        b.installArtifact(exe);

        // 添加运行example的步骤
        const run_example = b.addRunArtifact(exe);
        run_example.step.dependOn(b.getInstallStep());

        const example_step = b.step(example.name, b.fmt("Build and run the {s} example", .{example.name}));
        example_step.dependOn(&run_example.step);
    }
}

pub fn build(b: *std.Build) void {
    // 获取标准目标选项
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .gnu,
        },
    });
    const optimize = b.standardOptimizeOption(.{});

    // 获取librga库路径选项
    const librga_lib_dir = b.option([]const u8, "RK_LIBRGA_ROOT_DIR", "Path to librga library directory");

    // 获取RK_LIBRGA_ROOT_DIR环境变量
    const rk_librga_root_dir = std.process.getEnvVarOwned(std.heap.page_allocator, "RK_LIBRGA_ROOT_DIR") catch null;

    // 确定根目录：优先使用命令行选项，其次使用环境变量
    const root_dir = if (librga_lib_dir) |dir| dir else rk_librga_root_dir;

    // 检查目标平台和架构是否支持
    const lib_path = getLibrgaPath(target.result, root_dir) catch |err| {
        std.debug.print("Error: {s}. Only Linux platforms with ARM/ARM64 architectures are supported.\n", .{@errorName(err)});
        return;
    };

    const include_path = getIncludePath(root_dir);

    // 使用获取到的路径
    const final_lib_path = lib_path;
    const final_include_path = include_path;

    // 创建库模块
    const librga_module = createLibrgaModule(b, target, optimize, b.path(final_lib_path), b.path(final_include_path));

    // 创建静态库
    const lib = b.addStaticLibrary(.{
        .name = "zig-rk-librga",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    // 添加C库链接
    lib.linkSystemLibrary("rga");
    lib.addLibraryPath(b.path(final_lib_path));
    lib.addIncludePath(b.path(final_include_path));
    lib.linkLibC();

    // 安装库
    b.installArtifact(lib);

    // 创建测试
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 设置测试的库路径和头文件路径
    main_tests.linkSystemLibrary("rga");
    main_tests.addLibraryPath(.{ .cwd_relative = final_lib_path });
    main_tests.addIncludePath(.{ .cwd_relative = final_include_path });
    main_tests.linkLibC();

    const run_main_tests = b.addRunArtifact(main_tests);

    // 添加测试步骤
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // 构建示例
    buildExamples(b, target, optimize, b.path(final_lib_path), b.path(final_include_path), librga_module);
}

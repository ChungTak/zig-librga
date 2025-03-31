const std = @import("std");
const rga = @import("librga");
const c = rga.c;

// 图像参数设置
const SRC_WIDTH = 1280;
const SRC_HEIGHT = 720;
const SRC_FORMAT = c.RK_FORMAT_RGBA_8888;
const DST_WIDTH = 1280;
const DST_HEIGHT = 720;
const DST_FORMAT = c.RK_FORMAT_RGBA_8888;

// 演示模式
const Mode = enum {
    resize,
    crop,
    rotate,
    flip,
    translate,
    blend,
    cvtcolor,
    fill,
};

// 计时功能
const Timer = struct {
    start: std.time.Instant,

    pub fn init() !Timer {
        return Timer{
            .start = try std.time.Instant.now(),
        };
    }

    pub fn elapsed(self: *Timer) !u64 {
        const now = try std.time.Instant.now();
        return now.since(self.start);
    }
};

// 创建源缓冲区（红色填充）
fn createSrcBuffer(allocator: std.mem.Allocator, width: i32, height: i32, format: i32) !struct { buffer: []u8, rga_buffer: rga.Buffer } {
    // 运行时确定每个像素的字节数
    var bytes_per_pixel: usize = 0;
    switch (format) {
        c.RK_FORMAT_RGBA_8888 => bytes_per_pixel = 4,
        c.RK_FORMAT_RGB_888 => bytes_per_pixel = 3,
        c.RK_FORMAT_RGB_565 => bytes_per_pixel = 2,
        else => return error.UnsupportedFormat,
    }

    const buffer_size = @as(usize, @intCast(width * height)) * bytes_per_pixel;
    const buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(buffer);

    // 填充红色 (RGBA: FF0000FF)
    if (format == c.RK_FORMAT_RGBA_8888) {
        var i: usize = 0;
        while (i < buffer_size) : (i += 4) {
            buffer[i] = 0xFF; // R
            buffer[i + 1] = 0x00; // G
            buffer[i + 2] = 0x00; // B
            buffer[i + 3] = 0xFF; // A
        }
    } else if (format == c.RK_FORMAT_RGB_888) {
        var i: usize = 0;
        while (i < buffer_size) : (i += 3) {
            buffer[i] = 0xFF; // R
            buffer[i + 1] = 0x00; // G
            buffer[i + 2] = 0x00; // B
        }
    }

    const rga_buffer = rga.Buffer.fromVirtAddr(buffer.ptr, width, height, format, width, height);

    return .{
        .buffer = buffer,
        .rga_buffer = rga_buffer,
    };
}

// 创建目标缓冲区（空白）
fn createDstBuffer(allocator: std.mem.Allocator, width: i32, height: i32, format: i32) !struct { buffer: []u8, rga_buffer: rga.Buffer } {
    // 运行时确定每个像素的字节数
    var bytes_per_pixel: usize = 0;
    switch (format) {
        c.RK_FORMAT_RGBA_8888 => bytes_per_pixel = 4,
        c.RK_FORMAT_RGB_888 => bytes_per_pixel = 3,
        c.RK_FORMAT_RGB_565 => bytes_per_pixel = 2,
        c.RK_FORMAT_YCbCr_420_SP => bytes_per_pixel = 2, // NV12格式
        else => return error.UnsupportedFormat,
    }

    const buffer_size = @as(usize, @intCast(width * height)) * bytes_per_pixel;
    const buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(buffer);

    // 清空缓冲区（全部设为0）
    @memset(buffer, 0);

    const rga_buffer = rga.Buffer.fromVirtAddr(buffer.ptr, width, height, format, width, height);

    return .{
        .buffer = buffer,
        .rga_buffer = rga_buffer,
    };
}

// 打印执行信息
fn printJobInfo(op_name: []const u8, elapsed_ns: u64, status: rga.Error!void) !void {
    const stdout = std.io.getStdOut().writer();

    if (status) |_| {
        try stdout.print("{s} .... 耗时 {d} us, 状态: 成功\n", .{ op_name, elapsed_ns / 1000 });
    } else |err| {
        try stdout.print("{s} .... 耗时 {d} us, 状态: {s}\n", .{ op_name, elapsed_ns / 1000, @errorName(err) });
        return err;
    }
}

// 执行缩放演示
fn demoResize(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 缩放演示 ===\n", .{});

    // 创建源缓冲区
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区（一半大小）
    const dst_width = SRC_WIDTH / 2;
    const dst_height = SRC_HEIGHT / 2;
    const dst_result = try createDstBuffer(allocator, dst_width, dst_height, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    try stdout.print("缩放操作: {d}x{d} -> {d}x{d}\n", .{ SRC_WIDTH, SRC_HEIGHT, dst_width, dst_height });

    // 检查操作是否支持
    try rga.check(src, dst, null, null, 0);

    // 执行缩放
    var timer = try Timer.init();
    const status = rga.resize(src, dst, 0.5, 0.5, c.INTER_LINEAR, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("缩放", elapsed, status);
}

// 执行裁剪演示
fn demoCrop(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 裁剪演示 ===\n", .{});

    // 创建源缓冲区
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 定义裁剪区域（从图像中间裁剪300x300区域）
    const crop_rect = rga.Rect{
        .x = 100,
        .y = 100,
        .width = 300,
        .height = 300,
    };

    try stdout.print("裁剪区域: x={d}, y={d}, 宽={d}, 高={d}\n", .{ crop_rect.x, crop_rect.y, crop_rect.width, crop_rect.height });

    // 检查操作是否支持
    try rga.check(src, dst, crop_rect, null, c.IM_CROP);

    // 执行裁剪
    var timer = try Timer.init();
    const status = rga.crop(src, dst, crop_rect, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("裁剪", elapsed, status);
}

// 执行旋转演示
fn demoRotate(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 旋转演示 ===\n", .{});

    // 创建源缓冲区
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区（旋转90/270度时宽高交换）
    const dst_result = try createDstBuffer(allocator, SRC_HEIGHT, SRC_WIDTH, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 旋转角度
    const rotation = c.IM_HAL_TRANSFORM_ROT_90;
    var rotation_text: []const u8 = "未知";
    switch (rotation) {
        c.IM_HAL_TRANSFORM_ROT_90 => rotation_text = "90度",
        c.IM_HAL_TRANSFORM_ROT_180 => rotation_text = "180度",
        c.IM_HAL_TRANSFORM_ROT_270 => rotation_text = "270度",
        else => {},
    }

    try stdout.print("旋转角度: {s}\n", .{rotation_text});

    // 检查操作是否支持
    try rga.check(src, dst, null, null, rotation);

    // 执行旋转
    var timer = try Timer.init();
    const status = rga.rotate(src, dst, rotation, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("旋转", elapsed, status);
}

// 执行翻转演示
fn demoFlip(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 翻转演示 ===\n", .{});

    // 创建源缓冲区
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 翻转类型
    const flip_mode = c.IM_HAL_TRANSFORM_FLIP_H;
    var flip_text: []const u8 = "未知";
    switch (flip_mode) {
        c.IM_HAL_TRANSFORM_FLIP_H => flip_text = "水平翻转",
        c.IM_HAL_TRANSFORM_FLIP_V => flip_text = "垂直翻转",
        else => {},
    }

    try stdout.print("翻转类型: {s}\n", .{flip_text});

    // 检查操作是否支持
    try rga.check(src, dst, null, null, 0);

    // 执行翻转
    var timer = try Timer.init();
    const status = rga.flip(src, dst, flip_mode, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("翻转", elapsed, status);
}

// 执行位移演示
fn demoTranslate(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 位移演示 ===\n", .{});

    // 创建源缓冲区
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 位移距离
    const x_offset: i32 = 100;
    const y_offset: i32 = 100;

    try stdout.print("位移距离: x={d}, y={d}\n", .{ x_offset, y_offset });

    // 检查操作是否支持
    try rga.check(src, dst, null, null, 0);

    // 执行位移
    var timer = try Timer.init();
    const status = rga.translate(src, dst, x_offset, y_offset, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("位移", elapsed, status);
}

// 执行混合演示
fn demoBlend(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 混合演示 ===\n", .{});

    // 创建源缓冲区（红色背景）
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, SRC_FORMAT);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区（绿色背景）
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 填充目标缓冲区为绿色
    const bytes_per_pixel = 4; // RGBA
    for (0..dst_buffer.len / bytes_per_pixel) |i| {
        const offset = i * bytes_per_pixel;
        dst_buffer[offset] = 0x00; // R
        dst_buffer[offset + 1] = 0xFF; // G
        dst_buffer[offset + 2] = 0x00; // B
        dst_buffer[offset + 3] = 0x80; // A (半透明)
    }

    // 混合模式
    const blend_mode = c.IM_ALPHA_BLEND_SRC_OVER;

    try stdout.print("混合模式: IM_ALPHA_BLEND_SRC_OVER\n", .{});

    // 检查操作是否支持
    try rga.check(src, dst, null, null, 0);

    // 执行混合
    var timer = try Timer.init();
    const status = rga.blend(src, dst, blend_mode, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("混合", elapsed, status);
}

// 执行颜色填充演示
fn demoFill(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 颜色填充演示 ===\n", .{});

    // 创建目标缓冲区
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, DST_FORMAT);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    // 填充区域
    const fill_rect = rga.Rect{
        .x = 100,
        .y = 100,
        .width = 300,
        .height = 300,
    };

    // 填充颜色 (RGBA: 0000FFFF - 蓝色)
    const fill_color = 0x0000FFFF;

    try stdout.print("填充区域: x={d}, y={d}, 宽={d}, 高={d}\n", .{ fill_rect.x, fill_rect.y, fill_rect.width, fill_rect.height });
    try stdout.print("填充颜色: 蓝色 (0x0000FFFF)\n", .{});

    // 检查操作是否支持
    try rga.check(dst, dst, null, fill_rect, c.IM_COLOR_FILL);

    // 执行填充
    var timer = try Timer.init();
    const status = rga.fill(dst, fill_rect, fill_color, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("填充", elapsed, status);
}

// 执行颜色空间转换演示
fn demoCvtColor(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n=== 颜色空间转换演示 ===\n", .{});

    // 创建源缓冲区 (RGBA8888)
    const src_result = try createSrcBuffer(allocator, SRC_WIDTH, SRC_HEIGHT, c.RK_FORMAT_RGBA_8888);
    const src_buffer = src_result.buffer;
    const src = src_result.rga_buffer;
    defer allocator.free(src_buffer);

    // 创建目标缓冲区 (NV12)
    const dst_result = try createDstBuffer(allocator, DST_WIDTH, DST_HEIGHT, c.RK_FORMAT_YCbCr_420_SP);
    const dst_buffer = dst_result.buffer;
    const dst = dst_result.rga_buffer;
    defer allocator.free(dst_buffer);

    try stdout.print("颜色空间转换: RGBA8888 -> NV12(YCbCr_420_SP)\n", .{});

    // 检查操作是否支持
    try rga.check(src, dst, null, null, 0);

    // 执行颜色空间转换
    var timer = try Timer.init();
    const status = rga.cvtColor(src, dst, c.RK_FORMAT_RGBA_8888, c.RK_FORMAT_YCbCr_420_SP, 0, true);
    const elapsed = try timer.elapsed();

    try printJobInfo("颜色空间转换", elapsed, status);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("RGA 功能演示\n", .{});
    try stdout.print("==============\n", .{});

    // 初始化RGA
    try rga.init();
    defer rga.deinit();

    // 获取RGA设备信息
    const info = try rga.getInfo();
    try stdout.print("\nRGA设备信息:\n", .{});
    try stdout.print("  版本: {d}\n", .{info.version});
    try stdout.print("  输入分辨率: {d}\n", .{info.input_resolution});
    try stdout.print("  输出分辨率: {d}\n", .{info.output_resolution});
    try stdout.print("  缩放限制: {d}\n", .{info.scale_limit});

    // 创建内存分配器
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 获取命令行参数
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // 默认模式
    var mode = Mode.resize;

    // 解析命令行参数
    if (args.len > 1) {
        const arg = args[1];
        if (std.mem.eql(u8, arg, "resize") or std.mem.eql(u8, arg, "缩放")) {
            mode = Mode.resize;
        } else if (std.mem.eql(u8, arg, "crop") or std.mem.eql(u8, arg, "裁剪")) {
            mode = Mode.crop;
        } else if (std.mem.eql(u8, arg, "rotate") or std.mem.eql(u8, arg, "旋转")) {
            mode = Mode.rotate;
        } else if (std.mem.eql(u8, arg, "flip") or std.mem.eql(u8, arg, "翻转")) {
            mode = Mode.flip;
        } else if (std.mem.eql(u8, arg, "translate") or std.mem.eql(u8, arg, "位移")) {
            mode = Mode.translate;
        } else if (std.mem.eql(u8, arg, "blend") or std.mem.eql(u8, arg, "混合")) {
            mode = Mode.blend;
        } else if (std.mem.eql(u8, arg, "cvtcolor") or std.mem.eql(u8, arg, "颜色转换")) {
            mode = Mode.cvtcolor;
        } else if (std.mem.eql(u8, arg, "fill") or std.mem.eql(u8, arg, "填充")) {
            mode = Mode.fill;
        } else if (std.mem.eql(u8, arg, "all") or std.mem.eql(u8, arg, "所有")) {
            // 执行所有演示
            try stdout.print("\n执行所有RGA演示功能...\n", .{});
            try demoResize(allocator);
            try demoCrop(allocator);
            try demoRotate(allocator);
            try demoFlip(allocator);
            try demoTranslate(allocator);
            try demoBlend(allocator);
            try demoCvtColor(allocator);
            try demoFill(allocator);
            try stdout.print("\n所有演示完成!\n", .{});
            return;
        } else {
            try stdout.print("\n未知的演示模式: {s}\n", .{arg});
            try stdout.print("可用的模式: resize/crop/rotate/flip/translate/blend/cvtcolor/fill/all\n", .{});
            try stdout.print("           (缩放/裁剪/旋转/翻转/位移/混合/颜色转换/填充/所有)\n", .{});
            return;
        }
    }

    // 根据选择的模式执行对应的演示
    switch (mode) {
        .resize => try demoResize(allocator),
        .crop => try demoCrop(allocator),
        .rotate => try demoRotate(allocator),
        .flip => try demoFlip(allocator),
        .translate => try demoTranslate(allocator),
        .blend => try demoBlend(allocator),
        .cvtcolor => try demoCvtColor(allocator),
        .fill => try demoFill(allocator),
    }

    try stdout.print("\n演示完成!\n", .{});
}

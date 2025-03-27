const std = @import("std");
const rga = @import("rk-librga");
const c = rga.c;

const usage_str =
    \\用法：resize_demo [选项]
    \\
    \\选项：
    \\  -h, --help                   显示帮助信息
    \\  -i, --image=IMG              源图像路径
    \\  -o, --output=FILE            输出图像路径
    \\  -f, --format=FORMAT          图像格式，默认为RGBA8888
    \\  -s, --src_size=WxH           源图像尺寸 (宽x高)
    \\  -d, --dst_size=WxH           目标图像尺寸 (宽x高)
    \\  -t, --interpolation=TYPE     插值类型 [0:NEAREST, 1:BILINEAR, 2:BICUBIC]
    \\示例：
    \\  resize_demo -i input.rgb -o output.rgb -s 1920x1080 -d 1280x720 -f RGBA8888
    \\
;

const Format = struct {
    name: []const u8,
    format: i32,
    bpp: u32,
};

const TEST_DATA_SIZE = 1024 * 1024 * 20; // 20MB 测试数据缓冲区大小

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    var arg_it = std.process.args();
    // 跳过程序名
    _ = arg_it.skip();

    // 默认参数
    var src_width: i32 = 1280;
    var src_height: i32 = 720;
    var dst_width: i32 = 640;
    var dst_height: i32 = 360;
    var pixel_format: i32 = rga.PixelFormat.RGBA_8888;
    var bpp: u32 = 4; // 默认RGBA8888每像素4字节
    var src_file: ?[]const u8 = null;
    var dst_file: ?[]const u8 = null;
    var interpolation: c_int = rga.InterpolationMode.LINEAR;

    // 支持的格式
    const formats = [_]Format{
        .{ .name = "RGBA8888", .format = rga.PixelFormat.RGBA_8888, .bpp = 4 },
        .{ .name = "RGB888", .format = rga.PixelFormat.RGB_888, .bpp = 3 },
        .{ .name = "RGB565", .format = rga.PixelFormat.RGB_565, .bpp = 2 },
        .{ .name = "BGRA8888", .format = rga.PixelFormat.BGRA_8888, .bpp = 4 },
        .{ .name = "YUV420SP", .format = rga.PixelFormat.YCbCr_420_SP, .bpp = 2 },
    };

    // 解析命令行参数
    var arg_text: ?[]const u8 = arg_it.next();
    while (arg_text) |arg| : (arg_text = arg_it.next()) {
        if (std.mem.startsWith(u8, arg, "-i=") or std.mem.startsWith(u8, arg, "--image=")) {
            src_file = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
        } else if (std.mem.startsWith(u8, arg, "-o=") or std.mem.startsWith(u8, arg, "--output=")) {
            dst_file = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
        } else if (std.mem.startsWith(u8, arg, "-s=") or std.mem.startsWith(u8, arg, "--src_size=")) {
            const size_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            if (std.mem.indexOf(u8, size_str, "x")) |x_pos| {
                src_width = try std.fmt.parseInt(i32, size_str[0..x_pos], 10);
                src_height = try std.fmt.parseInt(i32, size_str[x_pos + 1 ..], 10);
            }
        } else if (std.mem.startsWith(u8, arg, "-d=") or std.mem.startsWith(u8, arg, "--dst_size=")) {
            const size_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            if (std.mem.indexOf(u8, size_str, "x")) |x_pos| {
                dst_width = try std.fmt.parseInt(i32, size_str[0..x_pos], 10);
                dst_height = try std.fmt.parseInt(i32, size_str[x_pos + 1 ..], 10);
            }
        } else if (std.mem.startsWith(u8, arg, "-f=") or std.mem.startsWith(u8, arg, "--format=")) {
            const fmt_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            var found = false;
            for (formats) |fmt| {
                if (std.mem.eql(u8, fmt.name, fmt_str)) {
                    pixel_format = fmt.format;
                    bpp = fmt.bpp;
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("不支持的格式: {s}\n", .{fmt_str});
                return error.UnsupportedFormat;
            }
        } else if (std.mem.startsWith(u8, arg, "-t=") or std.mem.startsWith(u8, arg, "--interpolation=")) {
            const t_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            const t_val = try std.fmt.parseInt(c_int, t_str, 10);
            switch (t_val) {
                0 => interpolation = rga.InterpolationMode.NEAREST,
                1 => interpolation = rga.InterpolationMode.LINEAR,
                2 => interpolation = rga.InterpolationMode.CUBIC,
                else => {
                    std.debug.print("不支持的插值类型: {d}\n", .{t_val});
                    return error.UnsupportedInterpolation;
                },
            }
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print("{s}\n", .{usage_str});
            return;
        }
    }

    // 计算缓冲区大小
    const src_size = @as(u32, @intCast(src_width * src_height)) * bpp;
    const dst_size = @as(u32, @intCast(dst_width * dst_height)) * bpp;

    std.debug.print("RGA 缩放演示\n", .{});
    std.debug.print("源尺寸: {d}x{d}, 目标尺寸: {d}x{d}\n", .{ src_width, src_height, dst_width, dst_height });
    std.debug.print("像素格式: 0x{x:0>8}, 每像素字节: {d}\n", .{ pixel_format, bpp });

    // 分配内存
    var src_data = try gpa.alloc(u8, src_size);
    defer gpa.free(src_data);

    var dst_data = try gpa.alloc(u8, dst_size);
    defer gpa.free(dst_data);

    // 填充或读取源数据
    if (src_file) |file_path| {
        std.debug.print("从文件加载源图像: {s}\n", .{file_path});
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const bytes_read = try file.readAll(src_data);
        if (bytes_read != src_size) {
            std.debug.print("警告: 文件大小 ({d} 字节) 与预期不符 ({d} 字节)\n", .{ bytes_read, src_size });
        }
    } else {
        std.debug.print("使用测试图案填充源图像\n", .{});
        var i: usize = 0;
        while (i < src_size) : (i += bpp) {
            const pos = i / bpp;
            const x = pos % @as(u32, @intCast(src_width));
            const y = pos / @as(u32, @intCast(src_width));

            if (bpp >= 3) {
                src_data[i] = @as(u8, @truncate(x % 256)); // R
                src_data[i + 1] = @as(u8, @truncate(y % 256)); // G
                src_data[i + 2] = 128; // B
                if (bpp == 4) {
                    src_data[i + 3] = 255; // A
                }
            } else if (bpp == 2) {
                // RGB565 格式
                const r5 = @as(u8, @truncate((x % 32) << 3));
                const g6 = @as(u8, @truncate((y % 64) << 2));
                const b5 = @as(u8, @truncate(16));

                const rgb565 = (@as(u16, r5) << 11) | (@as(u16, g6) << 5) | b5;
                src_data[i] = @as(u8, @truncate(rgb565 & 0xFF));
                src_data[i + 1] = @as(u8, @truncate((rgb565 >> 8) & 0xFF));
            } else {
                src_data[i] = @as(u8, @truncate((x + y) % 256));
            }
        }
    }

    // 创建RGA缓冲区
    const src_buffer = rga.Buffer.fromVirtualAddr(@ptrCast(&src_data[0]), src_width, src_height, pixel_format);

    const dst_buffer = rga.Buffer.fromVirtualAddr(@ptrCast(&dst_data[0]), dst_width, dst_height, pixel_format);

    // 执行RGA缩放操作
    std.debug.print("执行RGA缩放操作\n", .{});
    const ts_start = std.time.milliTimestamp();

    try rga.resize(src_buffer, dst_buffer, 0.0, // 使用目标尺寸自动计算比例
        0.0, interpolation, true // 同步执行
    );

    const ts_end = std.time.milliTimestamp();
    const cost_time = ts_end - ts_start;

    std.debug.print("RGA缩放操作完成，耗时: {d}ms\n", .{cost_time});

    // 输出目标数据到文件
    if (dst_file) |file_path| {
        std.debug.print("保存输出图像到: {s}\n", .{file_path});
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(dst_data);
    } else {
        std.debug.print("未指定输出文件路径，结果未保存\n", .{});
    }

    std.debug.print("测试完成\n", .{});
}

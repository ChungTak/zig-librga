const std = @import("std");
const rga = @import("zig-rk-librga");
const c = rga.c;

// Debug block - 打印可用的格式 (构建时取消注释)
// @compileLog("Available PixelFormats:", rga.PixelFormat);

const usage_str =
    \\用法：cvtcolor_example [选项]
    \\
    \\选项：
    \\  -h, --help                   显示帮助信息
    \\  -i, --input=PATH             源图像路径
    \\  -o, --output=PATH            输出图像路径
    \\  -s, --src_format=FORMAT      源图像格式，默认为RGB888
    \\  -d, --dst_format=FORMAT      目标图像格式，默认为YUV420SP
    \\  -w, --width=WIDTH            图像宽度，默认为1280
    \\  -g, --height=HEIGHT          图像高度，默认为720
    \\  -c, --color_space=SPACE      颜色空间转换模式，默认为BT601限制范围
    \\
    \\支持的格式：
    \\  RGB888, RGBA8888, RGB565, YUV420SP(NV12)
    \\
    \\颜色空间模式：
    \\  0: 无转换
    \\  1: BT601限制范围
    \\  2: BT601全范围
    \\  3: BT709限制范围
    \\
    \\示例：
    \\  cvtcolor_example -i input.rgb -o output.yuv -s RGB888 -d YUV420SP -w 1920 -g 1080 -c 1
    \\
;

const FormatInfo = struct {
    name: []const u8,
    format: c_int,
    bpp: u32,
    div: u32,
};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    var arg_it = std.process.args();
    // 跳过程序名
    _ = arg_it.skip();

    // 默认参数
    var width: u32 = 1280;
    var height: u32 = 720;
    var src_format: c_int = rga.PixelFormat.RGB_888;
    var dst_format: c_int = rga.PixelFormat.YCbCr_420_SP;
    var color_space: c_int = rga.ColorSpaceMode.RGB_TO_YUV_BT601_LIMIT;
    var src_file: ?[]const u8 = null;
    var dst_file: ?[]const u8 = null;

    // 支持的格式 - 只保留已知支持的格式
    const formats = [_]FormatInfo{
        .{ .name = "RGB888", .format = rga.PixelFormat.RGB_888, .bpp = 3, .div = 1 },
        .{ .name = "RGBA8888", .format = rga.PixelFormat.RGBA_8888, .bpp = 4, .div = 1 },
        .{ .name = "RGB565", .format = rga.PixelFormat.RGB_565, .bpp = 2, .div = 1 },
        .{ .name = "YUV420SP", .format = rga.PixelFormat.YCbCr_420_SP, .bpp = 3, .div = 2 },
    };

    // 解析命令行参数
    var arg_text: ?[]const u8 = arg_it.next();
    while (arg_text) |arg| : (arg_text = arg_it.next()) {
        if (std.mem.startsWith(u8, arg, "-i=") or std.mem.startsWith(u8, arg, "--input=")) {
            src_file = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
        } else if (std.mem.startsWith(u8, arg, "-o=") or std.mem.startsWith(u8, arg, "--output=")) {
            dst_file = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
        } else if (std.mem.startsWith(u8, arg, "-w=") or std.mem.startsWith(u8, arg, "--width=")) {
            width = try std.fmt.parseInt(u32, arg[std.mem.indexOf(u8, arg, "=").? + 1 ..], 10);
        } else if (std.mem.startsWith(u8, arg, "-g=") or std.mem.startsWith(u8, arg, "--height=")) {
            height = try std.fmt.parseInt(u32, arg[std.mem.indexOf(u8, arg, "=").? + 1 ..], 10);
        } else if (std.mem.startsWith(u8, arg, "-s=") or std.mem.startsWith(u8, arg, "--src_format=")) {
            const fmt_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            var found = false;
            for (formats) |fmt| {
                if (std.mem.eql(u8, fmt.name, fmt_str)) {
                    src_format = fmt.format;
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("不支持的源格式: {s}\n", .{fmt_str});
                return error.UnsupportedFormat;
            }
        } else if (std.mem.startsWith(u8, arg, "-d=") or std.mem.startsWith(u8, arg, "--dst_format=")) {
            const fmt_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            var found = false;
            for (formats) |fmt| {
                if (std.mem.eql(u8, fmt.name, fmt_str)) {
                    dst_format = fmt.format;
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("不支持的目标格式: {s}\n", .{fmt_str});
                return error.UnsupportedFormat;
            }
        } else if (std.mem.startsWith(u8, arg, "-c=") or std.mem.startsWith(u8, arg, "--color_space=")) {
            const cs_str = arg[std.mem.indexOf(u8, arg, "=").? + 1 ..];
            const cs_val = try std.fmt.parseInt(c_int, cs_str, 10);
            switch (cs_val) {
                0 => color_space = 0, // 使用0代替NONE
                1 => color_space = rga.ColorSpaceMode.RGB_TO_YUV_BT601_LIMIT,
                2 => color_space = rga.ColorSpaceMode.RGB_TO_YUV_BT601_FULL,
                3 => color_space = rga.ColorSpaceMode.RGB_TO_YUV_BT709_LIMIT,
                else => {
                    std.debug.print("不支持的颜色空间: {d}\n", .{cs_val});
                    return error.UnsupportedColorSpace;
                },
            }
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print("{s}\n", .{usage_str});
            return;
        }
    }

    // 获取源格式和目标格式的BPP
    var src_bpp: u32 = 3;
    var src_div: u32 = 1;
    var dst_bpp: u32 = 3;
    var dst_div: u32 = 2;

    for (formats) |fmt| {
        if (fmt.format == src_format) {
            src_bpp = fmt.bpp;
            src_div = fmt.div;
        }
        if (fmt.format == dst_format) {
            dst_bpp = fmt.bpp;
            dst_div = fmt.div;
        }
    }

    // 计算缓冲区大小 - 使用分数表示法
    const src_size = width * height * src_bpp / src_div;
    const dst_size = width * height * dst_bpp / dst_div;

    std.debug.print("RGA 颜色格式转换演示\n", .{});
    std.debug.print("图像尺寸: {d}x{d}\n", .{ width, height });
    std.debug.print("源格式: 0x{x:0>8}, 目标格式: 0x{x:0>8}\n", .{ src_format, dst_format });
    std.debug.print("颜色空间模式: {d}\n", .{color_space});

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

        // 判断源格式是RGB还是YUV
        const is_rgb = (src_format == rga.PixelFormat.RGB_888 or
            src_format == rga.PixelFormat.RGBA_8888 or
            src_format == rga.PixelFormat.RGB_565);

        if (is_rgb) {
            // 为RGB格式生成彩色测试图案
            const bytes_per_pixel = if (src_format == rga.PixelFormat.RGB_565)
                @as(usize, 2)
            else if (src_format == rga.PixelFormat.RGB_888)
                @as(usize, 3)
            else
                @as(usize, 4);

            var i: usize = 0;
            while (i < src_size) : (i += bytes_per_pixel) {
                const pos = i / bytes_per_pixel;
                const x = pos % width;
                const y = pos / width;

                if (bytes_per_pixel >= 3) {
                    src_data[i] = @as(u8, @truncate(x % 256)); // R
                    src_data[i + 1] = @as(u8, @truncate(y % 256)); // G
                    src_data[i + 2] = 128; // B
                    if (bytes_per_pixel == 4) {
                        src_data[i + 3] = 255; // A
                    }
                } else {
                    // RGB565 格式
                    const r5 = @as(u8, @truncate((x % 32) << 3));
                    const g6 = @as(u8, @truncate((y % 64) << 2));
                    const b5 = @as(u8, @truncate(16));

                    const rgb565 = (@as(u16, r5) << 11) | (@as(u16, g6) << 5) | b5;
                    src_data[i] = @as(u8, @truncate(rgb565 & 0xFF));
                    src_data[i + 1] = @as(u8, @truncate((rgb565 >> 8) & 0xFF));
                }
            }
        } else {
            // 为YUV格式生成灰度测试图案
            const y_size = width * height;

            // 填充Y平面 (灰度渐变)
            var i: usize = 0;
            while (i < y_size) : (i += 1) {
                const x = i % width;
                const y = i / width;
                src_data[i] = @as(u8, @truncate((x + y) % 256));
            }

            // 填充UV平面 (灰色)
            i = y_size;
            while (i < src_size) : (i += 1) {
                src_data[i] = 128; // U/V都填充128 (灰色)
            }
        }
    }

    // 创建RGA缓冲区
    var src_buffer = rga.Buffer.fromVirtualAddr(@ptrCast(&src_data[0]), @as(i32, @intCast(width)), @as(i32, @intCast(height)), src_format // 现在已经是c_int类型
    );

    const dst_buffer = rga.Buffer.fromVirtualAddr(@ptrCast(&dst_data[0]), @as(i32, @intCast(width)), @as(i32, @intCast(height)), dst_format // 现在已经是c_int类型
    );

    // 设置颜色空间转换模式
    if (color_space != 0) { // 使用0代替NONE
        src_buffer.setColorSpace(color_space);
    }

    // 执行RGA颜色格式转换操作
    std.debug.print("执行RGA颜色格式转换操作\n", .{});
    const ts_start = std.time.milliTimestamp();

    try rga.cvtColor(src_buffer, dst_buffer, @as(c_int, @intCast(src_format)), // 强制转换为c_int
        @as(c_int, @intCast(dst_format)), // 强制转换为c_int
        color_space, true);

    const ts_end = std.time.milliTimestamp();
    const cost_time = ts_end - ts_start;

    std.debug.print("RGA颜色格式转换操作完成，耗时: {d}ms\n", .{cost_time});

    // 输出目标数据到文件
    if (dst_file) |file_path| {
        std.debug.print("保存输出图像到: {s}\n", .{file_path});
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        try file.writeAll(dst_data);
    } else {
        std.debug.print("未指定输出文件路径，结果未保存\n", .{});
    }

    std.debug.print("颜色格式转换测试完成\n", .{});
}

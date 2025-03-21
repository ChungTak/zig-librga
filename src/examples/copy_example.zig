const std = @import("std");
const rga = @import("zig-rk-librga");
const c = rga.c;

pub fn main() !void {
    // 初始化
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const log_tag = "rga_copy_demo";
    std.debug.print("{s} 启动\n", .{log_tag});

    // 设置源和目标参数
    const src_width: usize = 1280;
    const src_height: usize = 720;
    const src_format = rga.PixelFormat.RGBA_8888;

    const dst_width: usize = 1280;
    const dst_height: usize = 720;
    const dst_format = rga.PixelFormat.RGBA_8888;

    // 计算缓冲区大小
    const bytes_per_pixel = 4; // RGBA8888格式
    const src_buf_size = src_width * src_height * bytes_per_pixel;
    const dst_buf_size = dst_width * dst_height * bytes_per_pixel;

    // 分配内存
    const src_buf = try allocator.alloc(u8, src_buf_size);
    defer allocator.free(src_buf);

    const dst_buf = try allocator.alloc(u8, dst_buf_size);
    defer allocator.free(dst_buf);

    // 尝试从文件读取图像数据，如果失败则生成测试图像
    const local_file_path = "/data";
    if (!try readImageFromFile(allocator, src_buf.ptr, local_file_path, src_width, src_height, src_format)) {
        std.debug.print("无法从文件读取图像，生成测试图像\n", .{});
        drawRgbaPattern(src_buf, src_width, src_height);
    }

    // 初始化目标缓冲区
    @memset(dst_buf, 0x80);

    // 创建源和目标缓冲区
    const src_buffer = rga.Buffer.fromVirtualAddr(src_buf.ptr, src_width, src_height, src_format);
    const dst_buffer = rga.Buffer.fromVirtualAddr(dst_buf.ptr, dst_width, dst_height, dst_format);
    // 移除不存在的兼容性检查，改用简单的参数检查
    if (src_width != dst_width) {
        std.debug.print("警告: 源缓冲区和目标缓冲区宽度不一致\n", .{});
    }
    if (src_height != dst_height) {
        std.debug.print("警告: 源缓冲区和目标缓冲区高度不一致\n", .{});
    }
    if (src_format != dst_format) {
        std.debug.print("警告: 源缓冲区和目标缓冲区格式不一致\n", .{});
    }
    // 不直接返回错误，因为RGA可能支持不同尺寸和格式之间的复制

    // 执行复制操作
    try rga.copy(src_buffer, dst_buffer, true); // 同步执行

    // 打印结果信息
    std.debug.print("输出 [0x{x:0>2}, 0x{x:0>2}, 0x{x:0>2}, 0x{x:0>2}]\n", .{ dst_buf[0], dst_buf[1], dst_buf[2], dst_buf[3] });

    // 将结果写入文件
    try writeImageToFile(allocator, dst_buf.ptr, local_file_path, dst_width, dst_height, dst_format);

    std.debug.print("{s} 运行成功!\n", .{log_tag});
}
/// 绘制RGBA测试图案
fn drawRgbaPattern(buffer: []u8, width: usize, height: usize) void {
    _ = height; // 未使用的参数
    var i: usize = 0;
    while (i < buffer.len) : (i += 4) {
        const pos = i / 4;
        const x = pos % width;
        const y = pos / width;

        buffer[i] = @as(u8, @truncate(x % 256)); // R
        buffer[i + 1] = @as(u8, @truncate(y % 256)); // G
        buffer[i + 2] = 128; // B
        buffer[i + 3] = 255; // A
    }
}

/// 从文件读取图像数据
fn readImageFromFile(allocator: std.mem.Allocator, buffer: [*]u8, base_path: []const u8, width: usize, height: usize, format: c_int) !bool {
    _ = allocator;
    // 构建文件名，格式为 "/data/in_wxh_fmt.bin"
    var filename_buf: [256]u8 = undefined;
    const fmt_str = formatToString(format);

    const filename = try std.fmt.bufPrint(&filename_buf, "{s}/in_{d}x{d}_{s}.bin", .{ base_path, width, height, fmt_str });

    // 尝试打开文件
    const file = std.fs.openFileAbsolute(filename, .{}) catch |err| {
        std.debug.print("无法打开文件 {s}: {any}\n", .{ filename, err });
        return false;
    };
    defer file.close();

    // 读取文件内容
    const bytes_read = try file.readAll(buffer[0 .. width * height * 4]);
    if (bytes_read != width * height * 4) {
        std.debug.print("文件大小不符（读取了 {d} 字节）\n", .{bytes_read});
        return false;
    }

    return true;
}

/// 将图像数据写入文件
fn writeImageToFile(allocator: std.mem.Allocator, buffer: [*]u8, base_path: []const u8, width: usize, height: usize, format: c_int) !void {
    _ = allocator;
    // 构建文件名，格式为 "/data/out_wxh_fmt.bin"
    var filename_buf: [256]u8 = undefined;
    const fmt_str = formatToString(format);

    const filename = try std.fmt.bufPrint(&filename_buf, "{s}/out_{d}x{d}_{s}.bin", .{ base_path, width, height, fmt_str });

    // 创建输出文件
    const file = try std.fs.createFileAbsolute(filename, .{});
    defer file.close();

    // 写入数据
    try file.writeAll(buffer[0 .. width * height * 4]);
    std.debug.print("已将图像数据写入到 {s}\n", .{filename});
}

// 修改辅助函数，使用更简单的映射方式
fn formatToString(format: c_int) []const u8 {
    return switch (format) {
        0x10 => "RGBA8888", // 示例值，需要根据实际值调整
        0x11 => "BGRA8888",
        0x20 => "RGB888",
        // ... 其他格式映射
        else => "UNKNOWN",
    };
}

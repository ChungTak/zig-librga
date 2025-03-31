const std = @import("std");
const zrga = @import("zrga");
const c = zrga.c;

// 默认参数定义
const DEFAULT_WIDTH = 1280;
const DEFAULT_HEIGHT = 720;
const DEFAULT_SCALE_UP_WIDTH = 1920;
const DEFAULT_SCALE_UP_HEIGHT = 1080;
const DEFAULT_SCALE_DOWN_WIDTH = 720;
const DEFAULT_SCALE_DOWN_HEIGHT = 480;
const DEFAULT_RGBA_FORMAT = c.RK_FORMAT_RGBA_8888;
const DEFAULT_YUV_FORMAT = c.RK_FORMAT_YCbCr_420_SP;

/// RGA示例演示
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 打印RGA信息
    const info = zrga.RgaContext.queryString(c.RGA_ALL);
    if (info) |i| {
        std.debug.print("RGA信息:\n{s}\n", .{i});
    }

    // 若参数未指定，显示用法
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // 跳过程序名
    _ = args.next();

    // 检查参数
    const mode_arg = args.next() orelse {
        printUsage();
        return;
    };

    // 解析操作模式
    const mode = try parseMode(mode_arg);

    // 设置源图像参数
    const src_width: i32 = DEFAULT_WIDTH;
    const src_height: i32 = DEFAULT_HEIGHT;
    const src_format: u32 = DEFAULT_RGBA_FORMAT;

    // 设置目标图像参数（根据操作模式调整）
    var dst_width: i32 = DEFAULT_WIDTH;
    var dst_height: i32 = DEFAULT_HEIGHT;
    var dst_format: u32 = DEFAULT_RGBA_FORMAT;

    // 根据模式调整目标尺寸和格式
    switch (mode) {
        .scale_up => {
            dst_width = DEFAULT_SCALE_UP_WIDTH;
            dst_height = DEFAULT_SCALE_UP_HEIGHT;
        },
        .scale_down => {
            dst_width = DEFAULT_SCALE_DOWN_WIDTH;
            dst_height = DEFAULT_SCALE_DOWN_HEIGHT;
        },
        .cvt_color => {
            dst_format = DEFAULT_YUV_FORMAT;
        },
        else => {},
    }

    // 计算缓冲区大小
    const src_bpp = getFormatBpp(src_format);
    const dst_bpp = getFormatBpp(dst_format);
    const src_buf_size = @as(usize, @intCast(src_width * src_height)) * src_bpp;
    const dst_buf_size = @as(usize, @intCast(dst_width * dst_height)) * dst_bpp;

    // 分配源图像和目标图像的内存
    const src_buf = try allocator.alloc(u8, src_buf_size);
    defer allocator.free(src_buf);

    const dst_buf = try allocator.alloc(u8, dst_buf_size);
    defer allocator.free(dst_buf);

    // 初始化源图像：填充渐变色
    fillGradientPattern(src_buf, src_width, src_height, src_bpp);

    // 清空目标缓冲区
    @memset(dst_buf, 0);

    // 创建RGA缓冲区
    var src_rga = try zrga.RgaBuffer.fromVirtual(src_buf.ptr, @intCast(src_width), @intCast(src_height), @intCast(src_format), null);
    defer src_rga.deinit();

    var dst_rga = try zrga.RgaBuffer.fromVirtual(dst_buf.ptr, @intCast(dst_width), @intCast(dst_height), @intCast(dst_format), null);
    defer dst_rga.deinit();

    // 执行图像操作
    try executeOperation(mode, &src_rga, &dst_rga);

    std.debug.print("RGA操作完成\n", .{});
}

// 操作模式枚举
const OperationMode = enum {
    copy,
    scale_up,
    scale_down,
    crop,
    rotate_90,
    rotate_180,
    rotate_270,
    flip_h,
    flip_v,
    translate,
    blend,
    cvt_color,
    fill,
};

// 解析命令行参数，获取操作模式
fn parseMode(arg: []const u8) !OperationMode {
    if (std.mem.eql(u8, arg, "--copy")) {
        return .copy;
    } else if (std.mem.eql(u8, arg, "--resize=up")) {
        return .scale_up;
    } else if (std.mem.eql(u8, arg, "--resize=down")) {
        return .scale_down;
    } else if (std.mem.eql(u8, arg, "--crop")) {
        return .crop;
    } else if (std.mem.eql(u8, arg, "--rotate=90")) {
        return .rotate_90;
    } else if (std.mem.eql(u8, arg, "--rotate=180")) {
        return .rotate_180;
    } else if (std.mem.eql(u8, arg, "--rotate=270")) {
        return .rotate_270;
    } else if (std.mem.eql(u8, arg, "--flip=H")) {
        return .flip_h;
    } else if (std.mem.eql(u8, arg, "--flip=V")) {
        return .flip_v;
    } else if (std.mem.eql(u8, arg, "--translate")) {
        return .translate;
    } else if (std.mem.eql(u8, arg, "--blend")) {
        return .blend;
    } else if (std.mem.eql(u8, arg, "--cvtcolor")) {
        return .cvt_color;
    } else if (std.mem.startsWith(u8, arg, "--fill")) {
        return .fill;
    } else {
        std.debug.print("未知操作模式: {s}\n", .{arg});
        printUsage();
        return error.UnknownMode;
    }
}

// 打印使用说明
fn printUsage() void {
    std.debug.print(
        \\使用方法: rgaIm_demo [选项]
        \\选项:
        \\  --copy                    复制图像
        \\  --resize=up               放大图像
        \\  --resize=down             缩小图像
        \\  --crop                    裁剪图像
        \\  --rotate=90/180/270       旋转图像
        \\  --flip=H/V                水平/垂直翻转
        \\  --translate               平移图像
        \\  --blend                   混合图像
        \\  --cvtcolor                颜色空间转换
        \\  --fill                    填充颜色
        \\
    , .{});
}

// 获取给定格式的每像素字节数
fn getFormatBpp(format: u32) u8 {
    return switch (format) {
        c.RK_FORMAT_RGBA_8888, c.RK_FORMAT_RGBX_8888, c.RK_FORMAT_BGRA_8888, c.RK_FORMAT_BGRX_8888 => 4,
        c.RK_FORMAT_RGB_888, c.RK_FORMAT_BGR_888 => 3,
        c.RK_FORMAT_RGB_565, c.RK_FORMAT_RGBA_5551, c.RK_FORMAT_RGBA_4444 => 2,
        c.RK_FORMAT_BPP1, c.RK_FORMAT_BPP2, c.RK_FORMAT_BPP4, c.RK_FORMAT_BPP8 => 1,
        c.RK_FORMAT_YCbCr_420_SP, c.RK_FORMAT_YCrCb_420_SP => 2, // NV12/NV21只是近似值
        else => 4, // 默认
    };
}

// 填充渐变图案
fn fillGradientPattern(buf: []u8, width: i32, height: i32, bpp: u8) void {
    const w = @as(usize, @intCast(width));
    const h = @as(usize, @intCast(height));

    if (bpp == 4) { // RGBA格式
        for (0..h) |y| {
            for (0..w) |x| {
                const offset = (y * w + x) * 4;
                buf[offset] = @truncate(x % 256); // R
                buf[offset + 1] = @truncate(y % 256); // G
                buf[offset + 2] = @truncate((x + y) % 256); // B
                buf[offset + 3] = 255; // A
            }
        }
    } else if (bpp == 3) { // RGB格式
        for (0..h) |y| {
            for (0..w) |x| {
                const offset = (y * w + x) * 3;
                buf[offset] = @truncate(x % 256); // R
                buf[offset + 1] = @truncate(y % 256); // G
                buf[offset + 2] = @truncate((x + y) % 256); // B
            }
        }
    } else { // 其他格式，简单填充
        for (0..buf.len) |i| {
            buf[i] = @truncate((i * 7) % 256);
        }
    }
}

// 执行指定的操作
fn executeOperation(mode: OperationMode, src: *zrga.RgaBuffer, dst: *zrga.RgaBuffer) !void {
    // 计时变量
    var timer = std.time.Timer.start() catch {
        std.debug.print("无法启动计时器\n", .{});
        return error.TimerError;
    };

    // 执行操作
    switch (mode) {
        .copy => {
            std.debug.print("执行复制操作...\n", .{});
            // 检查操作是否可行
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);

            // 执行操作
            try zrga.RgaContext.copy(src.*, dst.*, true);
        },
        .scale_up, .scale_down => {
            std.debug.print("执行缩放操作...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.resize(src.*, dst.*, 0.0, 0.0, c.IM_INTERP_LINEAR, true);
        },
        .crop => {
            std.debug.print("执行裁剪操作...\n", .{});
            const crop_rect = zrga.makeRect(100, 100, 300, 300);
            try zrga.RgaContext.check(src.*, dst.*, crop_rect, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.IM_CROP);
            try zrga.RgaContext.crop(src.*, dst.*, crop_rect, true);
        },
        .rotate_90 => {
            std.debug.print("执行90度旋转...\n", .{});
            // 90度旋转需要调整目标缓冲区尺寸
            var new_dst = dst.*;
            const tmp = new_dst.buffer.width;
            new_dst.buffer.width = new_dst.buffer.height;
            new_dst.buffer.height = tmp;
            new_dst.buffer.wstride = new_dst.buffer.width;
            new_dst.buffer.hstride = new_dst.buffer.height;

            try zrga.RgaContext.check(src.*, new_dst, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.IM_HAL_TRANSFORM_ROT_90);
            try zrga.RgaContext.rotate(src.*, new_dst, c.IM_HAL_TRANSFORM_ROT_90, true);
        },
        .rotate_180 => {
            std.debug.print("执行180度旋转...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.IM_HAL_TRANSFORM_ROT_180);
            try zrga.RgaContext.rotate(src.*, dst.*, c.IM_HAL_TRANSFORM_ROT_180, true);
        },
        .rotate_270 => {
            std.debug.print("执行270度旋转...\n", .{});
            // 270度旋转需要调整目标缓冲区尺寸
            var new_dst = dst.*;
            const tmp = new_dst.buffer.width;
            new_dst.buffer.width = new_dst.buffer.height;
            new_dst.buffer.height = tmp;
            new_dst.buffer.wstride = new_dst.buffer.width;
            new_dst.buffer.hstride = new_dst.buffer.height;

            try zrga.RgaContext.check(src.*, new_dst, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.IM_HAL_TRANSFORM_ROT_270);
            try zrga.RgaContext.rotate(src.*, new_dst, c.IM_HAL_TRANSFORM_ROT_270, true);
        },
        .flip_h => {
            std.debug.print("执行水平翻转...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.flip(src.*, dst.*, c.IM_HAL_TRANSFORM_FLIP_H, true);
        },
        .flip_v => {
            std.debug.print("执行垂直翻转...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.flip(src.*, dst.*, c.IM_HAL_TRANSFORM_FLIP_V, true);
        },
        .translate => {
            std.debug.print("执行平移操作...\n", .{});
            const x: i32 = 300;
            const y: i32 = 300;
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = x, .y = y, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.translate(src.*, dst.*, x, y, true);
        },
        .blend => {
            std.debug.print("执行混合操作...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.blend(src.*, dst.*, c.IM_ALPHA_BLEND_SRC_OVER | c.IM_ALPHA_BLEND_PRE_MUL, true);
        },
        .cvt_color => {
            std.debug.print("执行颜色空间转换...\n", .{});
            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, null);
            try zrga.RgaContext.cvtColor(src.*, dst.*, c.IM_COLOR_SPACE_DEFAULT, true);
        },
        .fill => {
            std.debug.print("执行颜色填充...\n", .{});
            const fill_rect = zrga.makeRect(100, 100, 300, 300);
            const color = zrga.rgbaToInt(0, 0, 255, 255); // 蓝色

            try zrga.RgaContext.check(src.*, dst.*, c.im_rect{ .x = 0, .y = 0, .width = 0, .height = 0 }, fill_rect, c.IM_COLOR_FILL);
            try zrga.RgaContext.fill(dst.*, fill_rect, color, true);
        },
    }

    // 计算并显示操作耗时
    const elapsed_ns = timer.read();
    const elapsed_us = elapsed_ns / 1000;
    std.debug.print("操作耗时: {d} 微秒\n", .{elapsed_us});
}

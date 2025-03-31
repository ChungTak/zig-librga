const std = @import("std");
const c = @import("c.zig").c;

/// 错误类型定义
pub const Error = error{
    InitFailed,
    NotSupported,
    OutOfMemory,
    InvalidParam,
    IllegalParam,
    Failed,
};

/// RGA库初始化
pub fn init() Error!void {
    // 在librga中不需要显式初始化，但为了遵循资源管理模式，提供此接口
}

/// RGA库资源释放
pub fn deinit() void {
    // 同样，在librga中不需要显式释放，但为了遵循资源管理模式，提供此接口
    // 可以调用imsync确保所有操作完成
    _ = c.imsync();
}

/// 将IM_STATUS转换为Zig错误
fn convertStatus(status: c.IM_STATUS) Error!void {
    return switch (status) {
        c.IM_STATUS_SUCCESS, c.IM_STATUS_NOERROR => {},
        c.IM_STATUS_NOT_SUPPORTED => Error.NotSupported,
        c.IM_STATUS_OUT_OF_MEMORY => Error.OutOfMemory,
        c.IM_STATUS_INVALID_PARAM => Error.InvalidParam,
        c.IM_STATUS_ILLEGAL_PARAM => Error.IllegalParam,
        else => Error.Failed,
    };
}

/// 获取RGA设备信息
pub fn getInfo() Error!c.rga_info_table_entry {
    var info_table: c.rga_info_table_entry = undefined;
    const status = c.rga_get_info(&info_table);
    try convertStatus(status);
    return info_table;
}

/// 矩形区域定义
pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    width: i32,
    height: i32,

    /// 转换为C API使用的im_rect结构体
    pub fn toImRect(self: Rect) c.im_rect {
        return c.im_rect{
            .x = self.x,
            .y = self.y,
            .width = self.width,
            .height = self.height,
        };
    }
};

/// 缓冲区定义
pub const Buffer = struct {
    // 缓冲区必须至少设置以下一种地址类型
    virt_addr: ?*anyopaque = null,
    phys_addr: ?*anyopaque = null,
    fd: i32 = -1,

    // 图像尺寸信息
    width: i32,
    height: i32,
    wstride: i32, // 可选，默认等于width
    hstride: i32, // 可选，默认等于height
    format: i32, // 像素格式

    // 可选参数
    color_space_mode: i32 = 0,
    global_alpha: i32 = 255,
    color: i32 = 0, // 用于颜色填充

    /// 转换为C API使用的rga_buffer_t结构体
    pub fn toRgaBuffer(self: Buffer) c.rga_buffer_t {
        var buffer = std.mem.zeroes(c.rga_buffer_t);

        buffer.vir_addr = self.virt_addr;
        buffer.phy_addr = self.phys_addr;
        buffer.fd = self.fd;

        buffer.width = self.width;
        buffer.height = self.height;
        buffer.wstride = if (self.wstride != 0) self.wstride else self.width;
        buffer.hstride = if (self.hstride != 0) self.hstride else self.height;
        buffer.format = self.format;

        buffer.color_space_mode = self.color_space_mode;
        buffer.global_alpha = self.global_alpha;
        buffer.color = self.color;

        return buffer;
    }

    /// 从虚拟地址创建Buffer
    pub fn fromVirtAddr(virt_addr: *anyopaque, width: i32, height: i32, format: i32, wstride: i32, hstride: i32) Buffer {
        return .{
            .virt_addr = virt_addr,
            .width = width,
            .height = height,
            .wstride = wstride,
            .hstride = hstride,
            .format = format,
        };
    }

    /// 从物理地址创建Buffer
    pub fn fromPhysAddr(phys_addr: *anyopaque, width: i32, height: i32, format: i32, wstride: i32, hstride: i32) Buffer {
        return .{
            .phys_addr = phys_addr,
            .width = width,
            .height = height,
            .wstride = wstride,
            .hstride = hstride,
            .format = format,
        };
    }

    /// 从文件描述符创建Buffer
    pub fn fromFd(fd: i32, width: i32, height: i32, format: i32, wstride: i32, hstride: i32) Buffer {
        return .{
            .fd = fd,
            .width = width,
            .height = height,
            .wstride = wstride,
            .hstride = hstride,
            .format = format,
        };
    }
};

/// 调整图像大小
pub fn resize(src: Buffer, dst: Buffer, fx: f64, fy: f64, interpolation: i32, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imresize_t(src_buffer, dst_buffer, fx, fy, interpolation, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 裁剪图像
pub fn crop(src: Buffer, dst: Buffer, rect: Rect, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();
    const im_rect = rect.toImRect();

    const status = c.imcrop_t(src_buffer, dst_buffer, im_rect, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 旋转图像
pub fn rotate(src: Buffer, dst: Buffer, rotation: i32, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imrotate_t(src_buffer, dst_buffer, rotation, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 翻转图像
pub fn flip(src: Buffer, dst: Buffer, mode: i32, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imflip_t(src_buffer, dst_buffer, mode, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 颜色填充
pub fn fill(buf: Buffer, rect: ?Rect, color: i32, do_sync: bool) Error!void {
    const buffer = buf.toRgaBuffer();
    const im_rect = if (rect) |r| r.toImRect() else c.im_rect{ .x = 0, .y = 0, .width = buf.width, .height = buf.height };

    const status = c.imfill_t(buffer, im_rect, color, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 图像混合
pub fn blend(srcA: Buffer, dst: Buffer, mode: i32, do_sync: bool) Error!void {
    const srcA_buffer = srcA.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    // 使用空的srcB
    const srcB_buffer = std.mem.zeroes(c.rga_buffer_t);

    const status = c.imblend_t(srcA_buffer, srcB_buffer, dst_buffer, mode, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 三图层混合
pub fn composite(srcA: Buffer, srcB: Buffer, dst: Buffer, mode: i32, do_sync: bool) Error!void {
    const srcA_buffer = srcA.toRgaBuffer();
    const srcB_buffer = srcB.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imblend_t(srcA_buffer, srcB_buffer, dst_buffer, mode, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 颜色空间转换
pub fn cvtColor(src: Buffer, dst: Buffer, sfmt: i32, dfmt: i32, mode: i32, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imcvtcolor_t(src_buffer, dst_buffer, sfmt, dfmt, mode, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 复制图像
pub fn copy(src: Buffer, dst: Buffer, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imcopy_t(src_buffer, dst_buffer, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 平移图像
pub fn translate(src: Buffer, dst: Buffer, x: i32, y: i32, do_sync: bool) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const status = c.imtranslate_t(src_buffer, dst_buffer, x, y, if (do_sync) 1 else 0);
    try convertStatus(status);
}

/// 等待所有RGA操作完成
pub fn sync() Error!void {
    const status = c.imsync();
    try convertStatus(status);
}

/// 检查RGA操作是否可行
pub fn check(src: Buffer, dst: Buffer, src_rect: ?Rect, dst_rect: ?Rect, usage: i32) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();
    const pat_buffer = std.mem.zeroes(c.rga_buffer_t);

    const src_im_rect = if (src_rect) |r| r.toImRect() else c.im_rect{ .x = 0, .y = 0, .width = src.width, .height = src.height };
    const dst_im_rect = if (dst_rect) |r| r.toImRect() else c.im_rect{ .x = 0, .y = 0, .width = dst.width, .height = dst.height };
    const pat_im_rect = std.mem.zeroes(c.im_rect);

    const status = c.imcheck_t(src_buffer, dst_buffer, pat_buffer, src_im_rect, dst_im_rect, pat_im_rect, usage);
    try convertStatus(status);
}

/// 获取RGA信息字符串
pub fn queryString(name: i32) []const u8 {
    return std.mem.span(c.querystring(name));
}

/// 金字塔缩放
pub fn pyramid(src: Buffer, dst: Buffer, direction: c.IM_SCALE) Error!void {
    const src_buffer = src.toRgaBuffer();
    const dst_buffer = dst.toRgaBuffer();

    const fx: f64 = if (direction == c.IM_UP_SCALE) 0.5 else 2.0;
    const fy: f64 = if (direction == c.IM_UP_SCALE) 0.5 else 2.0;

    const status = c.imresize_t(src_buffer, dst_buffer, fx, fy, c.INTER_LINEAR, 1);
    try convertStatus(status);
}

const std = @import("std");
const c = @import("c.zig").c;

/// RgaBuffer 封装了RGA的缓冲区对象，提供了简化的内存管理和操作
pub const RgaBuffer = struct {
    buffer: c.rga_buffer_t,
    handle: c.rga_buffer_handle_t,
    owned: bool, // 标记是否需要在析构时释放资源

    /// 从虚拟地址创建RGA缓冲区
    pub fn fromVirtual(
        virt_addr: [*]u8,
        width: u32,
        height: u32,
        format: c.RgaSURF_FORMAT,
        stride: ?u32,
    ) !RgaBuffer {
        const wstride = stride orelse width;

        var param = c.im_handle_param_t{
            .width = width,
            .height = height,
            .format = @intCast(format),
        };

        const handle = c.importbuffer_virtualaddr(virt_addr, &param);
        if (handle == 0) {
            return error.ImportBufferFailed;
        }

        var buffer = std.mem.zeroes(c.rga_buffer_t);
        buffer.width = @intCast(width);
        buffer.height = @intCast(height);
        buffer.wstride = @intCast(wstride);
        buffer.hstride = @intCast(height);
        buffer.format = @intCast(format);
        buffer.handle = handle;
        buffer.vir_addr = virt_addr; // 保存虚拟地址到buffer中

        return RgaBuffer{
            .buffer = buffer,
            .handle = handle,
            .owned = true,
        };
    }

    /// 从文件描述符创建RGA缓冲区
    pub fn fromFd(
        fd: i32,
        width: u32,
        height: u32,
        format: c.RgaSURF_FORMAT,
        stride: ?u32,
    ) !RgaBuffer {
        const wstride = stride orelse width;

        var param = c.im_handle_param_t{
            .width = width,
            .height = height,
            .format = @intCast(format),
        };

        const handle = c.importbuffer_fd(fd, &param);
        if (handle == 0) {
            return error.ImportBufferFailed;
        }

        var buffer = std.mem.zeroes(c.rga_buffer_t);
        buffer.width = @intCast(width);
        buffer.height = @intCast(height);
        buffer.wstride = @intCast(wstride);
        buffer.hstride = @intCast(height);
        buffer.format = @intCast(format);
        buffer.handle = handle;
        buffer.fd = fd;
        buffer.vir_addr = null; // 文件描述符方式没有直接的虚拟地址

        return RgaBuffer{
            .buffer = buffer,
            .handle = handle,
            .owned = true,
        };
    }

    /// 包装现有的RGA缓冲区handle
    pub fn fromHandle(
        handle: c.rga_buffer_handle_t,
        width: u32,
        height: u32,
        format: c.RgaSURF_FORMAT,
        stride: ?u32,
    ) !RgaBuffer {
        const wstride = stride orelse width;

        var buffer = std.mem.zeroes(c.rga_buffer_t);
        buffer.width = @intCast(width);
        buffer.height = @intCast(height);
        buffer.wstride = @intCast(wstride);
        buffer.hstride = @intCast(height);
        buffer.format = @intCast(format);
        buffer.handle = handle;
        buffer.vir_addr = null; // 从handle创建时，默认没有虚拟地址

        return RgaBuffer{
            .buffer = buffer,
            .handle = handle,
            .owned = false, // 我们不拥有此handle
        };
    }

    /// 从现有的rga_buffer_t创建RgaBuffer
    pub fn fromBuffer(buffer: c.rga_buffer_t, owned: bool) RgaBuffer {
        return RgaBuffer{
            .buffer = buffer,
            .handle = buffer.handle,
            .owned = owned,
        };
    }

    /// 释放RGA缓冲区资源
    pub fn deinit(self: *RgaBuffer) void {
        if (self.owned and self.handle != 0) {
            _ = c.releasebuffer_handle(self.handle);
            self.handle = 0;
        }
    }
};

/// RgaContext - RGA上下文对象，处理各种图像处理操作
pub const RgaContext = struct {
    /// 获取RGA信息字符串
    pub fn queryString(info_type: c_int) ?[*:0]const u8 {
        return c.querystring(info_type);
    }

    /// 复制图像
    pub fn copy(src: RgaBuffer, dst: RgaBuffer, sync: bool) !void {
        const status = c.imcopy_t(src.buffer, dst.buffer, if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 调整图像大小
    pub fn resize(src: RgaBuffer, dst: RgaBuffer, fx: f64, fy: f64, interpolation: c.IM_INTER_MODE, sync: bool) !void {
        const status = c.imresize_t(src.buffer, dst.buffer, fx, fy, @intCast(interpolation), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 裁剪图像
    pub fn crop(src: RgaBuffer, dst: RgaBuffer, rect: c.im_rect, sync: bool) !void {
        const status = c.imcrop_t(src.buffer, dst.buffer, rect, if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 旋转图像
    pub fn rotate(src: RgaBuffer, dst: RgaBuffer, rotation: c.IM_USAGE, sync: bool) !void {
        const status = c.imrotate_t(src.buffer, dst.buffer, @intCast(rotation), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 翻转图像
    pub fn flip(src: RgaBuffer, dst: RgaBuffer, mode: c.IM_USAGE, sync: bool) !void {
        const status = c.imflip_t(src.buffer, dst.buffer, @intCast(mode), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 平移图像
    pub fn translate(src: RgaBuffer, dst: RgaBuffer, x: i32, y: i32, sync: bool) !void {
        const status = c.imtranslate_t(src.buffer, dst.buffer, x, y, if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 图像格式转换
    pub fn cvtColor(src: RgaBuffer, dst: RgaBuffer, mode: c.IM_COLOR_SPACE_MODE, sync: bool) !void {
        const status = c.imcvtcolor_t(src.buffer, dst.buffer, src.buffer.format, dst.buffer.format, @intCast(mode), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 图像混合
    /// 注意：blend操作（源图像+目标图像→目标图像）在底层使用imblend_t函数
    /// imblend_t函数需要三个参数：srcA, srcB, dst，在blend模式下，srcB为空
    pub fn blend(src: RgaBuffer, dst: RgaBuffer, mode: c.IM_USAGE, sync: bool) !void {
        const empty_src = std.mem.zeroes(c.rga_buffer_t);
        const status = c.imblend_t(src.buffer, empty_src, dst.buffer, @intCast(mode), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 合成图像
    /// 注意：composite操作（源图像A+源图像B→目标图像）在底层同样使用imblend_t函数
    /// 在librga中没有提供专门的imcomposite_t函数，因此使用相同的imblend_t函数进行操作
    pub fn composite(srcA: RgaBuffer, srcB: RgaBuffer, dst: RgaBuffer, mode: c.IM_USAGE, sync: bool) !void {
        const status = c.imblend_t(srcA.buffer, srcB.buffer, dst.buffer, @intCast(mode), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 用颜色填充区域
    pub fn fill(dst: RgaBuffer, rect: c.im_rect, color: i32, sync: bool) !void {
        // const int_color: c_int = @intCast(color & 0x7FFFFFFF); // 确保值不超过int的范围
        const status = c.imfill_t(dst.buffer, rect, color, if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 应用马赛克效果
    /// 注意：librga库中对mosaic函数没有提供对应的_t版本，所以这里直接使用immosaic函数
    pub fn mosaic(image: RgaBuffer, rect: c.im_rect, mode: c.IM_MOSAIC_MODE, sync: bool) !void {
        const status = c.immosaic(image.buffer, rect, @intCast(mode), if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 应用高斯模糊
    pub fn gaussianBlur(src: RgaBuffer, dst: RgaBuffer, width: i32, height: i32, sigma_x: i32, sigma_y: i32, sync: bool) !void {
        const status = c.imgaussianBlur_t(src.buffer, dst.buffer, width, height, sigma_x, sigma_y, if (sync) 1 else 0);
        if (status != c.IM_STATUS_SUCCESS) {
            return error.RgaOperationFailed;
        }
    }

    /// 检查操作是否可行
    pub fn check(src: RgaBuffer, dst: RgaBuffer, src_rect: c.im_rect, dst_rect: c.im_rect, usage: ?c.IM_USAGE) !void {
        const status = if (usage) |u|
            c.imcheck_t(src.buffer, dst.buffer, std.mem.zeroes(c.rga_buffer_t), src_rect, dst_rect, std.mem.zeroes(c.im_rect), @intCast(u))
        else
            c.imcheck_t(src.buffer, dst.buffer, std.mem.zeroes(c.rga_buffer_t), src_rect, dst_rect, std.mem.zeroes(c.im_rect), 0);

        if (status != c.IM_STATUS_NOERROR) {
            return error.RgaCheckFailed;
        }
    }
};

/// 创建矩形区域
pub fn makeRect(x: i32, y: i32, width: i32, height: i32) c.im_rect {
    return c.im_rect{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

/// 创建颜色值
pub fn makeColor(r: u8, g: u8, b: u8, a: u8) c.im_color_t {
    return c.im_color_t{
        .red = r,
        .green = g,
        .blue = b,
        .alpha = a,
    };
}

/// 从RGBA值创建颜色整数
pub fn rgbaToInt(r: u8, g: u8, b: u8, a: u8) i32 {
    return (@as(i32, a) << 24) | (@as(i32, r) << 16) | (@as(i32, g) << 8) | @as(i32, b);
}

const std = @import("std");
const c = @import("bindings.zig").c;

// 错误类型
pub const Error = error{
    NotSupported,
    OutOfMemory,
    InvalidParam,
    IllegalParam,
    ErrorVersion,
    NoSession,
    Failed,
    Unknown,
};

// 将C的IM_STATUS转换为Zig错误
fn statusToError(status: c_int) Error!void {
    switch (status) {
        c.IM_STATUS_SUCCESS => return,
        c.IM_STATUS_NOERROR => return,
        c.IM_STATUS_NOT_SUPPORTED => return Error.NotSupported,
        c.IM_STATUS_OUT_OF_MEMORY => return Error.OutOfMemory,
        c.IM_STATUS_INVALID_PARAM => return Error.InvalidParam,
        c.IM_STATUS_ILLEGAL_PARAM => return Error.IllegalParam,
        c.IM_STATUS_ERROR_VERSION => return Error.ErrorVersion,
        c.IM_STATUS_NO_SESSION => return Error.NoSession,
        c.IM_STATUS_FAILED => return Error.Failed,
        else => return Error.Unknown,
    }
}

// RGA图像缓冲区结构体
pub const Buffer = struct {
    inner: c.rga_buffer_t,

    // 从虚拟地址创建Buffer
    pub fn fromVirtualAddr(addr: *anyopaque, width: i32, height: i32, format: i32) Buffer {
        return Buffer{
            .inner = c.wrapbuffer_virtualaddr_t(addr, width, height, width, height, format),
        };
    }

    // 从虚拟地址创建Buffer（带步长）
    pub fn fromVirtualAddrWithStride(addr: *anyopaque, width: i32, height: i32, wstride: i32, hstride: i32, format: i32) Buffer {
        return Buffer{
            .inner = c.wrapbuffer_virtualaddr_t(addr, width, height, wstride, hstride, format),
        };
    }

    // 从文件描述符创建Buffer
    pub fn fromFd(fd: c_int, width: i32, height: i32, format: i32) Buffer {
        return Buffer{
            .inner = c.wrapbuffer_fd_t(fd, width, height, width, height, format),
        };
    }

    // 从物理地址创建Buffer
    pub fn fromPhysicalAddr(addr: u64, width: i32, height: i32, format: i32) Buffer {
        return Buffer{
            .inner = c.wrapbuffer_physicaladdr_t(@as(*anyopaque, @ptrFromInt(addr)), width, height, width, height, format),
        };
    }

    // 设置透明度
    pub fn setOpacity(self: *Buffer, alpha: u8) void {
        c.imsetOpacity(&self.inner, alpha);
    }

    // 设置Alpha位
    pub fn setAlphaBit(self: *Buffer, alpha0: u8, alpha1: u8) void {
        c.imsetAlphaBit(&self.inner, alpha0, alpha1);
    }

    // 设置颜色空间
    pub fn setColorSpace(self: *Buffer, mode: c_int) void {
        c.imsetColorSpace(&self.inner, @as(c_uint, @intCast(@as(u32, @bitCast(mode)))));
    }
};

// 矩形结构体
pub const Rect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    // 转换为C的im_rect
    fn toImRect(self: Rect) c.im_rect {
        return c.im_rect{
            .x = self.x,
            .y = self.y,
            .width = self.width,
            .height = self.height,
        };
    }
};

// 色键范围
pub const ColorKeyRange = struct {
    min: i32,
    max: i32,

    // 转换为C的im_colorkey_range
    fn toImColorKeyRange(self: ColorKeyRange) c.im_colorkey_range {
        return c.im_colorkey_range{
            .min = self.min,
            .max = self.max,
        };
    }
};

// 旋转常量
pub const Rotation = struct {
    pub const ROTATE_90: c_int = c.IM_HAL_TRANSFORM_ROT_90;
    pub const ROTATE_180: c_int = c.IM_HAL_TRANSFORM_ROT_180;
    pub const ROTATE_270: c_int = c.IM_HAL_TRANSFORM_ROT_270;
};

// 翻转常量
pub const Flip = struct {
    pub const HORIZONTAL: c_int = c.IM_HAL_TRANSFORM_FLIP_H;
    pub const VERTICAL: c_int = c.IM_HAL_TRANSFORM_FLIP_V;
};

// 混合模式常量
pub const BlendMode = struct {
    pub const SRC_OVER: c_int = c.IM_ALPHA_BLEND_SRC_OVER;
    pub const SRC: c_int = c.IM_ALPHA_BLEND_SRC;
    pub const DST: c_int = c.IM_ALPHA_BLEND_DST;
    pub const SRC_IN: c_int = c.IM_ALPHA_BLEND_SRC_IN;
    pub const DST_IN: c_int = c.IM_ALPHA_BLEND_DST_IN;
    pub const SRC_OUT: c_int = c.IM_ALPHA_BLEND_SRC_OUT;
    pub const DST_OUT: c_int = c.IM_ALPHA_BLEND_DST_OUT;
    pub const DST_OVER: c_int = c.IM_ALPHA_BLEND_DST_OVER;
    pub const SRC_ATOP: c_int = c.IM_ALPHA_BLEND_SRC_ATOP;
    pub const DST_ATOP: c_int = c.IM_ALPHA_BLEND_DST_ATOP;
    pub const XOR: c_int = c.IM_ALPHA_BLEND_XOR;
};

// 颜色空间转换常量
pub const ColorSpaceMode = struct {
    pub const DEFAULT: c_int = c.IM_COLOR_SPACE_DEFAULT;
    pub const YUV_TO_RGB_BT601_LIMIT: c_int = c.IM_YUV_TO_RGB_BT601_LIMIT;
    pub const YUV_TO_RGB_BT601_FULL: c_int = c.IM_YUV_TO_RGB_BT601_FULL;
    pub const YUV_TO_RGB_BT709_LIMIT: c_int = c.IM_YUV_TO_RGB_BT709_LIMIT;
    pub const RGB_TO_YUV_BT601_FULL: c_int = c.IM_RGB_TO_YUV_BT601_FULL;
    pub const RGB_TO_YUV_BT601_LIMIT: c_int = c.IM_RGB_TO_YUV_BT601_LIMIT;
    pub const RGB_TO_YUV_BT709_LIMIT: c_int = c.IM_RGB_TO_YUV_BT709_LIMIT;
};

// 插值模式常量
pub const InterpolationMode = struct {
    pub const NEAREST: c_int = c.INTER_NEAREST;
    pub const LINEAR: c_int = c.INTER_LINEAR;
    pub const CUBIC: c_int = c.INTER_CUBIC;
};

// 马赛克模式常量
pub const MosaicMode = struct {
    pub const MODE_8: c_int = c.IM_MOSAIC_8;
    pub const MODE_16: c_int = c.IM_MOSAIC_16;
    pub const MODE_32: c_int = c.IM_MOSAIC_32;
    pub const MODE_64: c_int = c.IM_MOSAIC_64;
    pub const MODE_128: c_int = c.IM_MOSAIC_128;
};

// 边框类型常量
pub const BorderType = struct {
    pub const CONSTANT: c_int = c.IM_BORDER_CONSTANT;
    pub const REFLECT: c_int = c.IM_BORDER_REFLECT;
    pub const WRAP: c_int = c.IM_BORDER_WRAP;
};

// 像素格式常量 (添加常用格式)
pub const PixelFormat = struct {
    pub const RGBA_8888: c_int = c.RK_FORMAT_RGBA_8888;
    pub const BGRA_8888: c_int = c.RK_FORMAT_BGRA_8888;
    pub const RGBX_8888: c_int = c.RK_FORMAT_RGBX_8888;
    pub const BGRX_8888: c_int = c.RK_FORMAT_BGRX_8888;
    pub const RGB_888: c_int = c.RK_FORMAT_RGB_888;
    pub const BGR_888: c_int = c.RK_FORMAT_BGR_888;
    pub const RGB_565: c_int = c.RK_FORMAT_RGB_565;
    pub const BGR_565: c_int = c.RK_FORMAT_BGR_565;
    pub const YCbCr_420_SP: c_int = c.RK_FORMAT_YCbCr_420_SP;
    pub const YCrCb_420_SP: c_int = c.RK_FORMAT_YCrCb_420_SP;
};

//=============================================================================
// 图像处理函数
//=============================================================================

// 复制
pub fn copy(src: Buffer, dst: Buffer, sync: bool) Error!void {
    const status = c.imcopy_t(src.inner, dst.inner, if (sync) 1 else 0);
    try statusToError(status);
}

// 缩放
pub fn resize(src: Buffer, dst: Buffer, fx: f64, fy: f64, interpolation: i32, sync: bool) Error!void {
    const status = c.imresize_t(src.inner, dst.inner, fx, fy, interpolation, if (sync) 1 else 0);
    try statusToError(status);
}

// 裁剪
pub fn crop(src: Buffer, dst: Buffer, rect: Rect, sync: bool) Error!void {
    const im_rect = rect.toImRect();
    const status = c.imcrop(src.inner, dst.inner, im_rect, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 平移
pub fn translate(src: Buffer, dst: Buffer, x: i32, y: i32, sync: bool) Error!void {
    const status = c.imtranslate(src.inner, dst.inner, x, y, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 颜色格式转换
pub fn cvtColor(src: Buffer, dst: Buffer, sfmt: i32, dfmt: i32, mode: i32, sync: bool) Error!void {
    const status = c.imcvtcolor_t(src.inner, dst.inner, sfmt, dfmt, mode, if (sync) 1 else 0);
    try statusToError(status);
}

// 旋转
pub fn rotate(src: Buffer, dst: Buffer, rotation: i32, sync: bool) Error!void {
    const status = c.imrotate(src.inner, dst.inner, rotation, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 翻转
pub fn flip(src: Buffer, dst: Buffer, mode: i32, sync: bool) Error!void {
    const status = c.imflip(src.inner, dst.inner, mode, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 混合
pub fn blend(src: Buffer, dst: Buffer, mode: i32, sync: bool) Error!void {
    const status = c.imblend(src.inner, dst.inner, mode, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 合成
pub fn composite(srcA: Buffer, srcB: Buffer, dst: Buffer, mode: i32, sync: bool) Error!void {
    const status = c.imcomposite(srcA.inner, srcB.inner, dst.inner, mode, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 色键
pub fn colorKey(src: Buffer, dst: Buffer, range: ColorKeyRange, mode: c_int, sync: bool) Error!void {
    const im_range = range.toImColorKeyRange();
    const status = c.imcolorkey(src.inner, dst.inner, im_range, mode, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 填充
pub fn fill(dst: Buffer, rect: Rect, color: u32, sync: bool) Error!void {
    const im_rect = rect.toImRect();
    const status = c.imfill(dst.inner, im_rect, @as(c_int, @intCast(color)), if (sync) 1 else 0, null);
    try statusToError(status);
}

// 马赛克
pub fn mosaic(img: Buffer, rect: Rect, mosaic_mode: c_int, sync: bool) Error!void {
    const im_rect = rect.toImRect();
    const status = c.immosaic(img.inner, im_rect, mosaic_mode, if (sync) 1 else 0, null);
    try statusToError(status);
}

// 高斯模糊
pub fn gaussianBlur(src: Buffer, dst: Buffer, gauss_width: i32, gauss_height: i32, sigma_x: i32, sigma_y: i32, sync: bool) Error!void {
    const status = c.imgaussianBlur(src.inner, dst.inner, @as(c_int, @intCast(gauss_width)), @as(c_int, @intCast(gauss_height)), @as(c_int, @intCast(sigma_x)), @as(c_int, @intCast(sigma_y)), if (sync) 1 else 0, null);
    try statusToError(status);
}

// 添加边框
pub fn makeBorder(src: Buffer, dst: Buffer, top: i32, bottom: i32, left: i32, right: i32, border_type: c_int, value: i32, sync: bool) Error!void {
    const status = c.immakeBorder(src.inner, dst.inner, @as(c_int, @intCast(top)), @as(c_int, @intCast(bottom)), @as(c_int, @intCast(left)), @as(c_int, @intCast(right)), border_type, @as(c_int, @intCast(value)), if (sync) 1 else 0, null);
    try statusToError(status);
}

//=============================================================================
// 实用工具
//=============================================================================

// 导入文件描述符
pub fn importBufferFd(fd: i32, width: i32, height: i32, format: i32) Error!u32 {
    const handle = c.importbuffer_fd(fd, width, height, format);
    if (handle == 0) {
        return Error.Failed;
    }
    return @as(u32, @intCast(handle));
}

// 导入虚拟地址
pub fn importBufferVirtual(va: *anyopaque, width: i32, height: i32, format: i32) Error!u32 {
    const handle = c.importbuffer_virtualaddr(va, width, height, format);
    if (handle == 0) {
        return Error.Failed;
    }
    return @as(u32, @intCast(handle));
}

// 导入物理地址
pub fn importBufferPhysical(pa: u64, width: i32, height: i32, format: i32) Error!u32 {
    const handle = c.importbuffer_physicaladdr(pa, width, height, format);
    if (handle == 0) {
        return Error.Failed;
    }
    return @as(u32, @intCast(handle));
}

// 释放缓冲区句柄
pub fn releaseBufferHandle(handle: u32) Error!void {
    const status = c.releasebuffer_handle(@as(c.rga_buffer_handle_t, @intCast(handle)));
    try statusToError(status);
}

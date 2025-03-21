const std = @import("std");
const rga = @import("zig-rk-librga");

pub fn main() !void {
    std.debug.print("RGA 支持的像素格式：\n", .{});

    // 尝试获取并打印所有像素格式
    inline for (@typeInfo(rga.PixelFormat).Struct.fields) |field| {
        std.debug.print("  {s}: 0x{x:0>8}\n", .{ field.name, @field(rga.PixelFormat, field.name) });
    }
}

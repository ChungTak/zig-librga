const std = @import("std");
const rga = @import("zig-rk-librga");

pub fn main() !void {
    std.debug.print("RGA 支持的颜色空间模式：\n", .{});

    // 尝试获取并打印所有颜色空间模式
    inline for (@typeInfo(rga.ColorSpaceMode).Struct.fields) |field| {
        std.debug.print("  {s}: {d}\n", .{ field.name, @field(rga.ColorSpaceMode, field.name) });
    }
}

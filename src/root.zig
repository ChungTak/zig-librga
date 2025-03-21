// 导出C绑定
pub const c = @import("bindings.zig").c;

// 导出高级API
pub const rga = @import("api.zig");

// re-export 主要的类型和常量
pub usingnamespace rga;

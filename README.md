# zig-rk-librga

这是一个为 Rockchip RGA (Raster Graphic Acceleration) 库创建的 Zig 语言绑定。RGA 是 Rockchip SoC 上的 2D 硬件加速器。

## 依赖

本项目依赖于 [librga](https://github.com/airockchip/librga)，它作为 git submodule 包含在本项目中。

## 安装

### 使用 zig 包管理器

```bash
zig fetch --save git+https://github.com/ChungTak/zig-rk-librga.git
```

然后在你的 `build.zig` 中添加依赖：

```zig
const rga_dep = b.dependency("zig-rk-librga", .{});
exe.addModule("rga", rga_dep.module("rga"));
```

### 手动安装

1. 克隆此仓库：
```bash
git clone https://github.com/ChungTak/zig-rk-librga.git
```

2. 初始化并更新 submodule：
```bash
cd zig-rk-librga
git submodule update --init --recursive
```

## 编译

本项目需要编译 librga 作为依赖。构建系统会自动处理这一步骤。

```bash
zig build
```

## 使用方法

### Zig 封装绑定

目前，该项目只封装了 librga 的一小部分方法，提供了简化的 Zig API：

```zig
const std = @import("std");
const rga = @import("rga");

pub fn main() !void {
    // 初始化 RGA
    try rga.init();
    defer rga.deinit();
    
    // 使用封装的方法
    // ...
}
```

### 使用原始 C 绑定

对于未封装的功能，您可以直接使用原始 C 绑定。我们提供了完整的 librga C API 的访问：

```zig
const std = @import("std");
const rga = @import("rga");
const c = rga.c; // 访问原始 C API

pub fn main() !void {
    // 初始化 RGA
    try rga.init();
    defer rga.deinit();
    
    // 使用原始 C API
    var src_info: c.rga_info_t = undefined;
    var dst_info: c.rga_info_t = undefined;
    
    // 配置 RGA 参数
    // ...
    
    // 调用 C API 函数
    const ret = c.c_RkRgaBlit(&src_info, &dst_info, null);
    if (ret != 0) {
        return error.RGAOperationFailed;
    }
}
```

如需完整功能，请参考 [librga 官方文档](https://github.com/airockchip/librga/blob/main/docs/Rockchip_Developer_Guide_RGA_CN.md) 了解所有可用的 C API 函数及其用法。

## 示例

查看 `examples/` 目录中的示例代码，了解如何使用此绑定。

要构建并运行示例：

```bash
zig build example
```

## librga 文档

有关 RGA 功能和用法的更多信息，请参阅 [librga 官方文档](https://github.com/airockchip/librga/blob/main/docs/Rockchip_Developer_Guide_RGA_CN.md)。

## 许可证

本项目遵循 MIT 许可证。请注意，librga 有自己的许可证条款。
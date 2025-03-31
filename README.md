# zig-librga

这是一个为 Rockchip RGA (Raster Graphic Acceleration) 库创建的 Zig 语言绑定。RGA 是 Rockchip SoC 上的 2D 硬件加速器。

## ⚠️ 兼容性说明
- ​**适配版本**：仅支持 `旧版本 v1.3.x`（不兼容最新版）。

## 要求

- Zig 0.14.0或更高版本
- [librga-1.3.2](https://github.com/airockchip/librga/tree/1.3.2_release)运行时库


## 预编译库

项目已包含以下主流系统的预编译库:
- aarch64-linux-gnu
- arm-linux-gnueabihf
- aarch64-linux-android
- arm-linux-android

需要更多平台的库文件，可以从官方下载：[https://github.com/airockchip/librga/tree/1.3.2_release/libs](https://github.com/airockchip/librga/tree/1.3.2_release/libs)下载。

## 编译

项目通过环境变量`LIBRGA_LIBRARIES`指定RKNPU2库路径的路径:

```bash
# 示例: 指定自定义库路径
export LIBRGA_LIBRARIES=/path/to/your/libraries 
zig build
```

如果未设置环境变量，将使用项目内置的库(根据目标平台自动选择)。



### 指定平台和架构

在构建时，可以指定目标平台和架构：

```bash
# Linux + aarch64 (默认)
zig build -Dtarget=aarch64s-linux-gnu -Doptimize=ReleaseSafe

# Linux + armhf 32bit
zig build -Dtarget=arm-linux-gnueabihf

# Android + arm64-v8a
zig build -Dtarget=aarch64-linux-android

# Android + armeabi-v7a 32bit
zig build -Dtarget=arm-linux-android
```

## 安装

### 方法一：通过Zig包管理器安装:
在您的项目中使用以下命令添加依赖：

```bash
zig fetch --save git+https://github.com/ChungTak/zig-librga/tree/1.3.2_release
```

或者在你的`build.zig.zon`中手动添加依赖:

```zig
.dependencies = .{
    .librga = .{
        .url = "git+https://github.com/ChungTak/zig-librga/tree/1.3.2_release",
        .hash = "...", // 使用zig fetch获取正确的hash
    },
},
```

然后在你的 `build.zig` 中添加依赖：

```zig
const zrga_dep = b.dependency("zrga", .{});
exe.addModule("zrga", zrga_dep.module("zrga"));
```

### 手动安装

1. 克隆仓库1.3.2_release分支到项目路径.deps目录下：
```bash
mkdir -p .deps && cd .deps
git clone -b 1.3.2_release https://github.com/ChungTak/zig-librga.git
```

2. 然后在你的 `build.zig.zon` 中添加本地路径(不能是绝对路径)：
```zig
    .dependencies = .{
        .zrga = .{
            .path = ".deps/zig-librga",
        },
    },
```

然后在你的 `build.zig` 中添加依赖：

```zig
const zrga_dep = b.dependency("zrga", .{});
exe.addModule("zrga", zrga_dep.module("zrga"));
```


## 使用方法

### Zig 封装绑定

目前，该项目只封装了 librga 的一小部分方法，提供了简化的 Zig API：

```zig
const std = @import("std");
const zrga = @import("zrga");

pub fn main() !void {
    // 初始化 RGA
    try zrga.init();
    defer zrga.deinit();
    
    // 使用封装的方法
    // ...
}
```

### 使用原始 C 绑定

对于未封装的功能，您可以直接使用原始 C 绑定。我们提供了完整的 librga C API 的访问：

```zig
const std = @import("std");
const zrga = @import("zrga");
const c = zrga.c; // 访问原始 C API

pub fn main() !void {
    // 初始化 RGA
    try zrga.init();
    defer zrga.deinit();
    
    // 使用原始 C API
    var src_info: c.rga_info_t = undefined;
    var dst_info: c.rga_info_t = undefined;
    
    // 配置 RGA 参数
    // ...
}
```

如需完整功能，请参考 [librga-1.3.2 官方文档](https://github.com/airockchip/librga/tree/1.3.2_release/docs) 了解所有可用的 C API 函数及其用法。

## 示例

查看 `examples/` 目录中的示例代码，了解如何使用此绑定。

要构建并运行示例：

```bash
# 编译示例
zig build -Dtarget=aarch64-linux-gnu

# 运行完整的RGA功能演示
# 默认执行缩放演示
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo

# 运行特定的RGA功能演示（支持中英文参数）
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo resize   # 缩放
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo crop     # 裁剪
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo rotate   # 旋转
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo flip     # 翻转
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo translate # 位移
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo blend    # 混合
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo cvtcolor # 颜色空间转换
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo fill     # 颜色填充
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rga_demo all      # 执行所有演示
```

## librga 文档

有关 RGA 功能和用法的更多信息，请参阅 [librga 1.3.2 官方文档](https://github.com/airockchip/librga/tree/1.3.2_release/docs)。

## 许可证

本项目遵循 MIT 许可证。请注意，librga 有自己的许可证条款。
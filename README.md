# zig-librga

Rockchip RGA加速器的Zig语言绑定。该库包装了librga的C语言API，提供了更友好、更符合Zig风格的接口。

## 特性

- 支持Linux(aarch64/armhf)和Android(arm64-v8a/armeabi-v7a)平台
- 提供安全的Zig API，包括错误处理、内存管理等
- 支持从系统环境变量中搜索库文件和头文件
- 完整封装librga的C API

## 要求

- Zig 0.14.0或更高版本
- LIBRGA运行时库

## 预编译库

项目已包含以下主流系统的预编译库:
- aarch64-linux-gnu
- aarch64-linux-android

需要更多平台的库文件，可以从官方下载：[https://github.com/airockchip/librga/tree/main/libs](https://github.com/airockchip/librga/tree/main/libs)下载。


## 编译

项目通过环境变量`LIBRGA_LIBRARIES`指定LIBRGA库路径的路径:

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
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseSafe

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
zig fetch --save git+https://github.com/ChungTak/zig-librga
```

或者在你的`build.zig.zon`中手动添加依赖:

```zig
.dependencies = .{
    .zrga = .{
        .url = "git+https://github.com/ChungTak/zig-librga.git",
        .hash = "...", // 使用zig fetch获取正确的hash
    },
},
```

然后在你的 `build.zig` 中添加依赖：

```zig
const zrga_dep = b.dependency("zrga", .{});
exe.addModule("zrga", zrga_dep.module("zrga"));
```

### 方法二：手动安装

1. 克隆仓库：

1. 克隆此仓库到项目路径.deps目录下：
```bash
mkdir -p .deps && cd .deps
git clone https://github.com/ChungTak/zig-librga.git
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


## 使用示例

```zig
const std = @import("std");
const zrga = @import("zrga");
const c = zrgac;

pub fn main() !void {
    // 分配内存
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // 创建源和目标缓冲区
    const width = 1280;
    const height = 720;
    const format = c.RK_FORMAT_RGBA_8888;
    
    const src_buf = try allocator.alloc(u8, width * height * 4);
    defer allocator.free(src_buf);
    
    const dst_buf = try allocator.alloc(u8, width * height * 4);
    defer allocator.free(dst_buf);
    
    // 初始化源缓冲区...
    
    // 创建RGA缓冲区
    var src_rga = try zrgaRgaBuffer.fromVirtual(src_buf.ptr, width, height, format, null);
    defer src_rga.deinit();
    
    var dst_rga = try zrgaRgaBuffer.fromVirtual(dst_buf.ptr, width, height, format, null);
    defer dst_rga.deinit();
    
    // 执行操作
    try zrgaRgaContext.copy(src_rga, dst_rga, true);
    
    // 旋转图像
    try zrgaRgaContext.rotate(src_rga, dst_rga, c.IM_HAL_TRANSFORM_ROT_90, true);
    
    // 填充区域
    const rect = zrgamakeRect(100, 100, 200, 200);
    const color = zrgargbaToInt(255, 0, 0, 255); // 红色
    try zrgaRgaContext.fill(dst_rga, rect, color, true);
}
```

## API概览

### RgaBuffer

`RgaBuffer`是一个包装librga缓冲区对象的结构体，它自动处理资源分配和释放:

```zig
// 从虚拟地址创建
var buffer = try RgaBuffer.fromVirtual(ptr, width, height, format, stride);
defer buffer.deinit();

// 从文件描述符创建
var buffer = try RgaBuffer.fromFd(fd, width, height, format, stride);
defer buffer.deinit();
```

### RgaContext

`RgaContext`提供各种图像处理操作:

```zig
// 复制
try RgaContext.copy(src, dst, true);

// 缩放
try RgaContext.resize(src, dst, 0.5, 0.5, c.IM_INTERP_LINEAR, true);

// 旋转
try RgaContext.rotate(src, dst, c.IM_HAL_TRANSFORM_ROT_90, true);

// 裁剪
const rect = makeRect(100, 100, 300, 300);
try RgaContext.crop(src, dst, rect, true);

// 格式转换
try RgaContext.cvtColor(src, dst, c.IM_YUV_TO_RGB_BT709_LIMIT, true);

// 混合
try RgaContext.blend(src, dst, c.IM_ALPHA_BLEND_SRC_OVER, true);
```

编译并运行示例:

```bash
# 编译benchmark示例
zig build -Dtarget=aarch64-linux-gnu

# 运行benchmark示例
LD_LIBRARY_PATH=runtime/librga/lib/aarch64-linux-gnu ./zig-out/bin/rgaIm_demo --fill
```

## 许可证

本项目遵循 MIT 许可证。请注意，librga 有自己的许可证条款。


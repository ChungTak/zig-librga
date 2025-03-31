// 使用@cImport导入头文件
pub const c = @cImport({
    @cInclude("im2d.h");
    @cInclude("rga.h");
});

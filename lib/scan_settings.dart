import 'package:shared_preferences/shared_preferences.dart';

/// 颜色模式：彩色 / 黑白（灰度）
enum ColorMode { color, gray }

/// 页面尺寸：贴合文档（无白边）/ A4 / A3
enum PageSizeMode { fitDocument, a4, a3 }

/// 清晰度：普通 / 中 / 高（影响分辨率与压缩质量、进而影响文件大小）
enum Clarity { normal, medium, high }

/// 扫描前可预设、并持久化保存的选项。
class ScanSettings {
  ColorMode colorMode;
  PageSizeMode pageSize;
  Clarity clarity;

  ScanSettings({
    this.colorMode = ColorMode.color,
    this.pageSize = PageSizeMode.fitDocument,
    this.clarity = Clarity.medium,
  });

  /// 图片长边最大像素（超过则等比缩小），清晰度越高越大。
  int get maxDimension => switch (clarity) {
        Clarity.high => 3000,
        Clarity.medium => 2200,
        Clarity.normal => 1600,
      };

  /// JPEG 压缩质量（0-100），清晰度越高越大。
  int get jpegQuality => switch (clarity) {
        Clarity.high => 95,
        Clarity.medium => 85,
        Clarity.normal => 72,
      };

  static const _kColor = 'set_color';
  static const _kSize = 'set_size';
  static const _kClarity = 'set_clarity';

  static Future<ScanSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return ScanSettings(
      colorMode: ColorMode.values[p.getInt(_kColor) ?? ColorMode.color.index],
      pageSize:
          PageSizeMode.values[p.getInt(_kSize) ?? PageSizeMode.fitDocument.index],
      clarity: Clarity.values[p.getInt(_kClarity) ?? Clarity.medium.index],
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kColor, colorMode.index);
    await p.setInt(_kSize, pageSize.index);
    await p.setInt(_kClarity, clarity.index);
  }

  String get colorLabel => colorMode == ColorMode.color ? '彩色' : '黑白';
  String get sizeLabel => switch (pageSize) {
        PageSizeMode.fitDocument => '贴合文档',
        PageSizeMode.a4 => 'A4',
        PageSizeMode.a3 => 'A3',
      };
  String get clarityLabel => switch (clarity) {
        Clarity.high => '高清晰',
        Clarity.medium => '中清晰',
        Clarity.normal => '普通',
      };
}

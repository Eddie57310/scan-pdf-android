import 'package:flutter/material.dart';
import 'scan_settings.dart';

/// 扫描前的预设页。每次改动即时保存（持久化），返回首页后生效。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial});
  final ScanSettings initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ScanSettings _s;

  @override
  void initState() {
    super.initState();
    _s = ScanSettings(
      colorMode: widget.initial.colorMode,
      pageSize: widget.initial.pageSize,
      clarity: widget.initial.clarity,
    );
  }

  Future<void> _persist() => _s.save();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section(
            title: '颜色',
            subtitle: '不论扫描时怎么拍，出图统一按此设置',
            child: SegmentedButton<ColorMode>(
              segments: const [
                ButtonSegment(
                  value: ColorMode.color,
                  label: Text('彩色'),
                  icon: Icon(Icons.palette_outlined),
                ),
                ButtonSegment(
                  value: ColorMode.gray,
                  label: Text('黑白'),
                  icon: Icon(Icons.filter_b_and_w),
                ),
              ],
              selected: {_s.colorMode},
              onSelectionChanged: (v) {
                setState(() => _s.colorMode = v.first);
                _persist();
              },
            ),
          ),
          _section(
            title: '页面尺寸',
            subtitle: '「贴合文档」无白边；A4 / A3 为标准打印纸张',
            child: SegmentedButton<PageSizeMode>(
              segments: const [
                ButtonSegment(
                    value: PageSizeMode.fitDocument, label: Text('贴合文档')),
                ButtonSegment(value: PageSizeMode.a4, label: Text('A4')),
                ButtonSegment(value: PageSizeMode.a3, label: Text('A3')),
              ],
              selected: {_s.pageSize},
              onSelectionChanged: (v) {
                setState(() => _s.pageSize = v.first);
                _persist();
              },
            ),
          ),
          _section(
            title: '文件清晰度',
            subtitle: '越高越清晰、文件越大',
            child: SegmentedButton<Clarity>(
              segments: const [
                ButtonSegment(value: Clarity.normal, label: Text('普通')),
                ButtonSegment(value: Clarity.medium, label: Text('中')),
                ButtonSegment(value: Clarity.high, label: Text('高')),
              ],
              selected: {_s.clarity},
              onSelectionChanged: (v) {
                setState(() => _s.clarity = v.first);
                _persist();
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '当前：${_s.colorLabel} · ${_s.sizeLabel} · ${_s.clarityLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ),
    );
  }
}

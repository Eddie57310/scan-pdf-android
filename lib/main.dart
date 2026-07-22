import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:image/image.dart' as img;
import 'scan_settings.dart';
import 'settings_page.dart';

void main() {
  runApp(const ScanApp());
}

class ScanApp extends StatelessWidget {
  const ScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2563EB);
    return MaterialApp(
      title: '文档扫描',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _moduleChannel = MethodChannel('doc_scanner/module');

  List<File> _pdfs = [];
  bool _busy = false;
  String _moduleStatus = '';
  ScanSettings _settings = ScanSettings();
  Timer? _modulePoll;

  @override
  void dispose() {
    _modulePoll?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadPdfs();
    ScanSettings.load().then((s) {
      if (mounted) setState(() => _settings = s);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureScannerModule());
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SettingsPage(initial: _settings)),
    );
    final s = await ScanSettings.load(); // 设置页已即时保存，回来重新读取生效
    if (mounted) setState(() => _settings = s);
  }

  /// 启动时主动确保 Google 扫描模块就位，并把状态显示在首页顶部便于排错。
  Future<void> _ensureScannerModule() async {
    if (!Platform.isAndroid) {
      setState(() => _moduleStatus = 'ios'); // iOS 用 VisionKit，无需该模块
      return;
    }
    setState(() => _moduleStatus = 'checking');
    try {
      final status =
          await _moduleChannel.invokeMethod<String>('ensureScannerModule');
      if (!mounted) return;
      setState(() => _moduleStatus = status ?? 'unknown');
      if (status == 'installing') _startModulePolling();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _moduleStatus = 'error:${e.code}:${e.message}');
    } catch (e) {
      if (mounted) setState(() => _moduleStatus = 'error:$e');
    }
  }

  /// 模块在下载中时，每几秒复查一次，下好后自动把横幅清掉（变为已就位）。
  void _startModulePolling() {
    _modulePoll?.cancel();
    var ticks = 0;
    _modulePoll = Timer.periodic(const Duration(seconds: 4), (t) async {
      ticks++;
      try {
        final status =
            await _moduleChannel.invokeMethod<String>('ensureScannerModule');
        if (!mounted) {
          t.cancel();
          return;
        }
        if (status == 'available') {
          setState(() => _moduleStatus = 'available');
          t.cancel();
        }
      } catch (_) {
        // 忽略单次复查失败，继续轮询
      }
      if (ticks >= 30) t.cancel(); // 最多轮询约 2 分钟
    });
  }

  Future<Directory> _docsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/scans');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _loadPdfs() async {
    final dir = await _docsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() => _pdfs = files);
  }

  /// 核心：调起系统级扫描器（iOS VisionKit / 安卓 ML Kit），
  /// 自动检测边缘、纠偏、旋转，拿到裁切好的图片后合成 PDF。
  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final imagePaths = await CunningDocumentScanner.getPictures(
        scannerSource: ScannerSource.cameraAndGallery,
      );
      if (imagePaths == null || imagePaths.isEmpty) {
        setState(() => _busy = false);
        return; // 用户取消
      }

      final pdfFile = await _buildPdf(imagePaths);
      await _loadPdfs();
      setState(() => _busy = false);

      if (!mounted) return;
      _showResultSheet(pdfFile);
    } catch (e) {
      setState(() => _busy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败：$e')),
      );
    }
  }

  Future<File> _buildPdf(List<String> imagePaths) async {
    final s = _settings;
    final pdf = pw.Document();
    for (final path in imagePaths) {
      final raw = await File(path).readAsBytes();
      final bytes = _processImage(raw, s);
      final image = pw.MemoryImage(bytes);
      final w = (image.width ?? 1000).toDouble();
      final h = (image.height ?? 1414).toDouble();

      final PdfPageFormat fmt;
      final pw.Widget content;
      switch (s.pageSize) {
        case PageSizeMode.fitDocument:
          // 页面贴合文档比例、铺满整页、无白边。
          fmt = PdfPageFormat(
              PdfPageFormat.a4.width, PdfPageFormat.a4.width * h / w);
          content = pw.Image(image, fit: pw.BoxFit.fill);
        case PageSizeMode.a4:
          fmt = PdfPageFormat.a4;
          content = pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
        case PageSizeMode.a3:
          fmt = PdfPageFormat.a3;
          content = pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
      }
      pdf.addPage(
        pw.Page(
          pageFormat: fmt,
          margin: pw.EdgeInsets.zero,
          build: (context) => content,
        ),
      );
    }
    final dir = await _docsDir();
    final name = '扫描_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// 按设置处理单张图片：按清晰度缩放 + 可选转黑白 + 重新编码 JPEG。
  Uint8List _processImage(Uint8List raw, ScanSettings s) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw; // 解码失败则原样使用
    var im = decoded;
    final longest = im.width > im.height ? im.width : im.height;
    if (longest > s.maxDimension) {
      im = im.width >= im.height
          ? img.copyResize(im, width: s.maxDimension)
          : img.copyResize(im, height: s.maxDimension);
    }
    if (s.colorMode == ColorMode.gray) {
      im = img.grayscale(im);
    }
    return img.encodeJpg(im, quality: s.jpegQuality);
  }

  void _showResultSheet(File file) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('已生成 PDF', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              file.path.split('/').last,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('打开预览'),
              onTap: () {
                Navigator.pop(ctx);
                OpenFilex.open(file.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('分享 / 保存到其他 App'),
              onTap: () {
                Navigator.pop(ctx);
                SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(File file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份扫描件？'),
        content: Text(file.path.split('/').last),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await file.delete();
      await _loadPdfs();
    }
  }

  /// 首页顶部的扫描组件状态条，方便直观看到 Google 模块是否就位。
  Widget _buildModuleBanner() {
    if (_moduleStatus.isEmpty ||
        _moduleStatus == 'ios' ||
        _moduleStatus == 'available') {
      return const SizedBox.shrink();
    }
    late final Color bg;
    late final IconData icon;
    late final String text;
    if (_moduleStatus == 'checking') {
      bg = Colors.blueGrey;
      icon = Icons.hourglass_top;
      text = '正在检测扫描组件…';
    } else if (_moduleStatus == 'installing') {
      bg = Colors.orange.shade800;
      icon = Icons.downloading;
      text = 'Google 扫描组件下载中，请保持联网，稍等片刻再扫描';
    } else {
      bg = Colors.red.shade700;
      icon = Icons.error_outline;
      final detail = _moduleStatus.startsWith('error:')
          ? _moduleStatus.substring(6)
          : _moduleStatus;
      text = '扫描组件不可用（将使用内置离线扫描器）\n$detail';
    }
    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _ensureScannerModule,
              child: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 首页顶部的当前设置摘要，点一下进设置页。
  Widget _buildSettingsSummary() {
    final s = _settings;
    return InkWell(
      onTap: _openSettings,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Icon(Icons.tune,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(s.colorLabel),
                  _chip(s.sizeLabel),
                  _chip(s.clarityLabel),
                ],
              ),
            ),
            Text('修改',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文档扫描'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '扫描设置',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModuleBanner(),
          _buildSettingsSummary(),
          Expanded(
            child: _pdfs.isEmpty
                ? _EmptyState(onScan: _scan)
                : RefreshIndicator(
              onRefresh: _loadPdfs,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: _pdfs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = _pdfs[i];
                  final stat = f.statSync();
                  final when =
                      DateFormat('yyyy-MM-dd HH:mm').format(stat.modified);
                  final kb = (stat.size / 1024).toStringAsFixed(0);
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.picture_as_pdf_outlined),
                    ),
                    title: Text(
                      f.path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('$when · ${kb}KB'),
                    onTap: () => OpenFilex.open(f.path),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'share') {
                          SharePlus.instance
                              .share(ShareParams(files: [XFile(f.path)]));
                        } else if (v == 'delete') {
                          _confirmDelete(f);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'share', child: Text('分享')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _scan,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.document_scanner_outlined),
        label: Text(_busy ? '处理中…' : '扫描新文档'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.document_scanner_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '还没有扫描件',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '点下方按钮，对准文件即可自动检测边缘、纠偏并生成 PDF',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('开始扫描'),
            ),
          ],
        ),
      ),
    );
  }
}

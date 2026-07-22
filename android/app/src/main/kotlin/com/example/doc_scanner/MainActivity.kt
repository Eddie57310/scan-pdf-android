package com.example.doc_scanner

import com.google.android.gms.common.moduleinstall.InstallStatusListener
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.android.gms.common.moduleinstall.ModuleInstallStatusUpdate
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "doc_scanner/module"
    private var installListener: InstallStatusListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureScannerModule" -> ensureScannerModule(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 主动确保 Google ML Kit 文档扫描模块就位，并把详细状态回传 Flutter 便于排错：
     * - "available"                → 已就位，可用
     * - "installing"               → 已发起紧急下载（带监听器 = 前台立即下，非延迟任务）
     * - error(code, message)       → 拿不到，message 含具体异常，Flutter 会显示出来
     */
    private fun ensureScannerModule(result: MethodChannel.Result) {
        val options = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .build()
        val scanner = GmsDocumentScanning.getClient(options)
        val moduleInstall = ModuleInstall.getClient(this)

        moduleInstall.areModulesAvailable(scanner)
            .addOnSuccessListener { response ->
                if (response.areModulesAvailable()) {
                    result.success("available")
                } else {
                    // 加监听器 → 视为紧急请求，Play 服务会立即在前台下载并给进度，
                    // 而不是排成「联网+充电+空闲时再下」的延迟任务。
                    val listener = InstallStatusListener { }.also { installListener = it }
                    val request = ModuleInstallRequest.newBuilder()
                        .addApi(scanner)
                        .setListener(listener)
                        .build()
                    moduleInstall.installModules(request)
                        .addOnSuccessListener { r ->
                            if (r.areModulesAlreadyInstalled()) {
                                result.success("available")
                            } else {
                                result.success("installing")
                            }
                        }
                        .addOnFailureListener { e ->
                            result.error(
                                "INSTALL_FAILED",
                                "${e.javaClass.simpleName}: ${e.localizedMessage}",
                                null,
                            )
                        }
                }
            }
            .addOnFailureListener { e ->
                result.error(
                    "CHECK_FAILED",
                    "${e.javaClass.simpleName}: ${e.localizedMessage}",
                    null,
                )
            }
    }
}

/** 让接口可用 lambda 构造。 */
private fun InstallStatusListener(block: (ModuleInstallStatusUpdate) -> Unit): InstallStatusListener =
    object : InstallStatusListener {
        override fun onInstallStatusUpdated(update: ModuleInstallStatusUpdate) = block(update)
    }

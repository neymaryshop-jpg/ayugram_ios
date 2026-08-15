import Foundation

public final class SGCrashHandler {
    public static let shared = SGCrashHandler()

    private static let handledSignals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]

    private let diagnosticsDirectory: URL
    private let crashLogUrl: URL
    private let launchLogUrl: URL
    private let seenMarkerUrl: URL
    private var isInstalled = false

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.diagnosticsDirectory = documents.appendingPathComponent("sg_diagnostics", isDirectory: true)
        self.crashLogUrl = self.diagnosticsDirectory.appendingPathComponent("sg_crash.log")
        self.launchLogUrl = self.diagnosticsDirectory.appendingPathComponent("sg_launch.log")
        self.seenMarkerUrl = self.diagnosticsDirectory.appendingPathComponent("sg_crash_seen.log")
    }

    public func install() {
        if self.isInstalled {
            return
        }
        self.isInstalled = true

        try? FileManager.default.createDirectory(at: self.diagnosticsDirectory, withIntermediateDirectories: true, attributes: nil)
        self.trimCrashLogIfNeeded()
        self.logLaunch("launch begin")

        NSSetUncaughtExceptionHandler { exception in
            SGCrashHandler.appendCrash("Uncaught exception \(exception.name.rawValue): \(exception.reason ?? "no reason")\n\(exception.callStackSymbols.joined(separator: "\n"))")
        }

        for sig in SGCrashHandler.handledSignals {
            signal(sig) { sig in
                SGCrashHandler.handleSignal(sig)
            }
        }
    }

    public func logLaunch(_ message: String) {
        self.appendLine(message, to: self.launchLogUrl)
    }

    public func unreadCrashReport() -> String? {
        guard let crashData = try? Data(contentsOf: self.crashLogUrl), !crashData.isEmpty else {
            return nil
        }
        let text = String(data: crashData, encoding: .utf8) ?? ""
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let seenLineCount = (try? String(contentsOf: self.seenMarkerUrl, encoding: .utf8)).flatMap(Int.init) ?? 0
        guard lines.count > seenLineCount else {
            return nil
        }
        try? "\(lines.count)".data(using: .utf8)?.write(to: self.seenMarkerUrl)
        return lines.suffix(120).joined(separator: "\n")
    }

    private func trimCrashLogIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: self.crashLogUrl.path), let size = attributes[.size] as? Int, size > 64 * 1024 else {
            return
        }
        guard let handle = try? FileHandle(forReadingFrom: self.crashLogUrl) else {
            return
        }
        defer {
            try? handle.close()
        }
        try? handle.seek(toOffset: UInt64(max(0, size - 32 * 1024)))
        if let data = try? handle.readToEnd() {
            try? data.write(to: self.crashLogUrl)
        }
        try? FileManager.default.removeItem(at: self.seenMarkerUrl)
    }

    private static func handleSignal(_ sig: Int32) {
        SGCrashHandler.appendCrash("Signal \(SGCrashHandler.signalName(sig))")
        signal(sig, SIG_DFL)
        raise(sig)
    }

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT:
            return "SIGABRT"
        case SIGBUS:
            return "SIGBUS"
        case SIGFPE:
            return "SIGFPE"
        case SIGILL:
            return "SIGILL"
        case SIGSEGV:
            return "SIGSEGV"
        case SIGTRAP:
            return "SIGTRAP"
        default:
            return "\(sig)"
        }
    }

    private static func appendCrash(_ text: String) {
        SGCrashHandler.appendLine(text, to: SGCrashHandler.shared.crashLogUrl)
    }

    private static func appendLine(_ text: String, to url: URL) {
        let line = "\(Date()): \(text)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer {
                try? handle.close()
            }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}
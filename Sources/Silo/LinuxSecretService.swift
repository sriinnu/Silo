#if os(Linux)
import Foundation

enum LinuxSecretService {
    static func lookupPassword(applications: [String]) -> String? {
        guard let tool = secretToolPath() else { return nil }
        for app in applications {
            if let value = runSecretTool(tool: tool, args: ["lookup", "application", app]) {
                return value
            }
        }
        return nil
    }

    private static func secretToolPath() -> String? {
        let candidates = [
            "/usr/bin/secret-tool",
            "/usr/local/bin/secret-tool",
            "/opt/homebrew/bin/secret-tool",
            "secret-tool",
        ]
        for path in candidates {
            if path == "secret-tool" { return path }
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    private static func runSecretTool(tool: String, args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
#endif

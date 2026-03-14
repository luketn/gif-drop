import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didHandleFiles = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if !didHandleFiles {
            showAlert(
                title: "Drop Movies on App Icon",
                message: "Drag one or more movie files onto the GifDrop app icon to convert them to GIFs."
            )
            NSApp.terminate(nil)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        didHandleFiles = true
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        convertAll(urls)
        sender.reply(toOpenOrPrint: .success)
        NSApp.terminate(nil)
    }

    private func convertAll(_ files: [URL]) {
        if files.isEmpty {
            showAlert(title: "No Files", message: "No files were provided.")
            return
        }

        var successCount = 0
        var failures: [String] = []

        for input in files {
            do {
                _ = try convert(input: input)
                successCount += 1
            } catch {
                failures.append("\(input.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if failures.isEmpty {
//             showAlert(
//                 title: "GIF Conversion Complete",
//                 message: "Converted \(successCount) file(s) successfully. GIFs were saved next to the source files."
//             )
            return
        }

        let maxLines = 8
        let head = failures.prefix(maxLines).joined(separator: "\n")
        let suffix = failures.count > maxLines ? "\n...and \(failures.count - maxLines) more" : ""
        showAlert(
            title: "Some Conversions Failed",
            message: "Converted \(successCount) file(s).\n\n\(head)\(suffix)"
        )
    }

    private func convert(input: URL) throws -> URL {
        let ffmpegPath = try resolveFFmpegPath()
        let output = input.deletingPathExtension().appendingPathExtension("gif")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-i", input.path,
            //"-vf", "fps=12,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256[p];[s1][p]paletteuse=dither=bayer",
            "-vf", "fps=15,scale=1280:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=256:stats_mode=diff[p];[s1][p]paletteuse=dither=sierra2_4a",
            output.path
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let raw = String(data: data, encoding: .utf8) ?? "Unknown ffmpeg error"
            throw NSError(domain: "GifDrop", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: shortError(raw)
            ])
        }

        return output
    }

    private func resolveFFmpegPath() throws -> String {
        let fileManager = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        throw NSError(domain: "GifDrop", code: 127, userInfo: [
            NSLocalizedDescriptionKey: "ffmpeg not found. Install it first (for example with Homebrew: brew install ffmpeg)."
        ])
    }

    private func shortError(_ text: String) -> String {
        let lines = text
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return lines.suffix(3).joined(separator: "\n")
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import Foundation
import WhatCableCore

@main
struct WhatCableCLI {
    @MainActor
    static func main() {
        // Hand-rolled flag parsing. We only have a handful of flags; pulling
        // in swift-argument-parser would be heavier than the rest of the CLI.
        let args = Array(CommandLine.arguments.dropFirst())

        if args.contains("-h") || args.contains("--help") {
            print(helpText)
            return
        }
        if args.contains("--version") {
            print(AppInfo.version)
            return
        }

        let showRaw = args.contains("--raw")
        let asJSON = args.contains("--json")
        let watch = args.contains("--watch")

        // Reject unknown flags so typos don't silently produce default output.
        let knownFlags: Set<String> = ["--raw", "--json", "--watch", "-h", "--help", "--version"]
        for arg in args where arg.hasPrefix("-") && !knownFlags.contains(arg) {
            FileHandle.standardError.write(Data("whatcable: unknown option \(arg)\n".utf8))
            FileHandle.standardError.write(Data(helpText.utf8))
            exit(2)
        }

        if watch {
            let runner = WatchRunner(asJSON: asJSON, showRaw: showRaw)
            runner.start()
            dispatchMain()
        }

        let portWatcher = USBCPortWatcher()
        let powerWatcher = PowerSourceWatcher()
        let pdWatcher = PDIdentityWatcher()

        portWatcher.refresh()
        powerWatcher.refresh()
        pdWatcher.refresh()

        if asJSON {
            do {
                let json = try JSONFormatter.render(
                    ports: portWatcher.ports,
                    sources: powerWatcher.sources,
                    identities: pdWatcher.identities,
                    showRaw: showRaw
                )
                print(json)
            } catch {
                FileHandle.standardError.write(Data("whatcable: json encoding failed: \(error)\n".utf8))
                exit(1)
            }
        } else {
            let output = TextFormatter.render(
                ports: portWatcher.ports,
                sources: powerWatcher.sources,
                identities: pdWatcher.identities,
                showRaw: showRaw
            )
            print(output, terminator: "")
        }
    }

    static let helpText = """
    whatcable \(AppInfo.version) — \(AppInfo.tagline)

    Usage: whatcable [options]

    Options:
      --watch        Continuously monitor for changes (Ctrl+C to exit)
      --json         Output as JSON instead of human-readable text
      --raw          Include raw IOKit properties for each port
      --version      Print version and exit
      -h, --help     Show this help and exit

    """
}

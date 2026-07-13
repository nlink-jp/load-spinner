import AppKit
import LoadSpinnerCore

@main
@MainActor
enum Main {
    /// Held strongly because `NSApplication.delegate` is a weak reference.
    static var delegate: AppDelegate?

    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first {
            switch command {
            case "doctor":
                exit(runDoctor())
            case "version", "--version", "-v":
                print(appVersion)
                exit(0)
            case "help", "--help", "-h":
                printUsage()
                exit(0)
            default:
                FileHandle.standardError.write(Data("load-spinner: unknown command '\(command)'\n".utf8))
                printUsage()
                exit(2)
            }
        }

        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        application.delegate = appDelegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

func printUsage() {
    print("""
    load-spinner — menu bar CPU/GPU load indicator

    Usage:
      load-spinner            Launch the menu bar app
      load-spinner doctor     Diagnose CPU/GPU metric availability
      load-spinner --version  Print the version
      load-spinner --help     Show this help
    """)
}

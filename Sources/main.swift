import AppKit
if CommandLine.arguments.contains("--self-test") {
    runWorldTests()
    runLifeTests()
    runModelTests()
    runRoamingTests()
    runHabitatTests()
    runProgressionTests()
} else {
    let app = NSApplication.shared
    let delegate = Paradise()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}

import AppKit

private func runApp() {
    let app = NSApplication.shared
    let delegate = Paradise()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}

#if GALA_APP_STORE
runApp()
#else
if CommandLine.arguments.contains("--self-test") {
    runWorldTests()
    runLifeTests()
    runModelTests()
    runRoamingTests()
    runHabitatTests()
    runProgressionTests()
} else {
    runApp()
}
#endif

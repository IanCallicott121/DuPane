import Foundation

extension Notification.Name {
    static let quickLookRequested = Notification.Name("DuPane.quickLookRequested")
    static let operationShortcutRequested = Notification.Name("DuPane.operationShortcutRequested")
    static let goToPathShortcutRequested = Notification.Name("DuPane.goToPathShortcutRequested")
    static let creationPromptEscapeRequested = Notification.Name("DuPane.creationPromptEscapeRequested")
    static let paneNavigationRequested = Notification.Name("DuPane.paneNavigationRequested")
    static let paneContentsChanged = Notification.Name("DuPane.paneContentsChanged")
}

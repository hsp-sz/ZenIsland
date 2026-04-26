import AppKit
import CoreGraphics

@MainActor
final class StatusItemCoordinator {
    struct Selectors {
        let toggleWindowVisibility: Selector
        let selectAutomaticScreenPlacement: Selector
        let selectFixedScreenPlacement: Selector
        let selectZenMuxLogo: Selector
        let selectCustomLogo: Selector
        let resyncClaudeHooks: Selector
        let checkForUpdates: Selector
        let quitFromMenu: Selector
    }

    private(set) var statusItem: NSStatusItem?
    private weak var target: AnyObject?
    private var selectors: Selectors?
    private var visibilityMenuItem: NSMenuItem?
    private var screenMenuItem: NSMenuItem?
    private var automaticScreenMenuItem: NSMenuItem?
    private var fixedScreenMenuItems: [NSMenuItem] = []
    private var zenMuxLogoMenuItem: NSMenuItem?
    private var customLogoMenuItem: NSMenuItem?
    private var resyncClaudeHooksMenuItem: NSMenuItem?
    private var checkForUpdatesMenuItem: NSMenuItem?

    func attach(statusItem: NSStatusItem) {
        self.statusItem = statusItem
    }

    func setMenu(_ menu: NSMenu) {
        statusItem?.menu = menu
    }

    func setImage(_ image: NSImage?) {
        statusItem?.button?.image = image
    }

    func setToolTip(_ toolTip: String?) {
        statusItem?.button?.toolTip = toolTip
    }

    func createStatusItem(
        menuDelegate: NSMenuDelegate,
        target: AnyObject,
        selectors: Selectors,
        image: NSImage?
    ) {
        self.target = target
        self.selectors = selectors

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = menuDelegate

        let visibilityMenuItem = menuItem(
            title: "Show/Hide Island",
            action: selectors.toggleWindowVisibility
        )
        menu.addItem(visibilityMenuItem)
        menu.addItem(.separator())

        let screenMenuItem = NSMenuItem(title: "Screen", action: nil, keyEquivalent: "")
        let screenSubmenu = NSMenu(title: "Screen")
        let automaticScreenMenuItem = menuItem(
            title: "Auto Follow Active Screen",
            action: selectors.selectAutomaticScreenPlacement
        )
        screenSubmenu.addItem(automaticScreenMenuItem)
        menu.setSubmenu(screenSubmenu, for: screenMenuItem)
        menu.addItem(screenMenuItem)
        menu.addItem(.separator())

        let logoMenuItem = NSMenuItem(title: "Left Logo", action: nil, keyEquivalent: "")
        let logoSubmenu = NSMenu(title: "Left Logo")
        let zenMuxLogoMenuItem = menuItem(title: ProgressStore.BrandLogo.zenmux.menuTitle, action: selectors.selectZenMuxLogo)
        let customLogoMenuItem = menuItem(title: ProgressStore.BrandLogo.custom.menuTitle, action: selectors.selectCustomLogo)

        [
            zenMuxLogoMenuItem,
            customLogoMenuItem
        ].forEach { logoSubmenu.addItem($0) }

        menu.setSubmenu(logoSubmenu, for: logoMenuItem)
        menu.addItem(logoMenuItem)
        menu.addItem(.separator())

        let resyncClaudeHooksMenuItem = menuItem(
            title: "Resync Claude Hooks",
            action: selectors.resyncClaudeHooks
        )
        menu.addItem(resyncClaudeHooksMenuItem)
        menu.addItem(.separator())

        let checkForUpdatesMenuItem = menuItem(
            title: "Check for Updates…",
            action: selectors.checkForUpdates
        )
        menu.addItem(checkForUpdatesMenuItem)
        menu.addItem(.separator())

        let quitMenuItem = menuItem(
            title: "Quit",
            action: selectors.quitFromMenu,
            keyEquivalent: "q"
        )
        menu.addItem(quitMenuItem)

        attach(statusItem: statusItem)
        if let button = statusItem.button {
            setImage(image)
            button.imagePosition = .imageOnly
            setToolTip("ZenIsland")
        }

        setMenu(menu)

        self.visibilityMenuItem = visibilityMenuItem
        self.screenMenuItem = screenMenuItem
        self.automaticScreenMenuItem = automaticScreenMenuItem
        self.zenMuxLogoMenuItem = zenMuxLogoMenuItem
        self.customLogoMenuItem = customLogoMenuItem
        self.resyncClaudeHooksMenuItem = resyncClaudeHooksMenuItem
        self.checkForUpdatesMenuItem = checkForUpdatesMenuItem
    }

    func rebuildScreenMenu(
        screens: [NSScreen] = NSScreen.screens,
        titleForScreen: (NSScreen, CGDirectDisplayID) -> String
    ) {
        guard
            let selectors,
            let target,
            let screenSubmenu = screenMenuItem?.submenu
        else {
            return
        }

        while screenSubmenu.items.count > 1 {
            screenSubmenu.removeItem(at: 1)
        }
        fixedScreenMenuItems.removeAll()

        guard !screens.isEmpty else {
            return
        }

        screenSubmenu.addItem(.separator())
        for screen in screens {
            guard let displayID = screen.displayID else {
                continue
            }

            let item = NSMenuItem(
                title: titleForScreen(screen, displayID),
                action: selectors.selectFixedScreenPlacement,
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = NSNumber(value: displayID)
            screenSubmenu.addItem(item)
            fixedScreenMenuItems.append(item)
        }
    }

    func updateMenuState(
        isCheckingForUpdates: Bool,
        isDownloadingUpdate: Bool,
        isAutomaticScreenSelected: Bool,
        isSelectedFixedScreen: (CGDirectDisplayID) -> Bool,
        selectedLogo: IslandBrandLogo,
        customLogoPath: String?,
        approvalPreviewEnabled: Bool
    ) {
        visibilityMenuItem?.title = "Show/Hide Island"
        if isDownloadingUpdate {
            checkForUpdatesMenuItem?.title = "Downloading Update…"
        } else if isCheckingForUpdates {
            checkForUpdatesMenuItem?.title = "Checking for Updates…"
        } else {
            checkForUpdatesMenuItem?.title = "Check for Updates…"
        }
        checkForUpdatesMenuItem?.isEnabled = !isCheckingForUpdates && !isDownloadingUpdate
        automaticScreenMenuItem?.state = isAutomaticScreenSelected ? .on : .off
        for item in fixedScreenMenuItems {
            guard let representedDisplayID = item.representedObject as? NSNumber else {
                item.state = .off
                continue
            }
            item.state = isSelectedFixedScreen(CGDirectDisplayID(representedDisplayID.uint32Value)) ? .on : .off
        }
        zenMuxLogoMenuItem?.state = selectedLogo == .zenmux ? .on : .off
        customLogoMenuItem?.state = selectedLogo == .custom ? .on : .off
        customLogoMenuItem?.isEnabled = customLogoPath != nil
        _ = resyncClaudeHooksMenuItem
        _ = approvalPreviewEnabled
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }
}

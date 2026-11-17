//
//  BrowsingViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 29.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import WebKit

class BrowsingViewController: UIViewController, TabDelegate {

	@objc
	enum Transition: Int {
		case `default`
		case notAnimated
		case inBackground
	}

	/// UserDefaults key of the "merge bars like Safari" switch in the settings.
	static let mergedBarsKey = "CibulaMergedBars"

	/// Height of a tab card in the tab overview, in relation to its width (like Safari).
	static let tabCardRatio: CGFloat = 1.4

	/// The user removed the "Donate" card of the start page for good.
	private static let donateHiddenKey = "CibulaDonateCardHidden"

	/// The user removed the "Donate" card until the next start of the app.
	private static var donateHiddenThisSession = false

	private static let reloadImg = UIImage(systemName: "arrow.clockwise")
	private static let stopImg = UIImage(systemName: "xmark")

	private let barGlassTag = 7702
	private let backdropTag = 7703

	/// Floating bars (iPhone only).
	private var floating = false

	/// Address bar and toolbar are one capsule at the bottom.
	private var merged = false

	private var topBarTopConstraint: NSLayoutConstraint?
	private var toolbarBottomConstraint: NSLayoutConstraint?

	private let edgeGap: CGFloat = 6
	private let dockBottomGap: CGFloat = 16

	/// The start page: title, search field, favorites and the "Donate" card.
	private var startPage: CibulaStartPage?

	/// The tab which shows (or has just left) the start page.
	private var startOwner: ObjectIdentifier?

	/// When the user left the start page in that tab. The start page stays until the new page is there.
	private var startLeft: Date?
	private var startPollGeneration = 0

	/// Dark cover over the whole interface at startup. It goes away, when everything is loaded.
	private var cover: UIView?
	private var coverSince = Date()

	/// Live thumbnails of the tabs for the tab overview.
	var tabSnapshots = [ObjectIdentifier: UIImage]()

	@IBOutlet weak var searchBar: UIView?
	@IBOutlet weak var searchBarHeightConstraint: NSLayoutConstraint? {
		didSet {
			searchBarHeight = searchBarHeightConstraint?.constant
		}
	}
	@IBOutlet weak var securityBt: UIButton? {
		didSet {
			securityBt?.accessibilityHint = NSLocalizedString("Security Level for This Site", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var searchFl: UITextField? {
		didSet {
			searchFl?.leftView = encryptionBt
			searchFl?.rightView = reloadBt
			searchFl?.accessibilityHint = NSLocalizedString("Address and search bar", comment: "VoiceOver")
		}
	}

	lazy var encryptionBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		button.accessibilityLabel = NSLocalizedString("Certificate Information", comment: "VoiceOver")

		return button
	}()

	private lazy var reloadBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
		button.setImage(BrowsingViewController.reloadImg, for: .normal)
		button.tintColor = .label

		button.widthAnchor.constraint(equalToConstant: 24).isActive = true
		button.heightAnchor.constraint(equalToConstant: 24).isActive = true

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		return button
	}()

	@IBOutlet weak var torBt: UIButton? {
		didSet {
			torBt?.accessibilityLabel = NSLocalizedString("Tor Circuit", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var progress: UIProgressView?
	@IBOutlet weak var container: UIView?
	@IBOutlet weak var containerBottomConstraint2Toolbar: NSLayoutConstraint? // Not available on iPad

	@IBOutlet weak var tabsCollection: UICollectionView? {
		didSet {
			tabsCollection?.dragInteractionEnabled = true
		}
	}

	@IBOutlet weak var toolbar: UIView? // Not available on iPad
	@IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint? { // Not available on iPad
		didSet {
			toolbarHeight = toolbarHeightConstraint?.constant
		}
	}
	@IBOutlet weak var mainTools: UIStackView? // Not available on iPad
	@IBOutlet weak var tabsTools: UIView?
	@IBOutlet weak var backBt: UIButton? {
		didSet {
			backBt?.accessibilityLabel = NSLocalizedString("Back", comment: "VoiceOver")
		}
	}
	@IBOutlet weak var frwrdBt: UIButton? {
		didSet {
			frwrdBt?.accessibilityLabel = NSLocalizedString("Forward", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var findBt: UIButton? {
		didSet {
			if #available(iOS 16.0, *) {
				// No change.
			}
			else {
				// We do not support find below iOS 16.
				findBt?.isHidden = true

				// Reduce used width and height to 0.
				for constraint in findBt?.constraints ?? [] {
					if constraint.firstAnchor is NSLayoutAnchor<NSLayoutDimension> {
						constraint.constant = 0
					}
				}

				// Reduce one margin constraint to 0.
				for constraint in findBt?.superview?.constraints ?? [] {
					if let item = constraint.firstItem as? UIButton,
						item == findBt,
						constraint.secondItem is UIButton
					{
						constraint.constant = 0
					}
				}
			}
		}
	}

	@IBOutlet weak var actionBt: UIButton?
	@IBOutlet weak var bookmarksBt: UIButton?
	@IBOutlet weak var newTabBt: UIButton?

	@IBOutlet weak var tabsBt: UIButton? {
		didSet {
			tabsBt?.setTitleColor(tabsBt?.tintColor, for: .normal)

			tabsBt?.addTarget(self, action: #selector(showOverview), for: .touchUpInside)

			tabsBt?.accessibilityHint = NSLocalizedString("Tabs", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var settingsBt: UIButton? {
		didSet {
			settingsBt?.accessibilityLabel = NSLocalizedString("Settings", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var newTabFromOverviewBt: UIButton? {
		didSet {
			newTabFromOverviewBt?.addTarget(self, action: #selector(newTabFromOverview), for: .touchUpInside)
		}
	}

	@IBOutlet weak var hideOverviewBt: UIButton? {
		didSet {
			hideOverviewBt?.setTitle(NSLocalizedString("Done", comment: ""))
			hideOverviewBt?.addTarget(self, action: #selector(hideOverview), for: .touchUpInside)
		}
	}

	@objc
	var tabs = [Tab]()

	private var currentTabIndex = -1

	@objc
	weak var currentTab: Tab? {
		get {
			return currentTabIndex < 0 || currentTabIndex >= tabs.count ? tabs.last : tabs[currentTabIndex]
		}
		set {
			if let tab = newValue {
				currentTabIndex = tabs.firstIndex(of: tab) ?? -1
			}
			else {
				currentTabIndex = -1
			}

			if currentTab?.needsRefresh ?? false {
				currentTab?.refresh()
			}
		}
	}

	var searchBarHeight: CGFloat!
	var toolbarHeight: CGFloat? // Not available on iPad

	lazy var containerBottomConstraint2Superview: NSLayoutConstraint?
		= container?.bottomAnchor.constraint(equalTo: view.bottomAnchor)

	lazy var liveSearchVc = LiveSearchViewController()

	init() {
		var nib = String(describing: type(of: self))

		if UIDevice.current.userInterfaceIdiom == .pad {
			nib += "-iPad"
		}

		super.init(nibName: nib, bundle: Bundle(for: type(of: self)))
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		CibulaTheme.applyOnce()

		tabsCollection?.register(TabCell.nib, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			tab.add(to: container)
		}

		styleChrome()

		updateChrome()

		// The start page shows the bookmarks, so it has to follow every change of them.
		NotificationCenter.default.addObserver(forName: .cibulaBookmarksChanged, object: nil, queue: .main) { [weak self] _ in
			self?.startPage?.reload()
		}

		showStartupCover()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		updateFloatingMetrics()

		let nc = NotificationCenter.default

		nc.addObserver(self,
					   selector: #selector(keyboardWillShow(notification:)),
					   name: UIResponder.keyboardWillShowNotification,
					   object: nil)

		nc.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)),
					   name: UIResponder.keyboardWillHideNotification,
					   object: nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// Blue buttons and links of the whole app become purple.
		CibulaTheme.applyWindow(view.window)

		updateFloatingMetrics()

		// We made it this far, remove lock on previous startup.
		Settings.stateRestoreLock = false

		if currentTab?.needsRefresh ?? false {
			currentTab?.refresh()
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		let nc = NotificationCenter.default

		nc.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		nc.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)

		coder.encode(tabs.map({ $0.url.clean }), forKey: "webViewTabs")
		coder.encode(NSNumber(value: currentTabIndex), forKey: "curTabIndex")
	}

	func encodeRestorableState(with activity: NSUserActivity) {
		if !(currentTab?.url.isSpecial ?? true) {
			activity.webpageURL = currentTab?.url.clean
			activity.title = currentTab?.title
		}
		activity.userInfo = ["webViewTabs": tabs.map({ $0.url.clean }),
							 "curTabIndex": NSNumber(value: currentTabIndex)]
	}

	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)

		var urls = coder.decodeObject(forKey: "webViewTabs") as? [URL?]

		// Legacy support.
		if urls == nil {
			urls = (coder.decodeObject(forKey: "webViewTabs") as? [[String: Any]])?
				.map { $0["url"] as? URL }
		}

		decodeRestorableState(
			urls,
			coder.decodeObject(forKey: "curTabIndex") as? NSNumber)
	}

	func decodeRestorableState(with activity: NSUserActivity) {
		decodeRestorableState(
			activity.userInfo?["webViewTabs"] as? [URL?],
			activity.userInfo?["curTabIndex"] as? NSNumber)
	}

	func decodeRestorableState(_ urls: [URL?]?, _ currentTabIndex: NSNumber?) {
		for url in urls ?? [] {
			debug("Try restoring tab with \(url?.absoluteString ?? "(nil)").")

			addNewTab(url, transition: .notAnimated)
		}

		if let currentTabIndex = currentTabIndex {
			self.currentTabIndex = currentTabIndex.intValue
		}

		for tab in tabs {
			tab.isHidden = tab != currentTab
			tab.isUserInteractionEnabled = true
			tab.add(to: container)
		}

		currentTab?.refresh()

		updateChrome()
	}


	// MARK: Actions

	@IBAction func action(_ sender: UIButton) {
		unfocusSearchField()

		switch sender {
		case securityBt:
			let vc = SecurityPopUpViewController()
			let url = currentTab?.url.clean

			// Don't allow special pages to customize!
			vc.host = (url?.isSpecial ?? true) ? nil : url?.host ?? url?.path

			present(vc, sender)

		case encryptionBt:
			guard let certificate = currentTab?.tlsCertificate else {
				return
			}

			let vc = CertificateViewController()
			vc.certificate = certificate
			vc.title = currentTab?.url.host
			present(UINavigationController(rootViewController: vc), sender)

		case reloadBt:
			if currentTab?.isLoading ?? false {
				currentTab?.stop()
			}
			else {
				currentTab?.refresh()
			}
			updateReloadBt()

		case torBt:
			let vc = CircuitViewController()
			vc.currentUrl = currentTab?.url.clean
			present(vc, sender)

		case backBt:
			currentTab?.goBack()

		case frwrdBt:
			currentTab?.goForward()

		case findBt:
			currentTab?.toggleFind()

		case actionBt:
			guard let currentTab = currentTab else {
				return
			}

			present(UIActivityViewController(
				activityItems: [currentTab],
				applicationActivities: [DownloadActivity(), AddBookmarkActivity(), SafariActivity()]),
					sender)

		case newTabBt:
			addEmptyTabAndFocus()

		case settingsBt:
			showSettings()

		default:
			break
		}
	}

	@IBAction func showBookmarks() {
		unfocusSearchField()

		AppDelegate.shared?.dismissModals(of: BookmarksViewController.self)

		let bookmarks = BookmarksViewController.instantiate()
		bookmarks.overrideUserInterfaceStyle = .dark

		present(bookmarks, bookmarksBt)
	}

	@discardableResult
	@objc
	func showSettings() -> UINavigationController {
		AppDelegate.shared?.dismissModals(of: SettingsViewController.self)

		let navC = SettingsViewController.instantiate()
		navC.overrideUserInterfaceStyle = .dark

		present(navC)

		return navC
	}

	@objc func keyboardWillShow(notification: Notification) {
		if let kbSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
			let insets = UIEdgeInsets(top: 0, left: 0, bottom: kbSize.height, right: 0)
			liveSearchVc.tableView.contentInset = insets
			liveSearchVc.tableView.scrollIndicatorInsets = insets
		}

		liftDock(notification, up: true)
	}

	@objc func keyboardWillBeHidden(notification: Notification) {
		liveSearchVc.tableView.contentInset = .zero
		liveSearchVc.tableView.scrollIndicatorInsets = .zero

		liftDock(notification, up: false)
	}


	// MARK: TabDelegate

	func updateChrome() {
		debug("#updateChrome progress=\(currentTab?.progress ?? 1)")

		updateFloatingMetrics()

		updateStartOverlay()

		revealInterfaceIfReady()

		if let progress = progress {
			progress.progress = currentTab?.progress ?? 1

			if progress.progress >= 1 {
				if !progress.isHidden {
					view.transition({ progress.isHidden = true })
				}
			}
			else {
				if progress.isHidden {
					view.transition({ progress.isHidden = false })
				}
			}
		}

		updateReloadBt()

		updateSearchField()

		// The last non-hidden should be the one which is showing.
		guard let tab = tabs.last(where: { !$0.isHidden }) else {
			securityBt?.setTitle(nil)
			backBt?.isEnabled = false
			frwrdBt?.isEnabled = false
			findBt?.isEnabled = false
			actionBt?.isEnabled = false
			updateTabCount()

			return
		}

		let preset = SecurityPreset(HostSettings.for(tab.url.host))

		if preset == .custom {
			securityBt?.setBackgroundImage(SecurityLevelCell.customShieldImage, for: .normal)
			securityBt?.setTitle(nil)
		}
		else {
			securityBt?.setBackgroundImage(SecurityLevelCell.shieldImage?.tinted(with: preset.color), for: .normal)
			securityBt?.setTitle(preset.shortcode)
		}

		updateEncryptionBt(tab.secureMode)
		backBt?.isEnabled = tab.canGoBack
		frwrdBt?.isEnabled = tab.canGoForward
		findBt?.isEnabled = !tab.url.isSpecial
		actionBt?.isEnabled = tab.url.isSearchable
		updateTabCount()

		if !(tabsCollection?.isHidden ?? true) {
			tabsCollection?.reloadData()
		}
	}

	@objc
	@discardableResult
	func addNewTab(_ url: URL? = nil, configuration: WKWebViewConfiguration? = nil) -> Tab? {
		return addNewTab(url, transition: .default, configuration: configuration)
	}

	@discardableResult
	func addNewTab(_ url: URL? = nil,
				   transition: Transition = .default,
				   configuration: WKWebViewConfiguration? = nil,
				   completion: ((Bool) -> Void)? = nil) -> Tab?
	{
		debug("#addNewTab url=\(String(describing: url)), transition=\(transition), completion=\(String(describing: completion))")

		// Remember how the page we are leaving looks like.
		captureSnapshot()

		let tab = Tab(restorationId: url?.absoluteString, configuration: configuration)

		tab.load(url)

		tab.tabDelegate = self

		tabs.append(tab)

		tab.scrollViewDelegate = self
		tab.isHidden = true
		tab.add(to: container)

		let animations = {
			for otherTab in self.tabs {
				otherTab.isHidden = otherTab != tab
			}
		}

		let completionForeground = { (finished: Bool) in
			self.currentTab = tab

			self.updateChrome()

			completion?(finished)
		}

		switch transition {
		case .notAnimated:
			animations()
			completionForeground(true)

		case .inBackground:
			completion?(true)

		default:
			container?.transition(animations, completionForeground)
		}

		if #available(iOS 18, *) {
			TabEntity.add(tab: tab)
		}

		return tab
	}

	func removeTab(_ tab: Tab, focus: Tab? = nil) {
		debug("#removeTab tab=\(tab) focus=\(String(describing: focus))")

		unfocusSearchField()

		container?.transition({
			tab.isHidden = true
			(focus ?? self.tabs.last)?.isHidden = false
		}) { _ in
			self.tabSnapshots[ObjectIdentifier(tab)] = nil

			tab.close()
			self.tabs.removeAll { $0 == tab }

			if #available(iOS 18, *) {
				TabEntity.removeTab(withId: tab.hash)
			}

			self.currentTab = focus ?? self.tabs.last
			self.currentTab?.isHidden = false

			self.updateChrome()
		}
	}

	func getTab(ipcId: String?) -> Tab? {
		return tabs.first { $0.ipcId == ipcId }
	}

	func getTab(hash: Int?) -> Tab? {
		return tabs.first { $0.hash == hash }
	}

	func getIndex(of tab: Tab) -> Int? {
		return tabs.firstIndex(of: tab)
	}

	func unfocusSearchField() {
		if searchFl?.isFirstResponder ?? false {
			searchFl?.resignFirstResponder()
		}
	}


	// MARK: Public Methods

	@objc
	func becomesVisible() {
		if tabs.count < 1 {
			addNewTab()
		}
	}

	@objc
	func addEmptyTabAndFocus() {
		addNewTab() { _ in
			self.focusSearchField()
		}
	}

	@objc
	func switchToTab(_ index: Int) {
		if index < 0 || index >= tabs.count {
			return
		}

		captureSnapshot()

		let focussing = tabs[index]

		container?.transition({
			for tab in self.tabs {
				tab.isHidden = tab != focussing
			}
		}) { _ in
			self.currentTab = focussing
			self.updateChrome()
		}
	}

	@objc
	func removeCurrentTab() {
		guard let currentTab = currentTab else {
			return
		}

		removeTab(currentTab)
	}

	@objc
	func removeAllTabs() {
		for tab in tabs {
			tab.close()
		}

		tabs.removeAll()
		tabSnapshots.removeAll()

		currentTab = nil

		WebsiteStorage.shared.cleanup()

		self.updateChrome()
	}

	@objc
	func focusSearchField() {
		if !(searchFl?.isFirstResponder ?? false) {
			searchFl?.becomeFirstResponder()
		}
	}

	func debug(_ msg: String) {
		Log.debug(for: Self.self, msg)
	}

	/**
	Takes a picture of the page which is showing right now, for the tab overview.
	Like in Safari it shows the top of the page, without the area under the floating bars.
	The start page (title, search field, favorites) is part of the picture.
	Only works while the page is visible, so it is called before the page goes away.
	*/
	func captureSnapshot() {
		guard let container = container,
			  !container.isHidden,
			  container.bounds.width > 0,
			  container.bounds.height > 0,
			  let tab = currentTab
		else {
			return
		}

		let width = container.bounds.width
		let height = width * Self.tabCardRatio

		// The page starts below the safe area, the part above it is empty.
		let skip = floating ? view.safeAreaInsets.top : 0

		let format = UIGraphicsImageRendererFormat()
		format.scale = 1.5

		let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)

		tabSnapshots[ObjectIdentifier(tab)] = renderer.image { _ in
			container.drawHierarchy(
				in: CGRect(x: 0, y: -skip, width: container.bounds.width, height: container.bounds.height),
				afterScreenUpdates: false)

			// The start page lies over the web view.
			if let page = startPage, !page.isHidden {
				page.drawHierarchy(
					in: CGRect(x: 0, y: -skip, width: page.bounds.width, height: page.bounds.height),
					afterScreenUpdates: false)
			}
		}
	}

	/**
	Keeps the page clear of the floating bars: the page itself fills the whole screen
	and scrolls under the glass, only its safe area is reduced by the bars.
	*/
	func updateFloatingMetrics(overview: Bool? = nil) {
		guard floating else {
			return
		}

		let inOverview = overview ?? !(tabsCollection?.isHidden ?? true)

		var insets = UIEdgeInsets.zero

		if !inOverview {
			let systemBottom = view.window?.safeAreaInsets.bottom ?? 0
			let dockHeight = toolbarHeightConstraint?.constant ?? 49

			insets.bottom = max(0, dockBottomGap + dockHeight + 8 - systemBottom)

			if !merged {
				let barHeight: CGFloat = searchBarHeight ?? 50

				insets.top = edgeGap + barHeight + 10
			}
		}

		if additionalSafeAreaInsets != insets {
			additionalSafeAreaInsets = insets
		}

		// The top bar sits relative to the safe area, so take our own extra inset out again.
		topBarTopConstraint?.constant = edgeGap - additionalSafeAreaInsets.top
	}

	/**
	The start page of Cibula lies over the web view, as long as a tab shows it.
	When the user leaves it (typed address, tapped a favorite), the old page stays on the screen until the new
	one has really arrived, so the screen doesn't go blank.
	*/
	func updateStartOverlay() {
		guard floating else {
			return
		}

		// Never over the tab overview.
		if !(tabsCollection?.isHidden ?? true) {
			setStartPageVisible(false)

			return
		}

		let tab = currentTab
		let tabId = tab.map { ObjectIdentifier($0) }

		var visible = false

		if tab?.url == URL.start {
			startOwner = tabId
			startLeft = nil
			startPollGeneration += 1

			visible = true
		}
		else if let owner = startOwner, owner == tabId {
			// The user has just left the start page in this tab.
			if startLeft == nil {
				startLeft = Date()
				startPollGeneration += 1

				pollNewPage(startPollGeneration)
			}

			visible = true
		}
		else {
			// Another tab.
			startOwner = nil
			startLeft = nil
		}

		setStartPageVisible(visible)
	}


	// MARK: Private Methods

	private static func isStartHref(_ href: String) -> Bool {
		return href.hasPrefix("file:") && URL(string: href)?.lastPathComponent == URL.start.lastPathComponent
	}

	/// The web view which is showing right now.
	private func visibleWebView() -> WKWebView? {
		func find(_ view: UIView) -> WKWebView? {
			if view.isHidden {
				return nil
			}

			if let webView = view as? WKWebView {
				return webView
			}

			for sub in view.subviews.reversed() {
				if let webView = find(sub) {
					return webView
				}
			}

			return nil
		}

		guard let container = container else {
			return nil
		}

		return find(container)
	}

	/**
	Asks the page in the web view, which document it shows. As long as that is still the start page,
	the new page has not arrived and the start page stays. Then it goes away at once.
	*/
	private func pollNewPage(_ generation: Int) {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
			guard let self = self, generation == self.startPollGeneration, self.startLeft != nil else {
				return
			}

			guard let webView = self.visibleWebView() else {
				self.pollNewPage(generation)

				return
			}

			webView.evaluateJavaScript("document.location.href") { [weak self] result, _ in
				guard let self = self, generation == self.startPollGeneration, self.startLeft != nil else {
					return
				}

				if let href = result as? String, !Self.isStartHref(href) {
					self.startOwner = nil
					self.startLeft = nil

					self.setStartPageVisible(false)
				}
				else {
					self.pollNewPage(generation)
				}
			}
		}
	}

	private func setStartPageVisible(_ visible: Bool) {
		guard let container = container else {
			return
		}

		if visible && startPage == nil {
			let page = CibulaStartPage()
			page.translatesAutoresizingMaskIntoConstraints = false

			page.donateAvailable = !UserDefaults.standard.bool(forKey: Self.donateHiddenKey) && !Self.donateHiddenThisSession

			page.onSubmitSearch = { [weak self] text in
				self?.submitStartSearch(text)
			}
			page.onOpen = { [weak self] url in
				self?.unfocusSearchField()
				self?.currentTab?.load(url)
			}
			page.onOpenInNewTab = { [weak self] url in
				self?.addNewTab(url)
			}
			page.onAdd = { [weak self] in
				self?.addFavorite()
			}
			page.onEdit = { [weak self] index in
				self?.editFavorite(index)
			}
			page.onDelete = { index in
				if index >= 0 && index < NcBookmarks.root.bookmarks.count {
					NcBookmarks.root.bookmarks.remove(at: index)
					NcBookmarks.store()
				}
			}
			page.onDonate = { [weak self] in
				self?.openDonate()
			}
			page.onCloseDonate = { [weak self] in
				self?.askToRemoveDonateCard()
			}

			view.insertSubview(page, aboveSubview: container)

			NSLayoutConstraint.activate([
				page.topAnchor.constraint(equalTo: view.topAnchor),
				page.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				page.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				page.trailingAnchor.constraint(equalTo: view.trailingAnchor)
			])

			startPage = page

			page.reload()
		}

		if visible && (startPage?.isHidden ?? false) {
			startPage?.reload()
		}

		startPage?.isHidden = !visible

		if visible {
			startPage?.syncSettings()
		}
	}

	/// "+" on the start page: a sheet to add a favorite. "Cancel" brings the user straight back.
	private func addFavorite() {
		unfocusSearchField()

		let add = BookmarkViewController()

		let navC = UINavigationController(rootViewController: add)
		navC.overrideUserInterfaceStyle = .dark

		present(navC)
	}

	private func editFavorite(_ index: Int) {
		unfocusSearchField()

		let edit = BookmarkViewController()
		edit.index = index

		let navC = UINavigationController(rootViewController: edit)
		navC.overrideUserInterfaceStyle = .dark

		present(navC)
	}

	/// The donation screen opens on its own, "Done" brings the user straight back to the browser.
	private func openDonate() {
		unfocusSearchField()

		let navC = UINavigationController(rootViewController: CibulaDonateViewController())
		navC.overrideUserInterfaceStyle = .dark

		present(navC)
	}

	/// The cross on the "Donate" card.
	private func askToRemoveDonateCard() {
		let alert = UIAlertController(
			title: CibulaL10n.tr("Do you really want to remove “Donate” from the home screen?",
								 "Вы точно хотите убрать «Пожертвовать» с главного экрана?",
								 "Ви точно хочете прибрати «Пожертвувати» з головного екрана?"),
			message: nil,
			preferredStyle: .alert)

		alert.overrideUserInterfaceStyle = .dark

		// Red.
		alert.addAction(UIAlertAction(
			title: CibulaL10n.tr("Remove forever", "Убрать навсегда", "Прибрати назавжди"),
			style: .destructive) { [weak self] _ in
				UserDefaults.standard.set(true, forKey: Self.donateHiddenKey)

				self?.startPage?.donateAvailable = false

				self?.explainWhereToDonate()
			})

		// White.
		let once = UIAlertAction(
			title: CibulaL10n.tr("Remove", "Убрать", "Прибрати"),
			style: .default) { [weak self] _ in
				Self.donateHiddenThisSession = true

				self?.startPage?.donateAvailable = false
			}
		once.setValue(UIColor.white, forKey: "titleTextColor")
		alert.addAction(once)

		present(alert, animated: true)
	}

	private func explainWhereToDonate() {
		let path = CibulaL10n.tr("Settings > Donate", "Настройки > Пожертвовать", "Налаштування > Пожертвувати")

		let text = CibulaL10n.tr(
			"You can always support the author in \(path)",
			"Вы всегда сможете поддержать автора, перейдя в \(path)",
			"Ви завжди зможете підтримати автора, перейшовши в \(path)")

		let attributed = NSMutableAttributedString(
			string: text,
			attributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.white])

		if let range = text.range(of: path) {
			attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 13), range: NSRange(range, in: text))
		}

		let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
		alert.overrideUserInterfaceStyle = .dark
		alert.setValue(attributed, forKey: "attributedMessage")

		let ok = UIAlertAction(title: CibulaL10n.tr("OK", "Ок", "Ок"), style: .default)
		ok.setValue(UIColor.white, forKey: "titleTextColor")
		alert.addAction(ok)

		present(alert, animated: true)
	}

	/**
	Covers everything with the dark purple of the launch screen, so the parts of the interface
	(search field, bars, page) don't appear one after the other.
	*/
	private func showStartupCover() {
		let cover = GradientBackdropView()
		cover.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(cover)

		NSLayoutConstraint.activate([
			cover.topAnchor.constraint(equalTo: view.topAnchor),
			cover.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			cover.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])

		self.cover = cover
		coverSince = Date()

		scheduleCoverCheck()
	}

	/// The page could finish without anybody telling us, so look again and again, until the cover is gone.
	private func scheduleCoverCheck() {
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
			guard let self = self, self.cover != nil else {
				return
			}

			// Never keep the cover longer than 5 seconds.
			self.revealInterfaceIfReady(force: Date().timeIntervalSince(self.coverSince) > 5)

			self.scheduleCoverCheck()
		}
	}

	private func revealInterfaceIfReady(force: Bool = false) {
		guard let cover = cover else {
			return
		}

		if !force {
			// Wait until the first tab exists.
			guard let tab = currentTab else {
				return
			}

			let loaded = !tab.isLoading && tab.progress >= 1
			let waited = Date().timeIntervalSince(coverSince)

			if tab.url == URL.start {
				// The start page has to be completely loaded.
				guard loaded else {
					return
				}
			}
			else {
				// A restored page can take long over Tor. It gets a short time only.
				guard loaded || waited > 1.2 else {
					return
				}
			}
		}

		self.cover = nil

		// A short moment, so the web view can paint its first picture, then the cover fades out.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
			UIView.animate(withDuration: 0.3, animations: {
				cover.alpha = 0
			}) { _ in
				cover.removeFromSuperview()
			}
		}
	}

	private func submitStartSearch(_ text: String) {
		guard let field = searchFl else {
			return
		}

		field.text = text

		_ = field.delegate?.textFieldShouldReturn?(field)
	}

	/**
	Gives the top and bottom bars a floating liquid glass look, like Safari.
	Optionally merges both bars into one at the bottom.
	*/
	private func styleChrome() {
		let lilac = UIColor(red: 0.90, green: 0.82, blue: 1, alpha: 1)

		let isPhone = UIDevice.current.userInterfaceIdiom != .pad

		merged = isPhone && toolbar != nil && UserDefaults.standard.bool(forKey: Self.mergedBarsKey)
		floating = isPhone && searchBar != nil && toolbar != nil && container != nil

		// The extra safe area we add for the page must not squeeze the content of the bars.
		let marginViews: [UIView?] = [searchBar, toolbar, mainTools, tabsTools]

		for item in marginViews {
			item?.insetsLayoutMarginsFromSafeArea = false
		}

		addBackdrop()

		if floating, let sb = searchBar, let tb = toolbar {
			searchBarHeightConstraint?.constant = 50
			searchBarHeight = 50

			if merged {
				moveAddressBarIntoToolbar()
			}

			rebuildVerticalLayout()

			if !merged {
				insetHorizontally(sb, by: 12)
				addGlass(to: sb)
			}

			insetHorizontally(tb, by: 12)
			addGlass(to: tb)

			hideHairlines(in: sb)
			hideHairlines(in: tb)

			if !merged {
				view.bringSubviewToFront(sb)
			}

			view.bringSubviewToFront(tb)
		}
		else if let sb = searchBar {
			sb.backgroundColor = .clear
			sb.overrideUserInterfaceStyle = .dark
		}

		// The loading line sits inside the top edge of the panel.
		if let progress = progress {
			progress.progressTintColor = UIColor(red: 0.77, green: 0.55, blue: 1, alpha: 1)
			progress.trackTintColor = UIColor.white.withAlphaComponent(0.12)
			progress.layer.cornerRadius = 2
			progress.clipsToBounds = true
		}

		searchBar?.tintColor = lilac
		toolbar?.tintColor = lilac
		mainTools?.tintColor = lilac
		tabsBt?.tintColor = lilac
		tabsBt?.setTitleColor(lilac, for: .normal)

		// The box around the address field comes from the layout file. Remove it,
		// the capsule is the box now. Inside the shared capsule it stays as a soft pill.
		if let box = searchFl?.superview {
			box.backgroundColor = merged ? UIColor.white.withAlphaComponent(0.12) : .clear
			box.layer.cornerRadius = merged ? 15 : 8
			box.layer.cornerCurve = .continuous
		}

		if let field = searchFl {
			field.overrideUserInterfaceStyle = .dark
			field.borderStyle = .none
			field.backgroundColor = .clear
			field.textColor = .white
			field.tintColor = lilac

			// What stands in the empty address bar, e.g. on the start page.
			field.attributedPlaceholder = NSAttributedString(
				string: CibulaL10n.tr("Enter address…", "Введите адрес…", "Введіть адресу…"),
				attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)])
		}

		reloadBt.tintColor = lilac

		// The shield and the onion are too big for the slim capsule.
		securityBt?.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
		torBt?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
		torBt?.tintColor = lilac

		view.layoutIfNeeded()
	}

	/// Dark purple background, visible in the tab overview.
	private func addBackdrop() {
		if view.viewWithTag(backdropTag) != nil {
			return
		}

		let backdrop = GradientBackdropView()
		backdrop.tag = backdropTag
		backdrop.isUserInteractionEnabled = false
		backdrop.translatesAutoresizingMaskIntoConstraints = false
		view.insertSubview(backdrop, at: 0)

		NSLayoutConstraint.activate([
			backdrop.topAnchor.constraint(equalTo: view.topAnchor),
			backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
	}

	/**
	Moves the address bar from the top into the bottom bar, above the buttons.
	The bottom bar grows by the height of the address bar.
	*/
	private func moveAddressBarIntoToolbar() {
		guard let top = searchBar, let bottom = toolbar else {
			return
		}

		let topHeight: CGFloat = 50

		top.removeFromSuperview()
		bottom.addSubview(top)
		top.translatesAutoresizingMaskIntoConstraints = false
		top.backgroundColor = .clear

		NSLayoutConstraint.activate([
			top.topAnchor.constraint(equalTo: bottom.topAnchor, constant: 4),
			top.leadingAnchor.constraint(equalTo: bottom.leadingAnchor),
			top.trailingAnchor.constraint(equalTo: bottom.trailingAnchor)
		])

		let newHeight = (toolbarHeightConstraint?.constant ?? 49) + topHeight + 4
		toolbarHeight = newHeight
		toolbarHeightConstraint?.constant = newHeight

		// The buttons stay in the lower part.
		mainTools?.isLayoutMarginsRelativeArrangement = true
		mainTools?.layoutMargins = UIEdgeInsets(top: topHeight + 4, left: 0, bottom: 0, right: 0)
	}

	/**
	Lets go of the old vertical chain (top bar - page - bottom bar) and builds a new one:
	the page fills the whole screen, the bars float above it.
	The loading line moves into the top edge of the top bar (or of the shared bottom bar).
	*/
	private func rebuildVerticalLayout() {
		guard let sb = searchBar, let tb = toolbar, let ct = container else {
			return
		}

		var obsolete = [NSLayoutConstraint]()

		for constraint in view.constraints where constraint.isActive {
			if linked(constraint, ct, sb) || linked(constraint, ct, progress) || linked(constraint, tb, ct) {
				obsolete.append(constraint)
			}
			else if edgeAttribute(of: constraint, for: sb) == .top || edgeAttribute(of: constraint, for: tb) == .bottom {
				obsolete.append(constraint)
			}
		}

		NSLayoutConstraint.deactivate(obsolete)

		let toolbarBottom = tb.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -dockBottomGap)
		toolbarBottomConstraint = toolbarBottom

		NSLayoutConstraint.activate([
			ct.topAnchor.constraint(equalTo: view.topAnchor),
			ct.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			toolbarBottom
		])

		if !merged {
			let top = sb.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: edgeGap)
			topBarTopConstraint = top
			top.isActive = true
		}

		if let progress = progress {
			let host: UIView = merged ? tb : sb

			// Moving it into the bar drops all its old constraints to the screen.
			progress.removeFromSuperview()
			host.addSubview(progress)
			progress.translatesAutoresizingMaskIntoConstraints = false

			NSLayoutConstraint.activate([
				progress.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 26),
				progress.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -26),
				progress.topAnchor.constraint(equalTo: host.topAnchor, constant: 3),
				progress.heightAnchor.constraint(equalToConstant: 4)
			])
		}
	}

	/// Pulls a bar away from the left and right screen edges, if the layout pins it there.
	private func insetHorizontally(_ bar: UIView, by inset: CGFloat) {
		for constraint in view.constraints where constraint.isActive {
			let barIsFirst = constraint.firstItem === bar
			let barIsSecond = constraint.secondItem === bar

			if barIsFirst == barIsSecond {
				continue
			}

			let other: AnyObject? = barIsFirst ? constraint.secondItem : constraint.firstItem
			let attribute = barIsFirst ? constraint.firstAttribute : constraint.secondAttribute
			let otherAttribute = barIsFirst ? constraint.secondAttribute : constraint.firstAttribute

			guard attribute == otherAttribute, isScreenEdge(other) else {
				continue
			}

			var inward: CGFloat = 0

			switch attribute {
			case .leading, .left:
				inward = inset

			case .trailing, .right:
				inward = -inset

			default:
				break
			}

			if inward != 0 {
				constraint.constant += barIsFirst ? inward : -inward
			}
		}
	}

	/// Puts a rounded glass capsule behind the content of a bar.
	private func addGlass(to bar: UIView) {
		if bar.viewWithTag(barGlassTag) != nil {
			return
		}

		bar.backgroundColor = .clear
		bar.overrideUserInterfaceStyle = .dark

		let effect: UIVisualEffect

		if #available(iOS 26.0, *) {
			effect = UIGlassEffect()
		}
		else {
			effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
		}

		let glass = CapsuleGlassView(effect: effect)
		glass.tag = barGlassTag
		glass.frame = bar.bounds
		glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		glass.isUserInteractionEnabled = false
		glass.clipsToBounds = true
		glass.layer.cornerCurve = .continuous
		glass.layer.borderWidth = 0.5
		glass.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.35).cgColor

		// Dark purple layer on top of the glass, so the light icons stay readable on white pages.
		glass.contentView.backgroundColor = UIColor(red: 0.16, green: 0.05, blue: 0.30, alpha: 0.58)

		bar.insertSubview(glass, at: 0)
	}

	/// The thin grey lines of the old flat bars.
	private func hideHairlines(in bar: UIView) {
		for sub in bar.subviews where sub.tag != barGlassTag {
			let isLine = sub.constraints.contains {
				$0.firstAttribute == .height && $0.secondItem == nil && $0.constant <= 1
			}

			if isLine {
				sub.isHidden = true
			}
		}
	}

	/// In the shared capsule the bar must rise above the keyboard while typing an address.
	private func liftDock(_ notification: Notification, up: Bool) {
		guard merged, let constraint = toolbarBottomConstraint else {
			return
		}

		var offset = dockBottomGap

		if up {
			guard searchFl?.isFirstResponder ?? false,
				  let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
			else {
				return
			}

			let height = max(0, view.bounds.height - view.convert(frame, from: nil).minY)

			offset = height + 8
		}

		constraint.constant = -offset

		let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

		UIView.animate(withDuration: duration) {
			self.view.layoutIfNeeded()
		}
	}

	private func linked(_ constraint: NSLayoutConstraint, _ a: UIView?, _ b: UIView?) -> Bool {
		guard let a = a, let b = b else {
			return false
		}

		return (constraint.firstItem === a && constraint.secondItem === b)
			|| (constraint.firstItem === b && constraint.secondItem === a)
	}

	private func edgeAttribute(of constraint: NSLayoutConstraint, for bar: UIView) -> NSLayoutConstraint.Attribute? {
		if constraint.firstItem === bar, isScreenEdge(constraint.secondItem) {
			return constraint.firstAttribute
		}

		if constraint.secondItem === bar, isScreenEdge(constraint.firstItem) {
			return constraint.secondAttribute
		}

		return nil
	}

	private func isScreenEdge(_ item: AnyObject?) -> Bool {
		if let item = item as? UIView {
			return item === view
		}

		if let guide = item as? UILayoutGuide {
			return guide.owningView === view
		}

		return false
	}

	/**
	Update and center tab count in `tabsBt`.

	Honors right-to-left languages.
	*/
	private func updateTabCount() {
		tabsBt?.setTitle(Formatter.localize(tabs.count))

		var offset: CGFloat = 0

		if let titleLabel = tabsBt?.titleLabel, let imageView = tabsBt?.imageView {
			if UIView.userInterfaceLayoutDirection(for: tabsBt!.semanticContentAttribute) == .rightToLeft {
				offset = imageView.intrinsicContentSize.width / 2 // Move right edge to center of image.
					+ titleLabel.intrinsicContentSize.width / 2 // Move center of text to center of image.
					+ 3 // Correct for double-frame icon.
			}
			else {
				offset = -imageView.intrinsicContentSize.width / 2 // Move left edge to center of image.
					- titleLabel.intrinsicContentSize.width / 2 // Move center of text to center of image.
					- 3 // Correct for double-frame icon.
			}
		}

		// 2+2 in vertical direction is correction for double-frame icon
		// Ignore deprecation. UIButton.Configuration doesn't provide the vertical insets we need.
		tabsBt?.titleEdgeInsets = UIEdgeInsets(top: 2, left: offset, bottom: -2, right: -offset)

		// Half-way, in fresh style:
		// var conf = UIButton.Configuration.plain()
		// conf.imagePadding = offset
		// tabsBt.configuration = conf
	}

	/**
	Shows either a reload or stop icon, depending on if the current tab is currently loading or not.
	*/
	private func updateReloadBt() {
		if currentTab?.isLoading ?? false {
			reloadBt.setImage(BrowsingViewController.stopImg, for: .normal)
			reloadBt.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
		}
		else {
			reloadBt.setImage(BrowsingViewController.reloadImg, for: .normal)
			reloadBt.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		}
	}
}


/**
Languages of the app: English, Russian and Ukrainian.
The language of the system is used, unless the user picked one in the settings.
*/
enum CibulaL10n {

	/// "system", "en", "ru" or "uk".
	static let languageKey = "CibulaLanguage"

	static var chosen: String {
		UserDefaults.standard.string(forKey: languageKey) ?? "system"
	}

	/// The language which is actually used: "en", "ru" or "uk".
	static var code: String {
		let saved = chosen

		if saved == "en" || saved == "ru" || saved == "uk" {
			return saved
		}

		let first = Locale.preferredLanguages.first ?? "en"

		if first.hasPrefix("uk") {
			return "uk"
		}

		if first.hasPrefix("ru") {
			return "ru"
		}

		return "en"
	}

	static func tr(_ en: String, _ ru: String, _ uk: String) -> String {
		switch code {
		case "ru":
			return ru

		case "uk":
			return uk

		default:
			return en
		}
	}

	static func languageName(_ code: String) -> String {
		switch code {
		case "en":
			return "English"

		case "ru":
			return "Русский"

		case "uk":
			return "Українська"

		default:
			return tr("System", "Системный", "Системна")
		}
	}

	/// Remembers the choice. The texts of the system parts need a restart of the app.
	static func choose(_ code: String) {
		let defaults = UserDefaults.standard

		defaults.set(code, forKey: languageKey)

		if code == "system" {
			defaults.removeObject(forKey: "AppleLanguages")
		}
		else {
			defaults.set([code], forKey: "AppleLanguages")
		}
	}
}


/// Glass view with fully rounded ends.
private final class CapsuleGlassView: UIVisualEffectView {

	override func layoutSubviews() {
		super.layoutSubviews()

		layer.cornerRadius = min(bounds.height / 2, 28)
	}
}


/// Dark purple gradient, drawn behind everything.
private final class GradientBackdropView: UIView {

	override class var layerClass: AnyClass {
		CAGradientLayer.self
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		configure()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		configure()
	}

	private func configure() {
		guard let gradient = layer as? CAGradientLayer else {
			return
		}

		gradient.colors = [UIColor(red: 0.05, green: 0.00, blue: 0.10, alpha: 1).cgColor,
						   UIColor(red: 0.16, green: 0.04, blue: 0.32, alpha: 1).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
	}
}


/// A glass material, the same as the bars have. iOS 26 gets the real liquid glass.
private func cibulaGlassEffect() -> UIVisualEffect {
	if #available(iOS 26.0, *) {
		return UIGlassEffect()
	}

	return UIBlurEffect(style: .systemUltraThinMaterialDark)
}


/**
Search field of the start page: a glass capsule with the name of the search engine on the right.
It hands the text over to the real address bar, so nothing is searched in a different way.
*/
private final class StartSearchView: UIView, UITextFieldDelegate {

	let field = UITextField()

	var onSubmit: ((String) -> Void)?

	private let engineLabel = UILabel()

	private let lilac = UIColor(red: 0.90, green: 0.82, blue: 1, alpha: 1)

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

	/// Texts can change (language, search engine), so they are set again every time.
	func refresh() {
		field.attributedPlaceholder = NSAttributedString(
			string: CibulaL10n.tr("Search or type URL", "Поиск или адрес", "Пошук або адреса"),
			attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.55)])

		engineLabel.text = Settings.searchEngine.name
		engineLabel.sizeToFit()
		engineLabel.frame.size.width += 10

		field.rightView = engineLabel
	}

	private func setup() {
		let glass = CapsuleGlassView(effect: cibulaGlassEffect())
		glass.clipsToBounds = true
		glass.layer.cornerCurve = .continuous
		glass.layer.borderWidth = 0.5
		glass.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.35).cgColor
		glass.contentView.backgroundColor = UIColor(red: 0.16, green: 0.05, blue: 0.30, alpha: 0.58)
		glass.translatesAutoresizingMaskIntoConstraints = false
		addSubview(glass)

		let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
		icon.tintColor = lilac
		icon.contentMode = .center
		icon.frame = CGRect(x: 0, y: 0, width: 30, height: 24)

		engineLabel.font = .systemFont(ofSize: 13, weight: .semibold)
		engineLabel.textColor = lilac.withAlphaComponent(0.8)

		field.overrideUserInterfaceStyle = .dark
		field.borderStyle = .none
		field.backgroundColor = .clear
		field.font = .systemFont(ofSize: 17)
		field.textColor = .white
		field.tintColor = lilac
		field.returnKeyType = .go
		field.keyboardType = .webSearch
		field.autocorrectionType = .no
		field.autocapitalizationType = .none
		field.spellCheckingType = .no
		field.clearButtonMode = .whileEditing
		field.leftView = icon
		field.leftViewMode = .always
		field.rightViewMode = .unlessEditing
		field.delegate = self
		field.translatesAutoresizingMaskIntoConstraints = false
		addSubview(field)

		NSLayoutConstraint.activate([
			glass.topAnchor.constraint(equalTo: topAnchor),
			glass.bottomAnchor.constraint(equalTo: bottomAnchor),
			glass.leadingAnchor.constraint(equalTo: leadingAnchor),
			glass.trailingAnchor.constraint(equalTo: trailingAnchor),

			field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
			field.centerYAnchor.constraint(equalTo: centerYAnchor),
			field.heightAnchor.constraint(equalToConstant: 44)
		])

		refresh()
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

		textField.resignFirstResponder()

		if !text.isEmpty {
			textField.text = ""

			onSubmit?(text)
		}

		return true
	}
}


/// A favorite on the start page: round-cornered icon and the name below.
private final class FavoriteCell: UICollectionViewCell {

	static let identifier = "FavoriteCell"

	let icon = UIImageView()
	let label = UILabel()

	override init(frame: CGRect) {
		super.init(frame: frame)

		icon.translatesAutoresizingMaskIntoConstraints = false
		icon.contentMode = .scaleAspectFill
		icon.clipsToBounds = true
		icon.layer.cornerRadius = 17
		icon.layer.cornerCurve = .continuous
		icon.backgroundColor = UIColor.white.withAlphaComponent(0.92)

		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = .systemFont(ofSize: 12)
		label.textColor = UIColor.white.withAlphaComponent(0.86)
		label.textAlignment = .center
		label.lineBreakMode = .byTruncatingTail

		contentView.addSubview(icon)
		contentView.addSubview(label)

		NSLayoutConstraint.activate([
			icon.topAnchor.constraint(equalTo: contentView.topAnchor),
			icon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			icon.widthAnchor.constraint(equalToConstant: 60),
			icon.heightAnchor.constraint(equalToConstant: 60),

			label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 7),
			label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
			label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
			label.heightAnchor.constraint(equalToConstant: 15)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override var isHighlighted: Bool {
		didSet {
			contentView.alpha = isHighlighted ? 0.6 : 1
		}
	}
}


/// The "+" at the end of the favorites. A glass tile with the plus exactly in the middle.
private final class AddFavoriteCell: UICollectionViewCell {

	static let identifier = "AddFavoriteCell"

	override init(frame: CGRect) {
		super.init(frame: frame)

		let glass = UIVisualEffectView(effect: cibulaGlassEffect())
		glass.translatesAutoresizingMaskIntoConstraints = false
		glass.clipsToBounds = true
		glass.layer.cornerRadius = 17
		glass.layer.cornerCurve = .continuous
		glass.layer.borderWidth = 0.5
		glass.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.4).cgColor
		glass.contentView.backgroundColor = UIColor(red: 0.40, green: 0.16, blue: 0.75, alpha: 0.35)

		let plus = UIImageView(image: UIImage(
			systemName: "plus",
			withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)))
		plus.translatesAutoresizingMaskIntoConstraints = false
		plus.tintColor = .white
		plus.contentMode = .center
		glass.contentView.addSubview(plus)

		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.text = CibulaL10n.tr("Add", "Добавить", "Додати")
		label.font = .systemFont(ofSize: 12)
		label.textColor = UIColor.white.withAlphaComponent(0.86)
		label.textAlignment = .center

		contentView.addSubview(glass)
		contentView.addSubview(label)

		NSLayoutConstraint.activate([
			glass.topAnchor.constraint(equalTo: contentView.topAnchor),
			glass.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
			glass.widthAnchor.constraint(equalToConstant: 60),
			glass.heightAnchor.constraint(equalToConstant: 60),

			plus.centerXAnchor.constraint(equalTo: glass.contentView.centerXAnchor),
			plus.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor),

			label.topAnchor.constraint(equalTo: glass.bottomAnchor, constant: 7),
			label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
			label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
			label.heightAnchor.constraint(equalToConstant: 15)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override var isHighlighted: Bool {
		didSet {
			contentView.alpha = isHighlighted ? 0.6 : 1
		}
	}
}


/**
The start page of Cibula, made of native views: the title, the search field, the favorites
(all bookmarks, as many as fit, then "+") and the "Donate" card at the bottom.
It lies over the web view of a tab which shows the start page.
*/
private final class CibulaStartPage: UIView, UICollectionViewDataSource, UICollectionViewDelegate {

	var onSubmitSearch: ((String) -> Void)?
	var onOpen: ((URL) -> Void)?
	var onOpenInNewTab: ((URL) -> Void)?
	var onAdd: (() -> Void)?
	var onEdit: ((Int) -> Void)?
	var onDelete: ((Int) -> Void)?
	var onDonate: (() -> Void)?
	var onCloseDonate: (() -> Void)?

	/// Whether the "Donate" card may be shown at all.
	var donateAvailable = true {
		didSet {
			updateDonate()
		}
	}

	private let titleLabel = UILabel()
	private let search = StartSearchView()
	private let flow = UICollectionViewFlowLayout()
	private lazy var collection = UICollectionView(frame: .zero, collectionViewLayout: flow)
	private let card = UIVisualEffectView(effect: cibulaGlassEffect())

	private var collectionBottomToCard: NSLayoutConstraint?
	private var collectionBottomToSafe: NSLayoutConstraint?

	private var bookmarks: [NcBookmark] {
		NcBookmarks.root.bookmarks
	}

	override class var layerClass: AnyClass {
		CAGradientLayer.self
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		// Four columns, 16 points margin at the sides, 4 points between them.
		let width = floor((bounds.width - 32 - 12) / 4)

		if flow.itemSize.width != width {
			flow.itemSize = CGSize(width: width, height: 82)
			flow.invalidateLayout()
		}
	}

	/// Everything which depends on bookmarks, texts or settings is read again.
	func reload() {
		search.refresh()
		syncSettings()

		collection.reloadData()
	}

	func syncSettings() {
		collection.isHidden = Settings.disableBookmarksOnStartPage
	}


	// MARK: UICollectionViewDataSource

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return bookmarks.count + 1
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let list = bookmarks

		if indexPath.item >= list.count {
			return collectionView.dequeueReusableCell(withReuseIdentifier: AddFavoriteCell.identifier, for: indexPath)
		}

		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FavoriteCell.identifier, for: indexPath)

		if let cell = cell as? FavoriteCell {
			let bookmark = list[indexPath.item]
			let name = bookmark.title.isEmpty ? URL(string: bookmark.url)?.host ?? "" : bookmark.title

			cell.icon.image = NcBookmarks.tileIcon(bookmark.icon, name)
			cell.label.text = name
		}

		return cell
	}


	// MARK: UICollectionViewDelegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		endEditing(true)

		let list = bookmarks

		if indexPath.item >= list.count {
			onAdd?()

			return
		}

		if let url = URL(string: list[indexPath.item].url) {
			onOpen?(url)
		}
	}

	func collectionView(_ collectionView: UICollectionView,
						contextMenuConfigurationForItemAt indexPath: IndexPath,
						point: CGPoint) -> UIContextMenuConfiguration? {

		let list = bookmarks
		let index = indexPath.item

		// The "+" has no menu.
		guard index < list.count, let url = URL(string: list[index].url) else {
			return nil
		}

		return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
			let open = UIAction(
				title: CibulaL10n.tr("Open", "Открыть", "Відкрити"),
				image: UIImage(systemName: "safari")) { _ in
					self?.onOpen?(url)
				}

			let openNew = UIAction(
				title: CibulaL10n.tr("Open in New Tab", "Открыть в новой вкладке", "Відкрити в новій вкладці"),
				image: UIImage(systemName: "plus.square.on.square")) { _ in
					self?.onOpenInNewTab?(url)
				}

			let edit = UIAction(
				title: CibulaL10n.tr("Edit", "Изменить", "Змінити"),
				image: UIImage(systemName: "pencil")) { _ in
					self?.onEdit?(index)
				}

			let delete = UIAction(
				title: CibulaL10n.tr("Delete", "Удалить", "Видалити"),
				image: UIImage(systemName: "trash"),
				attributes: .destructive) { _ in
					self?.onDelete?(index)
				}

			return UIMenu(children: [open, openNew, edit, delete])
		}
	}


	// MARK: Private Methods

	private func setup() {
		overrideUserInterfaceStyle = .dark

		if let gradient = layer as? CAGradientLayer {
			// Solid purple at the top and the bottom, grey in the middle.
			gradient.colors = [UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor,
							   UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor,
							   UIColor(red: 0.15, green: 0.14, blue: 0.18, alpha: 1).cgColor,
							   UIColor(red: 0.14, green: 0.13, blue: 0.16, alpha: 1).cgColor,
							   UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor]
			gradient.locations = [0, 0.26, 0.6, 0.88, 1]
			gradient.startPoint = CGPoint(x: 0.5, y: 0)
			gradient.endPoint = CGPoint(x: 0.5, y: 1)
		}

		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		titleLabel.text = "Cibula"
		titleLabel.font = .systemFont(ofSize: 46, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		search.translatesAutoresizingMaskIntoConstraints = false
		search.onSubmit = { [weak self] text in
			self?.onSubmitSearch?(text)
		}

		flow.scrollDirection = .vertical
		flow.minimumLineSpacing = 20
		flow.minimumInteritemSpacing = 4
		flow.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
		flow.itemSize = CGSize(width: 80, height: 82)

		collection.translatesAutoresizingMaskIntoConstraints = false
		collection.backgroundColor = .clear
		collection.dataSource = self
		collection.delegate = self
		collection.alwaysBounceVertical = false
		collection.showsVerticalScrollIndicator = false
		collection.keyboardDismissMode = .onDrag
		collection.register(FavoriteCell.self, forCellWithReuseIdentifier: FavoriteCell.identifier)
		collection.register(AddFavoriteCell.self, forCellWithReuseIdentifier: AddFavoriteCell.identifier)

		buildCard()

		addSubview(collection)
		addSubview(titleLabel)
		addSubview(search)
		addSubview(card)

		let guide = safeAreaLayoutGuide

		let toCard = collection.bottomAnchor.constraint(equalTo: card.topAnchor, constant: -12)
		let toSafe = collection.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8)

		collectionBottomToCard = toCard
		collectionBottomToSafe = toSafe

		NSLayoutConstraint.activate([
			// 60 points below the top of the page: the title. Then the search field, then the favorites.
			titleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 60),
			titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
			titleLabel.heightAnchor.constraint(equalToConstant: 56),

			search.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
			search.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			search.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			search.heightAnchor.constraint(equalToConstant: 52),

			collection.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 28),
			collection.leadingAnchor.constraint(equalTo: leadingAnchor),
			collection.trailingAnchor.constraint(equalTo: trailingAnchor),

			card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			card.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -14)
		])

		updateDonate()

		// A tap on the background closes the keyboard.
		let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
		tap.cancelsTouchesInView = false
		addGestureRecognizer(tap)
	}

	@objc private func dismissKeyboard() {
		endEditing(true)
	}

	/// The favorites reach down to the "Donate" card, or down to the bottom bar, when the card is gone.
	private func updateDonate() {
		card.isHidden = !donateAvailable

		collectionBottomToCard?.isActive = donateAvailable
		collectionBottomToSafe?.isActive = !donateAvailable

		setNeedsLayout()
	}

	private func buildCard() {
		card.translatesAutoresizingMaskIntoConstraints = false
		card.clipsToBounds = true
		card.layer.cornerRadius = 24
		card.layer.cornerCurve = .continuous
		card.layer.borderWidth = 0.5
		card.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.3).cgColor
		card.contentView.backgroundColor = UIColor(red: 0.16, green: 0.05, blue: 0.30, alpha: 0.45)

		let heart = UIImageView(image: UIImage(
			systemName: "heart.fill",
			withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)))
		heart.translatesAutoresizingMaskIntoConstraints = false
		heart.tintColor = UIColor(red: 1, green: 0.36, blue: 0.54, alpha: 1)
		heart.contentMode = .center

		let title = UILabel()
		title.text = CibulaL10n.tr("Support Cibula", "Поддержать Cibula", "Підтримати Cibula")
		title.font = .systemFont(ofSize: 17, weight: .bold)
		title.textColor = .white

		let text = UILabel()
		text.text = CibulaL10n.tr("Cibula is free. Help it grow.",
								  "Cibula бесплатна. Помогите ей расти.",
								  "Cibula безкоштовна. Допоможіть їй рости.")
		text.font = .systemFont(ofSize: 14)
		text.textColor = UIColor.white.withAlphaComponent(0.7)
		text.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [title, text])
		texts.translatesAutoresizingMaskIntoConstraints = false
		texts.axis = .vertical
		texts.spacing = 3

		var closeConfig = UIButton.Configuration.plain()
		closeConfig.image = UIImage(
			systemName: "xmark",
			withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
		closeConfig.baseForegroundColor = UIColor.white.withAlphaComponent(0.85)

		let close = UIButton(configuration: closeConfig, primaryAction: UIAction { [weak self] _ in
			self?.onCloseDonate?()
		})
		close.translatesAutoresizingMaskIntoConstraints = false
		close.backgroundColor = UIColor.white.withAlphaComponent(0.12)
		close.layer.cornerRadius = 15

		var donateConfig = UIButton.Configuration.filled()
		donateConfig.title = CibulaL10n.tr("Donate", "Пожертвовать", "Пожертвувати")
		donateConfig.baseBackgroundColor = UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1)
		donateConfig.baseForegroundColor = .white
		donateConfig.cornerStyle = .large
		donateConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
			var outgoing = incoming
			outgoing.font = .systemFont(ofSize: 17, weight: .bold)
			return outgoing
		}

		let donate = UIButton(configuration: donateConfig, primaryAction: UIAction { [weak self] _ in
			self?.onDonate?()
		})
		donate.translatesAutoresizingMaskIntoConstraints = false

		let content = card.contentView

		content.addSubview(heart)
		content.addSubview(texts)
		content.addSubview(close)
		content.addSubview(donate)

		NSLayoutConstraint.activate([
			heart.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
			heart.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
			heart.widthAnchor.constraint(equalToConstant: 30),
			heart.heightAnchor.constraint(equalToConstant: 30),

			close.topAnchor.constraint(equalTo: content.topAnchor, constant: 10),
			close.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
			close.widthAnchor.constraint(equalToConstant: 30),
			close.heightAnchor.constraint(equalToConstant: 30),

			texts.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
			texts.leadingAnchor.constraint(equalTo: heart.trailingAnchor, constant: 14),
			texts.trailingAnchor.constraint(equalTo: close.leadingAnchor, constant: -8),

			donate.topAnchor.constraint(equalTo: texts.bottomAnchor, constant: 14),
			donate.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
			donate.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
			donate.heightAnchor.constraint(equalToConstant: 48),
			donate.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
		])
	}
}

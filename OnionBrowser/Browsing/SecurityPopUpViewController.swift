//
//  SecurityPopUpViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 13.12.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SecurityPopUpViewController: UIViewController, UIPopoverPresentationControllerDelegate,
UITableViewDataSource, UITableViewDelegate {

	var host: String?

	/// The blue of the buttons.
	private static let blue = UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1)

	private static let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = host != nil
				? CibulaL10n.tr("Security Level for This Site", "Уровень защиты для сайта", "Рівень захисту для сайту")
				: CibulaL10n.tr("Default Security", "Защита по умолчанию", "Захист за замовчуванням")
		}
	}

	@IBOutlet weak var tableView: UITableView!

	@IBOutlet weak var customizeBt: UIButton! {
		didSet {
			customizeBt.setTitle(CibulaL10n.tr("Customize", "Настроить", "Налаштувати"))
		}
	}

	@IBOutlet weak var learnMoreBt: UIButton! {
		didSet {
			learnMoreBt.setTitle(CibulaL10n.tr("Learn More", "Подробнее", "Докладніше"))
		}
	}


	override var preferredContentSize: CGSize {
		get {
			// The rows are cards now, they need a little more room.
			return CGSize(width: 300, height: 350 + (current == .custom ? SecurityLevelCell.height : 0))
		}
		set {
			// Ignore.
		}
	}

	private var presets: [SecurityPreset] = [.secure, .medium, .insecure]

	private lazy var current = SecurityPreset(HostSettings.for(host))

	private lazy var hostSettings: HostSettings = {
		guard let host = host, !host.isEmpty else {
			return HostSettings.forDefault()
		}

		return HostSettings.for(host)
	}()

	private var changeObserver: Any?

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark

		styleForCibula()

		if current == .custom {
			presets.append(.custom)
		}

		tableView.register(SecurityLevelCell.nib, forCellReuseIdentifier: SecurityLevelCell.reuseId)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Purple glass, like the bars of the browser.
		popoverPresentationController?.backgroundColor = UIColor(red: 0.17, green: 0.07, blue: 0.34, alpha: 0.96)

		if let row = presets.firstIndex(of: current) {
			tableView.selectRow(at: IndexPath(row: row, section: 0), animated: animated, scrollPosition: .none)
		}

		// Dismiss ourselves if the user changed something in SecurityViewController.
		changeObserver = NotificationCenter.default.addObserver(
			forName: .hostSettingsChanged, object: nil, queue: .main)
		{ notification in
			let host = notification.object as? String

			// Hide on default changes and specific changes for this host.
			if (host == nil || host == self.host)
				&& self.current != SecurityPreset(HostSettings.for(host)) {

				self.dismiss(animated: true)
			}
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		if let changeObserver = changeObserver {
			NotificationCenter.default.removeObserver(changeObserver)
			self.changeObserver = nil
		}
	}


	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return presets.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: SecurityLevelCell.reuseId, for: indexPath)
			as! SecurityLevelCell

		return cell.set(presets[indexPath.row])
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return SecurityLevelCell.height
	}

	func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
		// Don't do anything when the already selected row was selected again.
		if let selected = tableView.indexPathForSelectedRow?.row,
			indexPath.row == selected {
			return indexPath
		}

		current = presets[indexPath.row]

		let values = current.values
		hostSettings.javaScript = values?.javaScript ?? false
		hostSettings.lockdownMode = values?.lockdownMode ?? false
		hostSettings.orientationAndMotion = values?.orientationAndMotion ?? false
		hostSettings.mediaCapture = values?.mediaCapture ?? false

		// Trigger creation, save and store of HostSettings for this host.
		hostSettings.save().store()

		dismiss(animated: true)

		return indexPath
	}


	// MARK: UIPopoverPresentationControllerDelegate

	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: Actions

	@IBAction func customize() {
		// Trigger creation, save and store of HostSettings for this host.
		hostSettings.save().store()

		AppDelegate.shared?.dismissModals(of: SecurityViewController.self)

		let vc = SecurityViewController()
		vc.host = host

		present(UINavigationController(rootViewController: vc))
	}

	@IBAction func learnMore() {
		view.sceneDelegate?.browsingUi.addNewTab(URL.aboutSecurityLevels)

		dismiss(animated: true)
	}


	// MARK: Private Methods

	/// White texts, blue buttons, glass instead of white.
	private func styleForCibula() {
		view.backgroundColor = .clear
		tableView.backgroundColor = .clear

		headerLb.textColor = .white
		headerLb.font = .systemFont(ofSize: 17, weight: .bold)

		customizeBt.backgroundColor = Self.blue
		customizeBt.setTitleColor(.white, for: .normal)
		customizeBt.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
		customizeBt.titleLabel?.adjustsFontSizeToFitWidth = true
		customizeBt.titleLabel?.minimumScaleFactor = 0.7
		customizeBt.layer.cornerRadius = 18
		customizeBt.layer.cornerCurve = .continuous

		learnMoreBt.setTitleColor(Self.lilac, for: .normal)
	}
}

//
//  SettingsViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import CoreImage
import Eureka

class SettingsViewController: FixedFormViewController {

	private let defaultSecurityRow = LabelRow() {
		$0.title = NSLocalizedString("Default Security", comment: "Option title")
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}

	private let searchEngineRow = LabelRow() {
		$0.title = NSLocalizedString("Search Engine", comment: "Option title")
		$0.value = Settings.searchEngine.name
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}


	@objc
	class func instantiate() -> UINavigationController {
		return UINavigationController(rootViewController: self.init())
	}

	override func viewDidLoad() {
		// The base class (FixedFormViewController) makes the table rounded and purple.
		super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: CibulaL10n.tr("Done", "Готово", "Готово"),
			style: .done, target: self, action: #selector(dismsiss_))
		navigationItem.title = NSLocalizedString("Settings", comment: "Scene title")

		form
		+++ Section(header: CibulaL10n.tr("Language", "Язык", "Мова"),
					footer: CibulaL10n.tr("Takes effect after restarting the app.",
										  "Вступит в силу после перезапуска приложения.",
										  "Набуде чинності після перезапуску застосунку."))

		<<< PushRow<String>() {
			$0.title = CibulaL10n.tr("App Language", "Язык приложения", "Мова застосунку")
			$0.selectorTitle = $0.title
			$0.options = ["system", "en", "ru", "uk"]
			$0.value = CibulaL10n.chosen
			$0.displayValueFor = { code in
				CibulaL10n.languageName(code ?? "system")
			}
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			let code = row.value ?? "system"

			if code == CibulaL10n.chosen {
				return
			}

			CibulaL10n.choose(code)

			if let self {
				CibulaTheme.presentRestartAlert(on: self)
			}
		}

		form
		+++ defaultSecurityRow
		.onCellSelection { [weak self] _, _ in
			self?.showDefaultSecurity()
		}

		+++ Section(header: NSLocalizedString("Search", comment: "Section header"),
					footer: NSLocalizedString("When disabled, all text entered in search bar will be sent to the search engine unless it starts with \"http\".",
											  comment: "Explanation in section footer"))

		<<< searchEngineRow
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(SearchEnginesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Auto-Complete Search Results", comment: "Option title")
			$0.value = Settings.searchLive
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLive = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Stop Auto-Complete at First Dot", comment: "Option title")
			$0.value = Settings.searchLiveStopDot
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLiveStopDot = value
			}
		}

		+++ Section(header: NSLocalizedString("Privacy & Security", comment: "Section header"),
					footer: NSLocalizedString("Choose how long app remembers open tabs.", comment: "Explanation in section footer"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("Custom Site Security", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CustomSitesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Tell websites that you object to processing and selling of your personal data", comment: "Option title")
			$0.value = Settings.sendGpc
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.sendGpc = value
			}
		}

		<<< LabelRow() {
			$0.title = NSLocalizedString("Cookies and Local Storage", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(
				Storage1ViewController(), animated: true)
		}

		<<< SwitchRow() {
			switch SecureEnclave.biometryType() {
			case .touchID:
				$0.title = NSLocalizedString("Lock App with Touch ID or Device Passcode", comment: "")

			case .faceID:
				$0.title = NSLocalizedString("Lock App with Face ID or Device Passcode", comment: "")

			default:
				$0.title = NSLocalizedString("Lock App with Device Passcode", comment: "")
			}

			$0.value = SecureEnclave.loadKey() != nil
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			let newValue: Bool

			if row.value ?? false {
				newValue = SecureEnclave.createKey() != nil
			}
			else {
				newValue = !SecureEnclave.removeKey()
			}

			// Seems, we can't create a key. Maybe running on a simulator?
			if newValue != row.value {
				// Quirky way of disabling the onChange callback to avoid an endless loop.
				self?.form.delegate = nil

				row.value = newValue
				row.updateCell()

				row.disabled = true
				row.evaluateDisabled()

				self?.form.delegate = self // Enable callback again.
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Hide App Content when in Background", comment: "")
			$0.value = Settings.hideContent
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			Settings.hideContent = row.value ?? false
		})

		<<< PushRow<TabSecurityLevel>() {
			$0.title = NSLocalizedString("Tab Security", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = [TabSecurityLevel.alwaysRemember,
						  TabSecurityLevel.forgetOnShutdown,
						  TabSecurityLevel.clearOnBackground]

			$0.value = Settings.tabSecurity

			$0.cell.textLabel?.numberOfLines = 0
		}
		.onPresent { vc, selectorVc in
			// This is just to trigger the usage of #sectionFooterTitleForKey
			selectorVc.sectionKeyForValue = { value in
				return NSLocalizedString("Tab Security", comment: "Option title")
			}

			selectorVc.sectionFooterTitleForKey = { key in
				return NSLocalizedString("Choose how long app remembers open tabs.", comment: "")
			}
		}
		.onChange { row in
			if let value = row.value {
				Settings.tabSecurity = value
			}
		}

		+++ Section(header: NSLocalizedString("Miscellaneous", comment: "Section header"),
					footer: NSLocalizedString("Changing this option requires restarting the app.",
											  comment: "Option explanation"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("URL Blocker", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(BlocklistViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Mute Audio with Mute Switch", comment: "Option title")
			$0.value = Settings.muteWithSwitch
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.muteWithSwitch = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Disable Bookmarks on Start Page", comment: "Option title")
			$0.value = Settings.disableBookmarksOnStartPage
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			if let value = row.value, value != Settings.disableBookmarksOnStartPage {
				Settings.disableBookmarksOnStartPage = value

				NcBookmarks.updateStartPage(force: true)

				for tab in AppDelegate.shared?.allOpenTabs ?? [] {
					if tab.url == URL.start {
						tab.refresh()
					}
				}
			}
		})

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow 3rd-Party Keyboards", comment: "Option title")
			$0.value = Settings.thirdPartyKeyboards
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.thirdPartyKeyboards = value
			}
		}

		<<< SwitchRow() {
			$0.title = CibulaL10n.tr("Merge bars like Safari",
									 "Объединить панели, как в Safari",
									 "Об'єднати панелі, як у Safari")
			$0.value = UserDefaults.standard.bool(forKey: BrowsingViewController.mergedBarsKey)
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			let value = row.value ?? false

			if value == UserDefaults.standard.bool(forKey: BrowsingViewController.mergedBarsKey) {
				return
			}

			UserDefaults.standard.set(value, forKey: BrowsingViewController.mergedBarsKey)

			if let self {
				CibulaTheme.presentRestartAlert(on: self)
			}
		}

		// Last section: About, Donate, Telegram and the version. No header.
		form
		+++ Section(header: "",
					footer: String(
						format: NSLocalizedString("Version %@", comment: "Version info at end of scene"),
						Bundle.main.version))

		<<< ButtonRow() {
			$0.title = NSLocalizedString("About", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
			cell.imageView?.image = UIImage(systemName: "info.circle")
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CibulaAboutViewController(), animated: true)
		}

		<<< ButtonRow() {
			$0.title = CibulaL10n.tr("Donate", "Пожертвовать", "Пожертвувати")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
			cell.imageView?.image = UIImage(systemName: "heart.fill")
			cell.imageView?.tintColor = UIColor(red: 1, green: 0.36, blue: 0.54, alpha: 1)
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CibulaDonateViewController(), animated: true)
		}

		<<< ButtonRow() {
			$0.title = "Telegram"
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
			cell.imageView?.image = UIImage(systemName: "paperplane.fill")
		}
		.onCellSelection { _, _ in
			if let url = URL(string: "https://t.me/CibulaOnionBrowser") {
				UIApplication.shared.open(url)
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		defaultSecurityRow.value = SecurityPreset(HostSettings.forDefault()).description
		defaultSecurityRow.updateCell()

		searchEngineRow.value = Settings.searchEngine.name
		searchEngineRow.updateCell()
	}


	func showDefaultSecurity() {
		AppDelegate.shared?.dismissModals(of: SecurityViewController.self)

		navigationController?.pushViewController(
			SecurityViewController(), animated: true)
	}

	@objc private func dismsiss_() {
		navigationController?.dismiss(animated: true)
	}
}


// MARK: - About screen

class CibulaAboutViewController: UIViewController {

	private let gradient = CAGradientLayer()

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark
		title = CibulaL10n.tr("About", "О приложении", "Про застосунок")

		gradient.colors = [UIColor(red: 0.05, green: 0.00, blue: 0.10, alpha: 1).cgColor,
						   UIColor(red: 0.11, green: 0.04, blue: 0.22, alpha: 1).cgColor,
						   UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		// The name of the original project is built from pieces, so the build script doesn't rename it.
		let original = "Onion" + " " + "Browser"

		let rings = CibulaRingsView()
		rings.translatesAutoresizingMaskIntoConstraints = false
		rings.widthAnchor.constraint(equalToConstant: 120).isActive = true
		rings.heightAnchor.constraint(equalToConstant: 120).isActive = true

		let titleLabel = UILabel()
		titleLabel.text = "Cibula"
		titleLabel.font = .systemFont(ofSize: 34, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		let versionLabel = UILabel()
		versionLabel.text = CibulaL10n.tr("Version", "Версия", "Версія") + " " + Bundle.main.version
		versionLabel.font = .systemFont(ofSize: 15, weight: .medium)
		versionLabel.textColor = UIColor.white.withAlphaComponent(0.6)
		versionLabel.textAlignment = .center

		let tagline = UILabel()
		tagline.text = CibulaL10n.tr(
			"A private browser built on Tor: layer by layer, no traces.",
			"Приватный браузер на базе Tor: слой за слоем, без следов.",
			"Приватний браузер на базі Tor: шар за шаром, без слідів.")
		tagline.font = .systemFont(ofSize: 17, weight: .semibold)
		tagline.textColor = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)
		tagline.textAlignment = .center
		tagline.numberOfLines = 0

		let footer = UILabel()
		footer.text = CibulaL10n.tr(
			"Based on the open source project \(original).",
			"Основано на открытом проекте \(original).",
			"Засновано на відкритому проєкті \(original).")
		footer.font = .systemFont(ofSize: 13)
		footer.textColor = UIColor.white.withAlphaComponent(0.5)
		footer.textAlignment = .center
		footer.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [
			rings, titleLabel, versionLabel, tagline,
			card("gift.fill",
				 CibulaL10n.tr("Completely free", "Абсолютно бесплатно", "Абсолютно безкоштовно"),
				 CibulaL10n.tr("No subscriptions, no ads and no hidden payments. Cibula is a free fork of \(original).",
							   "Никаких подписок, рекламы и скрытых платежей. Cibula — свободный форк \(original).",
							   "Жодних підписок, реклами та прихованих платежів. Cibula — вільний форк \(original).")),
			card("paintpalette.fill",
				 CibulaL10n.tr("Own look", "Свой вид", "Власний вигляд"),
				 CibulaL10n.tr("Deep purple theme, glass bars and Safari-style tabs.",
							   "Тёмно-фиолетовая тема, стеклянные панели и вкладки в стиле Safari.",
							   "Темно-фіолетова тема, скляні панелі та вкладки в стилі Safari.")),
			card("shield.lefthalf.filled",
				 CibulaL10n.tr("Only what matters", "Ничего лишнего", "Нічого зайвого"),
				 CibulaL10n.tr("All traffic goes through the built-in Tor, without extra setup.",
							   "Весь трафик идёт через встроенный Tor, без дополнительных настроек.",
							   "Увесь трафік іде через вбудований Tor, без додаткових налаштувань.")),
			footer])
		stack.axis = .vertical
		stack.spacing = 14
		stack.setCustomSpacing(10, after: rings)
		stack.setCustomSpacing(4, after: titleLabel)
		stack.setCustomSpacing(18, after: tagline)
		stack.setCustomSpacing(22, after: stack.arrangedSubviews[6])
		stack.translatesAutoresizingMaskIntoConstraints = false

		let scroll = UIScrollView()
		scroll.translatesAutoresizingMaskIntoConstraints = false
		scroll.alwaysBounceVertical = true
		scroll.addSubview(stack)
		view.addSubview(scroll)

		NSLayoutConstraint.activate([
			scroll.topAnchor.constraint(equalTo: view.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
			stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
			stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
		])
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}

	private func card(_ symbol: String, _ title: String, _ text: String) -> UIView {
		let panel = UIView()
		panel.backgroundColor = UIColor.white.withAlphaComponent(0.07)
		panel.layer.cornerRadius = 20
		panel.layer.cornerCurve = .continuous
		panel.layer.borderWidth = 0.5
		panel.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.25).cgColor

		let icon = UIImageView(image: UIImage(systemName: symbol))
		icon.tintColor = UIColor(red: 0.77, green: 0.55, blue: 1, alpha: 1)
		icon.contentMode = .scaleAspectFit
		icon.translatesAutoresizingMaskIntoConstraints = false
		icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
		icon.heightAnchor.constraint(equalToConstant: 30).isActive = true

		let titleLabel = UILabel()
		titleLabel.text = title
		titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
		titleLabel.textColor = .white
		titleLabel.numberOfLines = 0

		let textLabel = UILabel()
		textLabel.text = text
		textLabel.font = .systemFont(ofSize: 15)
		textLabel.textColor = UIColor.white.withAlphaComponent(0.7)
		textLabel.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [titleLabel, textLabel])
		texts.axis = .vertical
		texts.spacing = 4

		let row = UIStackView(arrangedSubviews: [icon, texts])
		row.axis = .horizontal
		row.alignment = .top
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		panel.addSubview(row)

		NSLayoutConstraint.activate([
			row.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
			row.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
			row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16)
		])

		return panel
	}
}


// MARK: - Donation screen

/**
Choose a coin and a network, then scan the QR code or copy the address.
Works inside a navigation controller: pushed by the settings, or as the first screen of its own
navigation controller (then it brings its own "Done" button).
*/
class CibulaDonateViewController: UIViewController {

	/// Check every character against your own wallet before you publish a build!
	/// One address of this kind works on all Ethereum compatible networks.
	private static let evm = "0xa4313D499F956515e718B459c58bBebf60b08C39"
	private static let tron = "TSTNwZH79uAu7CPRDrmxF8frKkWVrihgF2"

	private struct Network {
		let name: String
		let icon: String
		let address: String
	}

	private struct Coin {
		let name: String
		let icon: String
		let networks: [Network]
	}

	private static let coins: [Coin] = [
		Coin(name: "USDT", icon: "usdt", networks: [
			Network(name: "Tron (TRC-20)", icon: "tron", address: CibulaDonateViewController.tron),
			Network(name: "Ethereum (ERC-20)", icon: "ethereum", address: CibulaDonateViewController.evm),
			Network(name: "BNB Smart Chain (BEP-20)", icon: "bnb", address: CibulaDonateViewController.evm)]),
		Coin(name: "USDC", icon: "usdc", networks: [
			Network(name: "Ethereum (ERC-20)", icon: "ethereum", address: CibulaDonateViewController.evm),
			Network(name: "Polygon", icon: "polygon", address: CibulaDonateViewController.evm),
			Network(name: "Arbitrum", icon: "arbitrum", address: CibulaDonateViewController.evm)])
	]

	private var coinIndex = 0
	private var networkIndex = 0

	private var coin: Coin {
		Self.coins[coinIndex]
	}

	private var network: Network {
		coin.networks[networkIndex]
	}

	private let gradient = CAGradientLayer()
	private let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)

	private let coinBadge = UIImageView()
	private let coinValue = UILabel()
	private let coinButton = UIButton(type: .system)

	private let networkBadge = UIImageView()
	private let networkValue = UILabel()
	private let networkButton = UIButton(type: .system)

	private let qrView = UIImageView()
	private let qrBadge = UIImageView()

	private let addressLabel = UILabel()
	private let copyIcon = UIImageView(image: UIImage(systemName: "doc.on.doc"))

	private let warning = UILabel()


	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark
		title = CibulaL10n.tr("Support Cibula", "Поддержать Cibula", "Підтримати Cibula")

		gradient.colors = [UIColor(red: 0.05, green: 0.00, blue: 0.10, alpha: 1).cgColor,
						   UIColor(red: 0.11, green: 0.04, blue: 0.22, alpha: 1).cgColor,
						   UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		// Opened on its own (from the start page): there is no "back", so there is a button to leave.
		if navigationController?.viewControllers.first === self {
			navigationItem.leftBarButtonItem = UIBarButtonItem(
				title: CibulaL10n.tr("Done", "Готово", "Готово"),
				style: .done, target: self, action: #selector(close))
		}

		let info = UILabel()
		info.text = CibulaL10n.tr(
			"Cibula is free. If you like it, you can support its development with a stablecoin.",
			"Cibula бесплатна. Если она вам нравится, вы можете поддержать её развитие стейблкоином.",
			"Cibula безкоштовна. Якщо вона вам подобається, ви можете підтримати її розвиток стейблкоїном.")
		info.font = .systemFont(ofSize: 16)
		info.textColor = UIColor.white.withAlphaComponent(0.75)
		info.numberOfLines = 0

		// The choice opens as a sheet from the bottom. (A menu made a square flash up behind the glass panel.)
		coinButton.addTarget(self, action: #selector(chooseCoin), for: .touchUpInside)
		networkButton.addTarget(self, action: #selector(chooseNetwork), for: .touchUpInside)

		let coinPanel = pickerPanel(badge: coinBadge,
									caption: CibulaL10n.tr("Coin", "Монета", "Монета"),
									value: coinValue, button: coinButton)

		let networkPanel = pickerPanel(badge: networkBadge,
									   caption: CibulaL10n.tr("Network", "Сеть", "Мережа"),
									   value: networkValue, button: networkButton)

		warning.font = .systemFont(ofSize: 14, weight: .medium)
		warning.textColor = UIColor(red: 1, green: 0.78, blue: 0.45, alpha: 1)
		warning.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [info, coinPanel, networkPanel, qrPanel(), addressPanel(), warning])
		stack.axis = .vertical
		stack.spacing = 14
		stack.translatesAutoresizingMaskIntoConstraints = false

		let scroll = UIScrollView()
		scroll.translatesAutoresizingMaskIntoConstraints = false
		scroll.alwaysBounceVertical = true
		scroll.addSubview(stack)
		view.addSubview(scroll)

		NSLayoutConstraint.activate([
			scroll.topAnchor.constraint(equalTo: view.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
			stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
			stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20)
		])

		refresh()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}


	// MARK: Actions

	@objc private func close() {
		dismiss(animated: true)
	}

	@objc private func copyAddress() {
		UIPasteboard.general.string = network.address

		UINotificationFeedbackGenerator().notificationOccurred(.success)

		copyIcon.image = UIImage(systemName: "checkmark")

		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
			self?.copyIcon.image = UIImage(systemName: "doc.on.doc")
		}
	}


	// MARK: Private Methods

	/// Shows the chosen coin and network everywhere and builds the two menus again.
	private func refresh() {
		coinBadge.image = CibulaCoinIcons.image(for: coin.icon)
		coinValue.text = coin.name

		networkBadge.image = CibulaCoinIcons.image(for: network.icon)
		networkValue.text = network.name

		qrView.image = qrImage(network.address)
		qrBadge.image = CibulaCoinIcons.image(for: coin.icon)

		addressLabel.text = network.address

		let coinName = coin.name
		let networkName = network.name

		warning.text = CibulaL10n.tr(
			"Send only \(coinName) on the \(networkName) network. Anything else will be lost.",
			"Отправляйте только \(coinName) в сети \(networkName). Всё остальное будет потеряно.",
			"Надсилайте лише \(coinName) у мережі \(networkName). Усе інше буде втрачено.")

	}

	@objc private func chooseCoin() {
		let sheet = UIAlertController(
			title: CibulaL10n.tr("Coin", "Монета", "Монета"), message: nil, preferredStyle: .actionSheet)
		sheet.overrideUserInterfaceStyle = .dark

		for (index, item) in Self.coins.enumerated() {
			let action = UIAlertAction(title: item.name, style: .default) { [weak self] _ in
				self?.coinIndex = index
				self?.networkIndex = 0
				self?.refresh()
			}

			// A check mark at the chosen one.
			action.setValue(index == coinIndex, forKey: "checked")

			sheet.addAction(action)
		}

		sheet.addAction(UIAlertAction(title: CibulaL10n.tr("Cancel", "Отмена", "Скасувати"), style: .cancel))

		sheet.popoverPresentationController?.sourceView = coinButton
		sheet.popoverPresentationController?.sourceRect = coinButton.bounds

		present(sheet, animated: true)
	}

	@objc private func chooseNetwork() {
		let sheet = UIAlertController(
			title: CibulaL10n.tr("Network", "Сеть", "Мережа"), message: nil, preferredStyle: .actionSheet)
		sheet.overrideUserInterfaceStyle = .dark

		for (index, item) in coin.networks.enumerated() {
			let action = UIAlertAction(title: item.name, style: .default) { [weak self] _ in
				self?.networkIndex = index
				self?.refresh()
			}

			action.setValue(index == networkIndex, forKey: "checked")

			sheet.addAction(action)
		}

		sheet.addAction(UIAlertAction(title: CibulaL10n.tr("Cancel", "Отмена", "Скасувати"), style: .cancel))

		sheet.popoverPresentationController?.sourceView = networkButton
		sheet.popoverPresentationController?.sourceRect = networkButton.bounds

		present(sheet, animated: true)
	}

	private func color(_ hex: UInt32) -> UIColor {
		UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
				green: CGFloat((hex >> 8) & 0xFF) / 255,
				blue: CGFloat(hex & 0xFF) / 255,
				alpha: 1)
	}

	private func glassPanel() -> UIVisualEffectView {
		let effect: UIVisualEffect

		if #available(iOS 26.0, *) {
			effect = UIGlassEffect()
		}
		else {
			effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
		}

		let panel = UIVisualEffectView(effect: effect)
		panel.clipsToBounds = true
		panel.layer.cornerRadius = 22
		panel.layer.cornerCurve = .continuous
		panel.layer.borderWidth = 0.5
		panel.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.3).cgColor
		panel.contentView.backgroundColor = UIColor(red: 0.16, green: 0.05, blue: 0.30, alpha: 0.45)

		return panel
	}

	/// A panel with a round badge, a small caption and the chosen value. A tap opens a menu.
	private func pickerPanel(badge: UIImageView, caption: String, value: UILabel, button: UIButton) -> UIView {
		let panel = glassPanel()

		badge.contentMode = .scaleAspectFit
		badge.translatesAutoresizingMaskIntoConstraints = false
		badge.widthAnchor.constraint(equalToConstant: 44).isActive = true
		badge.heightAnchor.constraint(equalToConstant: 44).isActive = true

		let captionLabel = UILabel()
		captionLabel.text = caption
		captionLabel.font = .systemFont(ofSize: 13, weight: .medium)
		captionLabel.textColor = lilac.withAlphaComponent(0.8)

		value.font = .systemFont(ofSize: 19, weight: .bold)
		value.textColor = .white
		value.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [captionLabel, value])
		texts.axis = .vertical
		texts.spacing = 2

		let chevron = UIImageView(image: UIImage(systemName: "chevron.up.chevron.down"))
		chevron.tintColor = lilac
		chevron.contentMode = .scaleAspectFit
		chevron.setContentHuggingPriority(.required, for: .horizontal)

		let row = UIStackView(arrangedSubviews: [badge, texts, chevron])
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		panel.contentView.addSubview(row)

		// The button has the shape of the panel, so the menu doesn't show a square behind it.
		button.translatesAutoresizingMaskIntoConstraints = false
		button.backgroundColor = .clear
		button.layer.cornerRadius = 22
		button.layer.cornerCurve = .continuous
		button.clipsToBounds = true
		panel.contentView.addSubview(button)

		NSLayoutConstraint.activate([
			row.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
			row.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -14),
			row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -16),

			button.topAnchor.constraint(equalTo: panel.contentView.topAnchor),
			button.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor),
			button.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor),
			button.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor)
		])

		return panel
	}

	/// White square with the QR code and the badge of the coin in the middle.
	private func qrPanel() -> UIView {
		let holder = UIView()

		let white = UIView()
		white.backgroundColor = .white
		white.layer.cornerRadius = 22
		white.layer.cornerCurve = .continuous
		white.translatesAutoresizingMaskIntoConstraints = false
		holder.addSubview(white)

		qrView.contentMode = .scaleAspectFit
		qrView.layer.magnificationFilter = .nearest
		qrView.translatesAutoresizingMaskIntoConstraints = false
		white.addSubview(qrView)

		let badgeRing = UIView()
		badgeRing.backgroundColor = .white
		badgeRing.layer.cornerRadius = 25
		badgeRing.translatesAutoresizingMaskIntoConstraints = false
		white.addSubview(badgeRing)

		qrBadge.contentMode = .scaleAspectFit
		qrBadge.translatesAutoresizingMaskIntoConstraints = false
		badgeRing.addSubview(qrBadge)

		NSLayoutConstraint.activate([
			white.topAnchor.constraint(equalTo: holder.topAnchor),
			white.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
			white.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
			white.widthAnchor.constraint(equalToConstant: 244),
			white.heightAnchor.constraint(equalToConstant: 244),

			qrView.topAnchor.constraint(equalTo: white.topAnchor, constant: 14),
			qrView.bottomAnchor.constraint(equalTo: white.bottomAnchor, constant: -14),
			qrView.leadingAnchor.constraint(equalTo: white.leadingAnchor, constant: 14),
			qrView.trailingAnchor.constraint(equalTo: white.trailingAnchor, constant: -14),

			badgeRing.centerXAnchor.constraint(equalTo: white.centerXAnchor),
			badgeRing.centerYAnchor.constraint(equalTo: white.centerYAnchor),
			badgeRing.widthAnchor.constraint(equalToConstant: 50),
			badgeRing.heightAnchor.constraint(equalToConstant: 50),

			qrBadge.centerXAnchor.constraint(equalTo: badgeRing.centerXAnchor),
			qrBadge.centerYAnchor.constraint(equalTo: badgeRing.centerYAnchor),
			qrBadge.widthAnchor.constraint(equalToConstant: 42),
			qrBadge.heightAnchor.constraint(equalToConstant: 42)
		])

		return holder
	}

	/// The address. A tap on the panel copies it.
	private func addressPanel() -> UIView {
		let panel = glassPanel()

		let captionLabel = UILabel()
		captionLabel.text = CibulaL10n.tr("Address", "Адрес", "Адреса")
		captionLabel.font = .systemFont(ofSize: 13, weight: .medium)
		captionLabel.textColor = lilac.withAlphaComponent(0.8)

		addressLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
		addressLabel.textColor = .white
		addressLabel.numberOfLines = 0
		addressLabel.lineBreakMode = .byCharWrapping

		let texts = UIStackView(arrangedSubviews: [captionLabel, addressLabel])
		texts.axis = .vertical
		texts.spacing = 4

		copyIcon.tintColor = lilac
		copyIcon.contentMode = .scaleAspectFit
		copyIcon.setContentHuggingPriority(.required, for: .horizontal)
		copyIcon.translatesAutoresizingMaskIntoConstraints = false
		copyIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true

		let row = UIStackView(arrangedSubviews: [texts, copyIcon])
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 12
		row.translatesAutoresizingMaskIntoConstraints = false
		panel.contentView.addSubview(row)

		NSLayoutConstraint.activate([
			row.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
			row.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -14),
			row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -16)
		])

		panel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyAddress)))

		return panel
	}

	private func qrImage(_ text: String) -> UIImage? {
		guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
			return nil
		}

		filter.setValue(Data(text.utf8), forKey: "inputMessage")

		// The highest error correction, because the badge covers the middle.
		filter.setValue("H", forKey: "inputCorrectionLevel")

		guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
			  let cgImage = CIContext().createCGImage(output, from: output.extent)
		else {
			return nil
		}

		return UIImage(cgImage: cgImage)
	}
}


/// The logo of the app: rings getting fainter outwards around a purple core.
private class CibulaRingsView: UIView {

	override init(frame: CGRect) {
		super.init(frame: frame)

		backgroundColor = .clear
		isOpaque = false
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		backgroundColor = .clear
		isOpaque = false
	}

	override func draw(_ rect: CGRect) {
		let center = CGPoint(x: bounds.midX, y: bounds.midY)
		let maxRadius = min(bounds.width, bounds.height) / 2 - 4

		let factors: [CGFloat] = [1, 0.78, 0.56, 0.35]
		let alphas: [CGFloat] = [0.35, 0.55, 0.8, 1]

		for (index, factor) in factors.enumerated() {
			let path = UIBezierPath(arcCenter: center, radius: maxRadius * factor,
									startAngle: 0, endAngle: .pi * 2, clockwise: true)
			path.lineWidth = maxRadius * 0.07

			UIColor(red: 0.77, green: 0.55, blue: 1, alpha: alphas[index]).setStroke()
			path.stroke()
		}

		let core = maxRadius * 0.16

		UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1).setFill()
		UIBezierPath(ovalIn: CGRect(x: center.x - core, y: center.y - core,
									width: core * 2, height: core * 2)).fill()
	}
}


/// Logos of the coins and networks (96 px PNG, base64), so they look right without network.
private enum CibulaCoinIcons {

	static func image(for key: String) -> UIImage? {
		if key == "tron" {
			return tron
		}

		guard let text = data[key], let bytes = Data(base64Encoded: text) else {
			return nil
		}

		return UIImage(data: bytes)
	}

	/// Tron has no picture of its own here: red circle with a white triangle mark.
	private static let tron: UIImage = {
		let size = CGSize(width: 96, height: 96)

		return UIGraphicsImageRenderer(size: size).image { _ in
			UIColor(red: 0.92, green: 0.0, blue: 0.16, alpha: 1).setFill()
			UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()

			let top = CGPoint(x: 28, y: 29)
			let right = CGPoint(x: 69, y: 37)
			let bottom = CGPoint(x: 49, y: 71)

			let outline = UIBezierPath()
			outline.move(to: top)
			outline.addLine(to: right)
			outline.addLine(to: bottom)
			outline.close()
			outline.lineWidth = 5
			outline.lineJoinStyle = .round
			UIColor.white.setStroke()
			outline.stroke()

			let inner = UIBezierPath()
			inner.move(to: top)
			inner.addLine(to: CGPoint(x: 55, y: 45))
			inner.addLine(to: right)
			inner.lineWidth = 4
			inner.lineJoinStyle = .round
			inner.stroke()
		}
	}()

	private static let data: [String: String] = [
		"usdc": "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAMAAADVRocKAAAAkFBMVEUndcosLCz+/v6px+lFh9GNtuPk7fhdl9cnarJzptwndcrJ3fEndMcnV4soN0gnTHQoSGu70+7X5PUrMjknPFIoUHwndMgpQVsmPlcqQVonZKYoU4IncL8mT3wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACQ1EDwAAAAMHRSTlP+AP///////4v/1P+wZxZIOv//BiZRiC1DQ39fh2IAAAAAAAAAAAAAAAAAAAAAAABWG7RvAAAEj0lEQVR42sWa2ZrbKgyAqVkMeLezzEx73v81j5PUMWgBnJl81aUX/SCEEALxq1CW/nPo7J/L5Y/ths9+Kf1PlHzUn23rRSS+tef+RwDLaIHugGLH5ZuAK699Y1xfByznVhRIe15eAiydF4Xiu+U4YChWf0cMBwHXVhyU9nQE0IkXpCsG9K14Sdq+DDB68aL4sQTQiW9Ilwd8Eb/pxjj8tKkm/PQrB7DoF9dUq0zoeX17bKQCj20agPTr6iENDVgFImwKYBn1KQBCWB4A9NemKgJUleYJgvcfGWioJB7k8LWpOV8KACPbfFK/cOEHcSdGCtB72vqreTTj9Q8H274KRsL3BKBlzNPUiYmlgg9NQGgxoGP0u8zcVTNJ6CDgROsHtld6FYh0hiKcAKAl9UNdhnDKsBMBoY0BIzW+RtGuj11q/wV50gOweML7Zm5uET6r8YT0SwA4B/3dPsXhLQHYm7W//L0Dwg4Ytv1JwE6o4y7cAQPuqxEHAcSf5yegxQZSWLve5q2ZtCIIEgaNdgNc8UdoetVNFHmiwACt+3x1/QuwqAPQCAqopw1Vwzf2AQiGWNITQJmKkIY1kgqGWYSTTJHrB6Of6gN8Md4BFnWAaVilnVKqdhPySOhJgY1WgIcNACOMB2br0sx1YTOBvwF6NFcU2QFJMLkuPIenXwH7LJto086EMp0ZhX2uiWAImGaBf8KHkkj3IhvZFdACNzaiBKDkKpoNGNNzMot9jLluc/amV9C4Of6X6OEQOCYCyLL82sSO0otPOJgqG8SSIuNmfoohbesw0htZYCYdt2YQHQDMfJS8e/ikXRLjYoN2woLhafiB22WWbLoEFiW7A2p2KQZZKLMvoNtpxaVkPVSSQugCwKUMcEOYMgIC2DLAfVGe5jwBmahgkKP/V0xAYAd5egKgm5qCybTvC3TeTfMTLZUEyfxE+8iGilREwP0FEe0jCHaSCXaqXoWxBAbMMNhlw7UmNSnGoDhcZxeciVwOFNMDF/tiW7Bk0h1zjFMTS+YZDoKmE0JFRVjNWGj7eCDTFrpRUT4pmSRcA8v1JYnX1oW9ZvSsAsjM8urLUsc9NjRy3cbKit0lwtTNMsmvo30bicrlB4/kN7BRw3j3RKlH7X8GkHq3ENiA1JxtnSlI3hXcOPzdgIRlhInNslyTXTDRFup0aBO4MjYT6Loowj43geE+XCe2yeklQ6OhGfadvkfTil46EwCFCig+KCX8Jj6UhwDEb+ew2uKTVYc8wOFyi8+Xc2ZFA+ZEOUfR5RymIIWmkqRXeknM7baspAZ11c6h3DcogCZKalxR0LjC5R/o7zJlTV1Y1gw/zJQ1U4VZrhd1mBPPucIsKC1HBQojc3Xf2KnHkuJ4nLLrzLbEFRTHUXnfFZf3ZVl5nzigMCUA4Ab2yBGL2hA8AHqZPXxINNMARS889oVjrtv2ifDUqSL2zV///qDu/UeN7z8sff9x7y16v/nA+v1H7jf578ClgRfvVQxl1x6Gb1zcOOUvbpy+e7clefXk+kOXZwbq8szwM5dndsrH0Fl7uVjbDR998W//A+LnMUWOGR8JAAAAAElFTkSuQmCC",
		"usdt": "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAMAAADVRocKAAAAkFBMVEX+/v5Qr5UsLCxnuaOQzLz///+q2Mu94dc4ODjm5ub8/PxbtJzT6+SpqKiUlJR8w6/X19fI5t1UVFPe8OuHh4aKior5+flLS0uc0sNnZmZpaWl2dnZaWVnOzc2ampqgoKCysrLPz87Q0NBgX18AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAnTxSyAAAAMHRSTlP+/wD//9T//weOsP//Z0//iv8X/ztFhxL/K0M5JIRiX2d/fyIAAAAAAAAAAAAAAAD56ltkAAADzElEQVR42s2aaYOjIAyGoyIeiGettp3Otf//P67tdDrlCEStO5tv08E8vkIIBCAkWtoey/d6P1n93h/blPocUBq1ZZbHoFicZ2X7FMBwyjTfD5TslK4EHGrU+41RH5YD0jIHguVlugiQyhiIFr+m8wE92f0V0c8EHHKYafnLHICEBSbJgDaHRZa3NMAuhoUW7ygACStM+gGfsMo+fYAMVlrmBqz2bxDg2f51ggKo4SlWYwAJTzJpB+zUVlEwwyL12Z0N0KrxlQSzLFEjrrUA8hUCDAm5CdA6YKaAICiQbvgGvMAqAUFQaQ7+aADtAxVBsFJCrgK0EQTVfIAuYfcISGNMgIh8JhAJcfoAKDU6uwOYN6oSTMLbD0AXAMESgF0CuAXMAuhtyzsgRwXMAgRgGUgXwAEXMA8wav863AA1LmAeQFjmbTC7mC0GBNzs5glw0p4QywG6hNMVoOVJrs6S7MHubcaHH5Wg50b2BOMLOaY5fxthfCMIW/o8TXgJTUI7AUr6PE1oJPRYA60LnImG8hZc6wTQwtglQFBaRVowg9rHNgEiYjxJmiT5SezN5c+Gj5UwmzdqL8PgFCAYb5KRRdZPJKqJ3LDIlXgGODoEVEXDhK8PqqRjeO48Qo9mStHomRMRGnUq8dFjDxJN9VwLanwUMegwCRJqNNWP2rznUtBgvVBDhnfxNKQ7pQsLy3wo2PRrIbCRmsHeMYiia9Q0nEXCPnzHpLtMjxUeCXsVYEZQxJru1kHFFAn8alMMfItpxsoZaXvICFPR9Ko8KR77risSPlqFaavgDGp46mQX6VkTjG0NWwMwEqBUA81D8ALMBNurU4WH4ANYEvhRm+xsaZkMGC2uBkhjOsEN4LbySAqhtXbD5wO4tcJjpEwnwQXgyK7fSPouggNg939N+i2QCTgA8X9dtqQxmYACMP/XhRdeYkmogMRReLEsfnECAkD93xa/KV4EbIQfIHD/t+W7q0zUCR9AdO7CkW0LhRIsAJf/+xYqdBViu8gFiFz+c3Qbi6WgpriZQNILto1NYyLBk77QjXj4BksIbv9fApBiCIng8a8UQ4xyDoHg8a+Wc9wDyb5g8tX6PSU1H8HnH148RUEPwetfesuaToLXv6WsGQ7egw9Gri/EA6G0jBP89Yvd0uI4o/mXWHn/7H2U4+nxx85rDii433/2m0cs2x8SheHHOv8fv39Qt/1R4xTTSw9Lh//luPcye298YL39kfslT7/SLw3IBZcGtr/28A8ubnzJ2Pbqye0Ust/w8sxdyXDs5fly/ecs++NAvv7zFzdBM3uSuv+/AAAAAElFTkSuQmCC",
		"ethereum": "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAMAAADVRocKAAAAkFBMVEXs7vAtLCw3NzeLi4sUFBSWl5fV19jt7/G1trg3Nzfq7O7T1NZSU1JHR0eHiIlkZWUkJCTFx8inqapLS0uio6XDxMaXmJrn6etYWFl1dnZSUlJ4eXlmZmdkZGWSk5Tc3uB+f4CCg4O/wMLBwsR/gIDf4eOfoaHe4OJ8fX5/f4B/gIGdn6CfoaK9vsAAAAAAAAAQou66AAAAMHRSTlP+AP//////1P8GsJD//0v/////FGeHZoclOBn/L0NXhf8+/384//+BRkJC/2X/AABFN17BAAAEfElEQVR42q2a52KrMAyFHYzNhiSMZjWj7W3vfP/Xu2YGiCQEDX9L/NXnYFmWLFbMx0tf4yx/MU+exa+px/2d4Lx0OH/5jhg8jv8VH54C8PbBaOweJdh73wSc8NFbxmk5wIt9wXj82FsE8ApHMB+n8OYDYnj4jYIR8UzADhNHRQoRajcHkGFiuNKKNPK3gg044N5KaVkJ6vaBB/jAzVUlwHpDzb5xABn+tWxkBYjwN4ppwDvxOaoaYCn8lfcpQECM78oGgPpsnoAGUONr2QJwnx8Jgj1+JVADwH1+IAwAuZgSqAVE1Js5BijIgCP7AMpnITIY8CEYE2gBlM9CfECAlAyeGzkEkD4LJwUAdOxXY4DlknvEI6BgCdQDkD7fbWgBO8FxuA+gfRa7EYApUB9gaY5IDeAmWA4PAaTP4tYHeA53An0A7bPj9QBnpsMjAO3z+Q6gJ6AlBrDk9BQqQMwWaASwNtQP4w7gswUaA5LJD6kEnJhLAABYW+qnpwYQzJjAGED6HNQA0uKNpAGkz6XNBrDnOwwASJ/3FSCYIRAAmNifBa2QnAZQQc9oJFaHOQJBAMrngwHEMxwGAZTPZwMIZk0gWQOEN8IEQSzjR4cTy7Lt9Qyf/ZXAPdaj0Y9hOZhtnvWa67PjiZQp0DGqx7LrZ830ORWvLIGSbizbhhCoz6/i9/QSqLUZA4YIzOdYYOeN7VibR0CfgfmciZxeAkk08tO2YQTicy4ulMPJ4zdv2zAC8fkiXlCHjxGwpgBA89nCPr8gAEAbAlBP4w0GgBKpxMIeG3vWCSwRaPI2XACQsMkZEibmAuQP5DMFo7XZBvVxDsAceDSYYPxCQoUyaecm5AIi87YKNRwqUkQipWErAPFV9c9skWCHhGuzEMrcWU0C1qX4xrErFq6xDccsZQVZMRo/MRN1zURhgcoNB9syq+2mnLYOcUApvk6IFLLcMs/kfuCOV0VfnT/mj5/Vir+iCTaRttTxrjTbfCIAoBS//vcxgeq0Bd2U2z25nMTdinb4akw1kWNXiReet7SbZml2h6iHr45n3UK5kqkjkfx22757D1D3sNNFE1SgJvllJS4dolXHDacPIU36TuR2vcxCNTHQtv6JzlxaoPYAQh2h+rlRNYk6pH32diNcoKqcMHEIHGR3qjlr6IR3SvM5x9hhflpNYhifrpxjLHUGGSaQajMK4kTlq3cQp0oJ4xQ4Yh9jY2YxZOlBfFAMIcs5RCmBKg3e2AUpohiyZRekyJIaWs4JZ5TUqKo+WpDSjDo/q6ypYYCaVdYkC7MuBAhnFmbJmoUCAJqsUUDF8YwjEkegYkF53x0DwgXl/RXn1D8tULCsxaK5/YNgaZNo0AEJlzaJqDZXv4ejF7e5iDp/rwuFCvSX02rcO1N9NEwgZ89rlqb+RCcQEchP2e3eAhcJFyh7QsPaLQHhExrWaMtdSbhQOrvljl0aMKmdfNKlAeTagxs+7dpD7UU+dXEj/8bFjXoaJ+rqyem7V0+aWwTx5fHyzCVOn3Y7p7n+83PJ9Z//gGBAP1P906YAAAAASUVORK5CYII=",
		"bnb": "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAMAAADVRocKAAAAkFBMVEXwuQstLCz+/v3zy0nywiz77cL33IXwuQv11Gv55abWpg44MybttwtORCOGbBqkghaQcxn44JSZehfEmRHstgttWRyCaRzhrgz88dFaSx5jUx5YSyJlVSF9ZRnDmRFnVyFHPiF0YCFQRB9eUCR9ZRoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADiuG0vAAAAMHRSTlP+AP//////1P//jwewFkdnU/9mh4c1PIP/J0MjLDl/QxU6HSZGAAAAAAAAAAAAAADIz8/QAAAEDklEQVR42s2a55KjMAyAFWzAdEhPNtl29/7PeKQsyCBZhiQ3q1+ZDPjDslVtWHhKVnyU1WrdyqoqP4rM9z3weaiod3kMlsT5ri6eAsi+0sHYiJJ+ZQ8CTvzoP4zTfEBW5+AheZ3NAmTLGDwlXmbTAaX38FdEORHwJ4eJkr9NAVQwQ5begCKHWZIXfoBtDDMl3voAKnhAljLgHR6SdwmQwoOSugEPjz8iwLPHHxIswEp8WYWBFh9acYCl+GoStJKIiIoGbKX3ouAukfTklgIUgn2pAIkRLK4gAG7/oMPAEkFP+RjgXoAmGIkbUQ0Bb66nTUCKU09vA4BDQWqPBo0ijFCykkDaQZbyk8sfiZ+ethiQxT7aCe8frL30FGcIUPMTSKihjDUnRuoekLlMQJPGFVlzckwB2AnoSPff2+naGDS17nej2SkAt4Uun/iD0Lr3dUHn7bT1KLeRLoAT7xcMtR721jH8ap/ugJRwyp3osa/D34seDTUVGYBaYjQ+estQexNbRUgtcwvYAA+wdoluqA1leABsroCUBXQj4a3TzUnpASKkoidQRhDaNhShUY1Cyo9sdxJSpgCLAhhAZG2ogddprMWIGAAULaB2ApCvi4jgeeeygLoFpE4AFQCs4Bk4AWkLyDkzGwOu3zsMnj1AUcYMtKOLaECLGAVPl7NoVxkK1k2TgLHcAFzkKeCDddPGH6BYt32E0p3h+AF4KYGqN5SeBaCmUQGV8Ia9N0uk8cPeJ4VUIgwp0HagqYxxLNhzUIAU1gwARUl+eHuiFGDNA/qNrRk9NcMUgASkMoBG4ADGA1JmkXtnx+lJ4dDPA1bkNsXOrluKhtRO43Z27fAlSN6U8qGqn5cbULa2LLtrRQNuabcbcCSd3SgeaAqgPOJBOzzlrkcANRfQumsq4DwPkHuGzNmAVA76iRsgBP3SM23hAHvlkbYsuMSrT7Y4gBETL8/UUWvG0OwsiUkdncmvYVoJakry60zf+/qABuBSgkvfxzqiS2GiPrAeZAsQQkf250aD4Rqi5uk2FJaDqwi0AoCm6gOxHu+KwEUplOBoTY2iZtnQOZFUiPcI5exQhVoqxNlWgkEAjVsJ2DCU3Epw9BIi7Bl0tzWVneSLzRBXOydBvuhaH+A/GrEx6NGQ0nv8wXhKoX9DanFwttRIX6TVlJaa3NVXnr20QZ/ft605EZDPaMxqyrSnNGYX5+e1ls90c1xchptpN5MOWia29/U+FNeXb++//oDi9Ucsrz8kev0xl89Bi+fhCnvUeJ5/1Hj+HYelc9VUTTmwPkw/sD78riP3/3Bp4IIo/a49lPOuPdzWQr64sXn06snGdfVk8+jVk7thlOTlme+n3c65zuTz+Lda7dbr3aoqj5/e13/+Ab1/LpkGKk2LAAAAAElFTkSuQmCC",
		"polygon": "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",
		"arbitrum": "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"
	]
}

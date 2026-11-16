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
		let badge: String
		let color: UInt32
		let address: String
	}

	private struct Coin {
		let name: String
		let badge: String
		let color: UInt32
		let networks: [Network]
	}

	private static let coins: [Coin] = [
		Coin(name: "USDT", badge: "₮", color: 0x26A17B, networks: [
			Network(name: "Tron (TRC-20)", badge: "T", color: 0xE8412A, address: CibulaDonateViewController.tron),
			Network(name: "Ethereum (ERC-20)", badge: "Ξ", color: 0x627EEA, address: CibulaDonateViewController.evm),
			Network(name: "BNB Smart Chain (BEP-20)", badge: "B", color: 0xF0B90B, address: CibulaDonateViewController.evm)]),
		Coin(name: "USDC", badge: "$", color: 0x2775CA, networks: [
			Network(name: "Ethereum (ERC-20)", badge: "Ξ", color: 0x627EEA, address: CibulaDonateViewController.evm),
			Network(name: "Polygon", badge: "P", color: 0x8247E5, address: CibulaDonateViewController.evm),
			Network(name: "Arbitrum", badge: "A", color: 0x28A0F0, address: CibulaDonateViewController.evm)])
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

	private let coinBadge = UILabel()
	private let coinValue = UILabel()
	private let coinButton = UIButton(type: .system)

	private let networkBadge = UILabel()
	private let networkValue = UILabel()
	private let networkButton = UIButton(type: .system)

	private let qrView = UIImageView()
	private let qrBadge = UILabel()

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

		coinButton.showsMenuAsPrimaryAction = true
		networkButton.showsMenuAsPrimaryAction = true

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
		coinBadge.text = coin.badge
		coinBadge.backgroundColor = color(coin.color)
		coinValue.text = coin.name

		networkBadge.text = network.badge
		networkBadge.backgroundColor = color(network.color)
		networkValue.text = network.name

		qrView.image = qrImage(network.address)
		qrBadge.text = coin.badge
		qrBadge.backgroundColor = color(coin.color)

		addressLabel.text = network.address

		let coinName = coin.name
		let networkName = network.name

		warning.text = CibulaL10n.tr(
			"Send only \(coinName) on the \(networkName) network. Anything else will be lost.",
			"Отправляйте только \(coinName) в сети \(networkName). Всё остальное будет потеряно.",
			"Надсилайте лише \(coinName) у мережі \(networkName). Усе інше буде втрачено.")

		coinButton.menu = UIMenu(children: Self.coins.enumerated().map { index, item in
			UIAction(title: item.name, state: index == coinIndex ? .on : .off) { [weak self] _ in
				self?.coinIndex = index
				self?.networkIndex = 0
				self?.refresh()
			}
		})

		networkButton.menu = UIMenu(children: coin.networks.enumerated().map { index, item in
			UIAction(title: item.name, state: index == networkIndex ? .on : .off) { [weak self] _ in
				self?.networkIndex = index
				self?.refresh()
			}
		})
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
	private func pickerPanel(badge: UILabel, caption: String, value: UILabel, button: UIButton) -> UIView {
		let panel = glassPanel()

		badge.font = .systemFont(ofSize: 20, weight: .bold)
		badge.textColor = .white
		badge.textAlignment = .center
		badge.layer.cornerRadius = 22
		badge.clipsToBounds = true
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

		button.translatesAutoresizingMaskIntoConstraints = false
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

		qrBadge.font = .systemFont(ofSize: 22, weight: .bold)
		qrBadge.textColor = .white
		qrBadge.textAlignment = .center
		qrBadge.layer.cornerRadius = 21
		qrBadge.clipsToBounds = true
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

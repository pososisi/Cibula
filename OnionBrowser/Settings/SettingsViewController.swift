//
//  SettingsViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
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
		// Rounded, inset sections instead of the flat grouped list.
		let table = UITableView(frame: view.bounds, style: .insetGrouped)
		table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		tableView = table

		super.viewDidLoad()

		navigationItem.rightBarButtonItem = UIBarButtonItem(
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

			self?.askForRestart()
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

			self?.askForRestart()
		}

		// Last section: only "About" and the version. No header.
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
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CibulaAboutViewController(), animated: true)
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

	private func askForRestart() {
		let alert = UIAlertController(
			title: CibulaL10n.tr("Restart required",
								 "Требуется перезапуск",
								 "Потрібен перезапуск"),
			message: CibulaL10n.tr("Close the app completely and open it again to apply the change.",
								   "Полностью закройте приложение и откройте его снова, чтобы изменение вступило в силу.",
								   "Повністю закрийте застосунок і відкрийте його знову, щоб зміна набула чинності."),
			preferredStyle: .alert)

		alert.addAction(UIAlertAction(title: "OK", style: .default))

		present(alert, animated: true)
	}

	@objc private func dismsiss_() {
		navigationController?.dismiss(animated: true)
	}
}


// MARK: - About screen

class CibulaAboutViewController: UIViewController {

	private let gradient = CAGradientLayer()

	private let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)

	override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	override func loadView() {
		view = UIView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark
		title = tr("About", "О приложении", "Про застосунок")

		gradient.colors = [color(0x0D0019).cgColor, color(0x2A0A52).cgColor, color(0x5B13A8).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		let scroll = UIScrollView()
		scroll.alwaysBounceVertical = true
		scroll.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scroll)

		// Logo.
		let rings = CibulaRingsView()
		rings.translatesAutoresizingMaskIntoConstraints = false

		let ringsHolder = UIView()
		ringsHolder.addSubview(rings)

		NSLayoutConstraint.activate([
			rings.centerXAnchor.constraint(equalTo: ringsHolder.centerXAnchor),
			rings.topAnchor.constraint(equalTo: ringsHolder.topAnchor),
			rings.bottomAnchor.constraint(equalTo: ringsHolder.bottomAnchor),
			rings.widthAnchor.constraint(equalToConstant: 130),
			rings.heightAnchor.constraint(equalToConstant: 130)
		])

		let titleLabel = UILabel()
		titleLabel.text = "Cibula"
		titleLabel.font = .systemFont(ofSize: 38, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		let versionLabel = UILabel()
		versionLabel.text = tr("Version", "Версия", "Версія") + " " + Bundle.main.version
		versionLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
		versionLabel.textColor = lilac
		versionLabel.textAlignment = .center

		let taglineLabel = UILabel()
		taglineLabel.text = tr("A private browser built on Tor — layer by layer, no traces.",
							   "Приватный браузер на базе Tor — слой за слоем, без следов.",
							   "Приватний браузер на основі Tor — шар за шаром, без слідів.")
		taglineLabel.font = .systemFont(ofSize: 17, weight: .semibold)
		taglineLabel.textColor = .white
		taglineLabel.textAlignment = .center
		taglineLabel.numberOfLines = 0

		let free = card("gift.fill",
						tr("Completely free", "Абсолютно бесплатно", "Абсолютно безкоштовно"),
						tr("No subscriptions, no ads, no hidden payments.",
						   "Никаких подписок, рекламы и скрытых платежей.",
						   "Жодних підписок, реклами та прихованих платежів."))

		let design = card("paintbrush.fill",
						  tr("Better design", "Улучшенный дизайн", "Покращений дизайн"),
						  tr("A deep purple theme, glass bars and Safari-style tabs.",
							 "Тёмно-фиолетовая тема, стеклянные панели и вкладки в стиле Safari.",
							 "Темно-фіолетова тема, скляні панелі та вкладки в стилі Safari."))

		let clean = card("sparkles",
						 tr("No clutter", "Без лишнего хлама", "Без зайвого мотлоху"),
						 tr("Everything distracting is gone. All traffic goes through the built-in Tor, no extra setup.",
							"Убрано всё, что отвлекает. Весь трафик идёт через встроенный Tor, без дополнительных настроек.",
							"Прибрано все, що відволікає. Увесь трафік іде через вбудований Tor, без додаткових налаштувань."))

		let donate = donateCard()

		// The name of the original project is built from parts on purpose,
		// so the build script which renames the app doesn't touch it.
		let original = "Onion" + " " + "Browser"

		let footer = UILabel()
		footer.text = tr("Cibula is a fork of the open source project \(original).",
						 "Cibula — форк открытого проекта \(original).",
						 "Cibula — форк відкритого проєкту \(original).")
		footer.font = .systemFont(ofSize: 13, weight: .regular)
		footer.textColor = UIColor.white.withAlphaComponent(0.5)
		footer.textAlignment = .center
		footer.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [ringsHolder, titleLabel, versionLabel, taglineLabel, free, design, clean, donate, footer])
		stack.axis = .vertical
		stack.spacing = 14
		stack.setCustomSpacing(18, after: ringsHolder)
		stack.setCustomSpacing(4, after: titleLabel)
		stack.setCustomSpacing(22, after: versionLabel)
		stack.setCustomSpacing(22, after: taglineLabel)
		stack.setCustomSpacing(22, after: clean)
		stack.translatesAutoresizingMaskIntoConstraints = false
		scroll.addSubview(stack)

		NSLayoutConstraint.activate([
			scroll.topAnchor.constraint(equalTo: view.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
			stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
			stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
			stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
		])
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}


	// MARK: Private Methods

	private func card(_ symbol: String, _ title: String, _ text: String) -> UIView {
		let box = UIView()
		box.backgroundColor = UIColor.white.withAlphaComponent(0.08)
		box.layer.cornerRadius = 18
		box.layer.cornerCurve = .continuous
		box.layer.borderWidth = 1
		box.layer.borderColor = lilac.withAlphaComponent(0.25).cgColor

		let icon = UIImageView(image: UIImage(systemName: symbol))
		icon.tintColor = lilac
		icon.contentMode = .scaleAspectFit
		icon.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = UILabel()
		titleLabel.text = title
		titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
		titleLabel.textColor = .white
		titleLabel.numberOfLines = 0

		let textLabel = UILabel()
		textLabel.text = text
		textLabel.font = .systemFont(ofSize: 15, weight: .regular)
		textLabel.textColor = UIColor.white.withAlphaComponent(0.75)
		textLabel.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [titleLabel, textLabel])
		texts.axis = .vertical
		texts.spacing = 4

		let row = UIStackView(arrangedSubviews: [icon, texts])
		row.axis = .horizontal
		row.alignment = .top
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(row)

		NSLayoutConstraint.activate([
			icon.widthAnchor.constraint(equalToConstant: 28),
			icon.heightAnchor.constraint(equalToConstant: 28),

			row.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
			row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
			row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
		])

		return box
	}

	/// Compact card with a heart and a button, opens the donation sheet.
	private func donateCard() -> UIView {
		let box = UIView()
		box.backgroundColor = UIColor.white.withAlphaComponent(0.08)
		box.layer.cornerRadius = 18
		box.layer.cornerCurve = .continuous
		box.layer.borderWidth = 1
		box.layer.borderColor = lilac.withAlphaComponent(0.25).cgColor

		let heart = UIImageView(image: UIImage(systemName: "heart.fill"))
		heart.tintColor = color(0xFF5C8A)
		heart.contentMode = .scaleAspectFit
		heart.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = UILabel()
		titleLabel.text = tr("Support Cibula", "Поддержать Cibula", "Підтримати Cibula")
		titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
		titleLabel.textColor = .white
		titleLabel.numberOfLines = 0

		let textLabel = UILabel()
		textLabel.text = tr("Cibula is free. If you like it, you can support its development.",
							"Cibula бесплатна. Если она вам нравится, вы можете поддержать её развитие.",
							"Cibula безкоштовна. Якщо вона вам подобається, ви можете підтримати її розвиток.")
		textLabel.font = .systemFont(ofSize: 15, weight: .regular)
		textLabel.textColor = UIColor.white.withAlphaComponent(0.75)
		textLabel.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [titleLabel, textLabel])
		texts.axis = .vertical
		texts.spacing = 4

		let top = UIStackView(arrangedSubviews: [heart, texts])
		top.axis = .horizontal
		top.alignment = .top
		top.spacing = 14

		var config = UIButton.Configuration.filled()
		config.title = tr("Donate", "Пожертвовать", "Пожертвувати")
		config.baseBackgroundColor = color(0x8B2CF5)
		config.baseForegroundColor = .white
		config.cornerStyle = .large
		config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
		config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
			var outgoing = incoming
			outgoing.font = .systemFont(ofSize: 17, weight: .bold)
			return outgoing
		}

		let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
			self?.present(CibulaDonateViewController(), animated: true)
		})

		let column = UIStackView(arrangedSubviews: [top, button])
		column.axis = .vertical
		column.spacing = 14
		column.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(column)

		NSLayoutConstraint.activate([
			heart.widthAnchor.constraint(equalToConstant: 28),
			heart.heightAnchor.constraint(equalToConstant: 28),

			column.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
			column.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
			column.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			column.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
		])

		return box
	}

	private func tr(_ en: String, _ ru: String, _ uk: String) -> String {
		CibulaL10n.tr(en, ru, uk)
	}

	private func color(_ hex: UInt32) -> UIColor {
		UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
				green: CGFloat((hex >> 8) & 0xFF) / 255,
				blue: CGFloat(hex & 0xFF) / 255,
				alpha: 1)
	}
}


// MARK: - Donation sheet

class CibulaDonateViewController: UIViewController {

	/// The Tron (TRC-20) address which receives the USDT donations.
	/// Check every character against your wallet before you publish a build!
	static let address = "TSTNwZH79uAu7CPRDrmxF8frKkWVrihgF2"

	private let gradient = CAGradientLayer()
	private let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)
	private let copyIcon = UIImageView(image: UIImage(systemName: "doc.on.doc"))

	override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	override func loadView() {
		view = UIView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark

		sheetPresentationController?.detents = [.large()]

		gradient.colors = [color(0x0D0019).cgColor, color(0x2A0A52).cgColor, color(0x5B13A8).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		let scroll = UIScrollView()
		scroll.alwaysBounceVertical = true
		scroll.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scroll)

		// "Done" in the top right corner.
		var doneConfig = UIButton.Configuration.plain()
		doneConfig.title = tr("Done", "Готово", "Готово")
		doneConfig.baseForegroundColor = color(0xE6D2FF)
		doneConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
			var outgoing = incoming
			outgoing.font = .systemFont(ofSize: 17, weight: .semibold)
			return outgoing
		}

		let done = UIButton(configuration: doneConfig, primaryAction: UIAction { [weak self] _ in
			self?.dismiss(animated: true)
		})
		done.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(done)

		let titleLabel = UILabel()
		titleLabel.text = tr("Support Cibula", "Поддержать Cibula", "Підтримати Cibula")
		titleLabel.font = .systemFont(ofSize: 26, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		let infoLabel = UILabel()
		infoLabel.text = tr("Cibula is free. If you like it, you can support its development with USDT.",
							"Cibula бесплатна. Если она вам нравится, вы можете поддержать её развитие в USDT.",
							"Cibula безкоштовна. Якщо вона вам подобається, ви можете підтримати її розвиток у USDT.")
		infoLabel.font = .systemFont(ofSize: 15, weight: .regular)
		infoLabel.textColor = UIColor.white.withAlphaComponent(0.75)
		infoLabel.textAlignment = .center
		infoLabel.numberOfLines = 0

		let coinRow = infoRow(badge: "₮", badgeColor: color(0x26A17B),
							  caption: tr("Stablecoin", "Стейблкоин", "Стейблкоїн"),
							  value: "USDT")

		let networkRow = infoRow(badge: "T", badgeColor: color(0xE8412A),
								 caption: tr("Network", "Сеть", "Мережа"),
								 value: "Tron (TRC-20)")

		let warning = UILabel()
		warning.text = tr("Send only USDT on the Tron (TRC-20) network. Anything else will be lost.",
						  "Отправляйте только USDT в сети Tron (TRC-20). Всё остальное будет потеряно.",
						  "Надсилайте лише USDT у мережі Tron (TRC-20). Усе інше буде втрачено.")
		warning.font = .systemFont(ofSize: 13, weight: .regular)
		warning.textColor = UIColor.white.withAlphaComponent(0.55)
		warning.textAlignment = .center
		warning.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [titleLabel, infoLabel, coinRow, networkRow, qrBox(), addressBox(), warning])
		stack.axis = .vertical
		stack.spacing = 14
		stack.setCustomSpacing(8, after: titleLabel)
		stack.setCustomSpacing(22, after: infoLabel)
		stack.translatesAutoresizingMaskIntoConstraints = false
		scroll.addSubview(stack)

		NSLayoutConstraint.activate([
			done.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
			done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),

			scroll.topAnchor.constraint(equalTo: view.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 56),
			stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
			stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
			stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
		])

		view.bringSubviewToFront(done)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}


	// MARK: Actions

	@objc private func copyAddress() {
		UIPasteboard.general.string = Self.address

		UIImpactFeedbackGenerator(style: .light).impactOccurred()

		copyIcon.image = UIImage(systemName: "checkmark")

		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
			self?.copyIcon.image = UIImage(systemName: "doc.on.doc")
		}
	}


	// MARK: Private Methods

	private func panel() -> UIView {
		let box = UIView()
		box.backgroundColor = UIColor.white.withAlphaComponent(0.08)
		box.layer.cornerRadius = 20
		box.layer.cornerCurve = .continuous
		box.layer.borderWidth = 1
		box.layer.borderColor = lilac.withAlphaComponent(0.25).cgColor

		return box
	}

	private func infoRow(badge: String, badgeColor: UIColor, caption: String, value: String) -> UIView {
		let box = panel()

		let circle = UILabel()
		circle.text = badge
		circle.font = .systemFont(ofSize: 22, weight: .heavy)
		circle.textColor = .white
		circle.textAlignment = .center
		circle.backgroundColor = badgeColor
		circle.layer.cornerRadius = 22
		circle.clipsToBounds = true
		circle.translatesAutoresizingMaskIntoConstraints = false

		let captionLabel = UILabel()
		captionLabel.text = caption
		captionLabel.font = .systemFont(ofSize: 13, weight: .regular)
		captionLabel.textColor = UIColor.white.withAlphaComponent(0.6)

		let valueLabel = UILabel()
		valueLabel.text = value
		valueLabel.font = .systemFont(ofSize: 19, weight: .bold)
		valueLabel.textColor = .white

		let texts = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
		texts.axis = .vertical
		texts.spacing = 2

		let row = UIStackView(arrangedSubviews: [circle, texts])
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(row)

		NSLayoutConstraint.activate([
			circle.widthAnchor.constraint(equalToConstant: 44),
			circle.heightAnchor.constraint(equalToConstant: 44),

			row.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
			row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
			row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
		])

		return box
	}

	private func qrBox() -> UIView {
		let holder = UIView()

		let box = UIView()
		box.backgroundColor = .white
		box.layer.cornerRadius = 24
		box.layer.cornerCurve = .continuous
		box.translatesAutoresizingMaskIntoConstraints = false
		holder.addSubview(box)

		let qr = UIImageView(image: qrImage(Self.address))
		qr.contentMode = .scaleAspectFit
		qr.layer.magnificationFilter = .nearest
		qr.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(qr)

		// Small badge in the middle (the code stays readable, it is built with a high error correction).
		let badge = UILabel()
		badge.text = "₮"
		badge.font = .systemFont(ofSize: 26, weight: .heavy)
		badge.textColor = .white
		badge.textAlignment = .center
		badge.backgroundColor = color(0x26A17B)
		badge.layer.cornerRadius = 24
		badge.layer.borderWidth = 5
		badge.layer.borderColor = UIColor.white.cgColor
		badge.clipsToBounds = true
		badge.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(badge)

		NSLayoutConstraint.activate([
			box.topAnchor.constraint(equalTo: holder.topAnchor),
			box.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
			box.centerXAnchor.constraint(equalTo: holder.centerXAnchor),
			box.widthAnchor.constraint(equalToConstant: 230),
			box.heightAnchor.constraint(equalToConstant: 230),

			qr.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
			qr.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
			qr.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			qr.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),

			badge.centerXAnchor.constraint(equalTo: box.centerXAnchor),
			badge.centerYAnchor.constraint(equalTo: box.centerYAnchor),
			badge.widthAnchor.constraint(equalToConstant: 48),
			badge.heightAnchor.constraint(equalToConstant: 48)
		])

		return holder
	}

	private func addressBox() -> UIView {
		let box = panel()

		let captionLabel = UILabel()
		captionLabel.text = tr("Address", "Адрес", "Адреса")
		captionLabel.font = .systemFont(ofSize: 13, weight: .regular)
		captionLabel.textColor = UIColor.white.withAlphaComponent(0.6)

		let valueLabel = UILabel()
		valueLabel.text = Self.address
		valueLabel.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
		valueLabel.textColor = .white
		valueLabel.numberOfLines = 0
		valueLabel.lineBreakMode = .byCharWrapping

		let texts = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
		texts.axis = .vertical
		texts.spacing = 4

		copyIcon.tintColor = lilac
		copyIcon.contentMode = .scaleAspectFit
		copyIcon.translatesAutoresizingMaskIntoConstraints = false

		let row = UIStackView(arrangedSubviews: [texts, copyIcon])
		row.axis = .horizontal
		row.alignment = .center
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(row)

		NSLayoutConstraint.activate([
			copyIcon.widthAnchor.constraint(equalToConstant: 26),
			copyIcon.heightAnchor.constraint(equalToConstant: 26),

			row.topAnchor.constraint(equalTo: box.topAnchor, constant: 14),
			row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -14),
			row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
		])

		box.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyAddress)))

		return box
	}

	private func qrImage(_ text: String) -> UIImage? {
		guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
			return nil
		}

		filter.setValue(Data(text.utf8), forKey: "inputMessage")
		filter.setValue("H", forKey: "inputCorrectionLevel")

		guard let output = filter.outputImage else {
			return nil
		}

		let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

		guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else {
			return nil
		}

		return UIImage(cgImage: cgImage)
	}

	private func tr(_ en: String, _ ru: String, _ uk: String) -> String {
		CibulaL10n.tr(en, ru, uk)
	}

	private func color(_ hex: UInt32) -> UIColor {
		UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
				green: CGFloat((hex >> 8) & 0xFF) / 255,
				blue: CGFloat(hex & 0xFF) / 255,
				alpha: 1)
	}
}


/// Concentric rings, like the layers of an onion.
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
		guard let ctx = UIGraphicsGetCurrentContext() else {
			return
		}

		let center = CGPoint(x: bounds.midX, y: bounds.midY)
		let maxRadius = min(bounds.width, bounds.height) / 2 - 4

		for i in 0..<4 {
			let radius = maxRadius * (1 - CGFloat(i) * 0.22)
			let alpha = 0.3 + 0.2 * CGFloat(i)

			ctx.setStrokeColor(UIColor(red: 0.82, green: 0.62, blue: 1, alpha: alpha).cgColor)
			ctx.setLineWidth(3)
			ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
			ctx.strokePath()
		}

		let core = maxRadius * 0.2
		ctx.setFillColor(UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1).cgColor)
		ctx.fillEllipse(in: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2))
	}
}

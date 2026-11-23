//
//  FixedFormViewController.swift
//  IPtProxyUI
//
//  Created by Benjamin Erhart on 2021-11-29.
//  Copyright © 2019 - 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

/**
Base class of the form screens (settings, security, bookmark editing ...).
The Cibula look (rounded sections on a purple background) comes from the hook on
`FormViewController` below, so it also covers the screens Eureka builds itself.
*/
open class FixedFormViewController: FormViewController {

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		navigationController?.overrideUserInterfaceStyle = .dark

		CibulaTheme.useTextForExit(navigationItem)
	}

	open override func keyboardWillShow(_ notification: Notification) {
		// When showing inside a popover on iPad, the popover gets resized on
		// keyboard display, so we shall not do this inside the view.
		if popoverPresentationController != nil && UIDevice.current.userInterfaceIdiom == .pad {
			return
		}

		super.keyboardWillShow(notification)
	}
}


extension FormViewController {

	/**
	Makes every Eureka form screen of the app rounded and purple. That includes the selection
	lists behind "Language" or "Tab Security", which Eureka creates on its own.
	*/
	static let cibulaSwizzle: Void = {
		let selector = #selector(UIViewController.viewDidLoad)
		let replacementSelector = #selector(FormViewController.cibulaViewDidLoad)

		guard let original = class_getInstanceMethod(FormViewController.self, selector),
			  let replacement = class_getInstanceMethod(FormViewController.self, replacementSelector),
			  let inherited = class_getInstanceMethod(UIViewController.self, selector)
		else {
			return
		}

		// Only exchange, if Eureka has its own version. Otherwise we would touch every screen of the app.
		if method_getImplementation(original) == method_getImplementation(inherited) {
			return
		}

		method_exchangeImplementations(original, replacement)
	}()

	/// After the exchange, calling this runs the original `viewDidLoad` of Eureka.
	@objc func cibulaViewDidLoad() {
		overrideUserInterfaceStyle = .dark

		// Rounded, inset sections instead of the flat grouped list.
		if tableView == nil {
			let table = UITableView(frame: view.bounds, style: .insetGrouped)
			table.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			tableView = table
		}

		cibulaViewDidLoad()

		tableView.backgroundColor = .clear
		tableView.separatorColor = UIColor.white.withAlphaComponent(0.12)

		if !(tableView.backgroundView is FormBackdropView) {
			tableView.backgroundView = FormBackdropView()
		}
	}
}


/// The look of the app for all the screens which open in a navigation controller.
enum CibulaTheme {

	/// Purple of buttons, links and the "Done" pill.
	static let tint = UIColor(red: 0.60, green: 0.33, blue: 1.0, alpha: 1)

	private static var applied = false

	/// Sets the colors of tables, rows and bars once for the whole app.
	static func applyOnce() {
		if applied {
			return
		}

		applied = true

		// Rounded, purple form screens everywhere.
		_ = FormViewController.cibulaSwizzle

		// Defaults of Cibula. What the user has chosen himself always wins.
		UserDefaults.standard.register(defaults: [BrowsingViewController.mergedBarsKey: true])

		let flag = "CibulaDefaultsV2"

		if !UserDefaults.standard.bool(forKey: flag) {
			UserDefaults.standard.set(true, forKey: flag)

			// The tabs stay after a restart. The user can change that in the settings.
			Settings.tabSecurity = .alwaysRemember
		}

		let container: [UIAppearanceContainer.Type] = [UINavigationController.self]

		let table = UITableView.appearance(whenContainedInInstancesOf: container)
		table.backgroundColor = UIColor(red: 0.08, green: 0.03, blue: 0.15, alpha: 1)
		table.separatorColor = UIColor.white.withAlphaComponent(0.12)

		UITableViewCell.appearance(whenContainedInInstancesOf: container).backgroundColor
			= UIColor.white.withAlphaComponent(0.07)

		UINavigationBar.appearance().tintColor = tint
	}

	/// The icon of the app (rings on dark purple). Used where a bookmark has no icon of its own.
	static let logoIcon: UIImage = {
		let size = CGSize(width: 128, height: 128)

		let format = UIGraphicsImageRendererFormat()
		format.scale = 1

		return UIGraphicsImageRenderer(size: size, format: format).image { _ in
			UIColor(red: 0.10, green: 0.012, blue: 0.227, alpha: 1).setFill()
			UIRectFill(CGRect(origin: .zero, size: size))

			let center = CGPoint(x: 64, y: 64)

			let rings: [(CGFloat, UIColor)] = [
				(46, UIColor(red: 106 / 255, green: 63 / 255, blue: 160 / 255, alpha: 1)),
				(36, UIColor(red: 138 / 255, green: 96 / 255, blue: 196 / 255, alpha: 1)),
				(26, UIColor(red: 166 / 255, green: 122 / 255, blue: 232 / 255, alpha: 1)),
				(17, UIColor(red: 190 / 255, green: 150 / 255, blue: 255 / 255, alpha: 1))]

			for (radius, color) in rings {
				let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
				path.lineWidth = 2.6
				color.setStroke()
				path.stroke()
			}

			UIColor(red: 0.45, green: 0.17, blue: 0.93, alpha: 1).setFill()
			UIBezierPath(arcCenter: center, radius: 9, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
		}
	}()

	/// Blue buttons and links become purple.
	static func applyWindow(_ window: UIWindow?) {
		window?.tintColor = tint
	}

	/**
	The system "Done" button is a blue circle with a check mark. Cibula shows the word instead,
	on the left side. Only a button which obviously closes the screen is touched.
	*/
	static func useTextForExit(_ navigationItem: UINavigationItem) {
		guard let item = navigationItem.leftBarButtonItem,
			  item.title == nil, item.image == nil, item.customView == nil,
			  let action = item.action
		else {
			return
		}

		let name = NSStringFromSelector(action).lowercased()

		guard name.contains("dism") || name.contains("done") || name.contains("close") else {
			return
		}

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			title: CibulaL10n.tr("Done", "Готово", "Готово"),
			style: .done, target: item.target, action: action)
	}

	/**
	"Restart required". iOS doesn't allow an app to start itself again, so "OK" closes the app
	and the user opens it once more. "Restart later" (gray) leaves everything as it is.
	*/
	static func presentRestartAlert(on viewController: UIViewController) {
		let alert = UIAlertController(
			title: CibulaL10n.tr("Restart required", "Нужен перезапуск", "Потрібен перезапуск"),
			message: CibulaL10n.tr(
				"The app will close so the change takes effect. Open it again afterwards.",
				"Приложение закроется, чтобы изменение вступило в силу. Потом откройте его снова.",
				"Застосунок закриється, щоб зміна набула чинності. Потім відкрийте його знову."),
			preferredStyle: .alert)

		alert.overrideUserInterfaceStyle = .dark

		// Gray, on top.
		let later = UIAlertAction(
			title: CibulaL10n.tr("Restart later", "Перезагрузить позже", "Перезавантажити пізніше"),
			style: .default)
		later.setValue(UIColor.systemGray, forKey: "titleTextColor")

		// White, below. The "cancel" style puts it at the bottom and makes it bold.
		let ok = UIAlertAction(
			title: CibulaL10n.tr("OK", "Ок", "Ок"),
			style: .cancel) { _ in
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
					exit(0)
				}
			}
		ok.setValue(UIColor.white, forKey: "titleTextColor")

		alert.addAction(later)
		alert.addAction(ok)

		viewController.present(alert, animated: true)
	}
}


/// Dark purple gradient behind the tables of the form screens.
private final class FormBackdropView: UIView {

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
						   UIColor(red: 0.11, green: 0.04, blue: 0.22, alpha: 1).cgColor,
						   UIColor(red: 0.18, green: 0.06, blue: 0.36, alpha: 1).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
	}
}

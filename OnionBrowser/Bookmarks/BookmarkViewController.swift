//
//  BookmarkViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import PhotosUI
import Eureka

class BookmarkViewController: FixedFormViewController {

	var index: Int?
	var folder: NcFolder = NcBookmarks.root
	var delegate: BookmarksViewControllerDelegate?

	private var bookmark: NcBookmark?

	private var sceneGoneStoreImmediately = false

	/// A new bookmark goes to the top of the list instead of the end (used by the "+" on the start page).
	var insertAtTop = false

	/// The user picked an icon himself. Then no icon is loaded from the website anymore.
	private var customIcon = false

	/// This screen is the first one of its own navigation controller (opened from the start page).
	private var isSheetRoot: Bool {
		navigationController?.viewControllers.first === self
	}

	private let favIconRow = FavIconRow() {
		$0.placeholderImage = CibulaTheme.logoIcon
	}

	private let titleRow = TextRow() {
		$0.placeholder = NSLocalizedString("Title", comment: "Bookmark title placeholder")
	}

	private let urlRow = URLRow() {
		$0.placeholder = NSLocalizedString("Address", comment: "Bookmark URL placeholder")
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		// No arrow and check buttons above the keyboard.
		navigationOptions = RowNavigationOptions.Disabled

		// Was called via "+" (add).
		if index == nil {

			// Check, if we have a valid URL in the current tab. If so, prefill with that.
			if let info = AddSiteViewController.getCurrentTabInfo(view.sceneDelegate) {

				// Check, if this page is already bookmarked. If so, edit that.
				if let bookmark = folder.bookmarks.first(where: { $0.url == info.url.absoluteString }) {
					self.bookmark = bookmark
					index = folder.bookmarks.firstIndex(of: bookmark)
				}
				else {
					titleRow.value = info.title
					urlRow.value = info.url

					acquireIcon()
				}
			}
		}
		else {
			bookmark = folder.bookmarks[index!]
		}

		navigationItem.title = index == nil
			? NSLocalizedString("Add Bookmark", comment: "Scene title")
			: NSLocalizedString("Edit Bookmark", comment: "Scene title")

		if index == nil {
			navigationItem.rightBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .save, target: self, action: #selector(addNew))

			// Don't allow to store empty bookmarks.
			navigationItem.rightBarButtonItem?.isEnabled = urlRow.value != nil
		}

		// Opened from the start page: there is no "back", so there is a button to leave.
		if isSheetRoot {
			navigationItem.leftBarButtonItem = UIBarButtonItem(
				title: index == nil
					? CibulaL10n.tr("Cancel", "Отмена", "Скасувати")
					: CibulaL10n.tr("Done", "Готово", "Готово"),
				style: .plain, target: self, action: #selector(closeSheet))
		}

		if let bookmark = bookmark {
			favIconRow.value = bookmark.icon
			titleRow.value = bookmark.title
			urlRow.value = URL(string: bookmark.url)

			if bookmark.icon == nil {
				acquireIcon()
			}
		}

		form
			+++ favIconRow
			<<< titleRow
			<<< urlRow
			.onChange { [weak self] row in
				self?.acquireIcon()
				self?.navigationItem.rightBarButtonItem?.isEnabled = row.value != nil
			}

		// Tap on the icon: pick an own one from the photo library.
		favIconRow.cell.isUserInteractionEnabled = true
		favIconRow.cell.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chooseIcon)))
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		// Store changes, if user edits an existing bookmark or bookmark was created
		// with #addNew.
		if index != nil {
			bookmark?.title = titleRow.value ?? bookmark?.title ?? ""

			// Don't allow empty URL.
			if let url = cleanUrl() {
				bookmark?.url = url.absoluteString
			}

			bookmark?.icon = favIconRow.value

			bookmark?.updateLastModified()

			NcBookmarks.store()

			if let bookmark {
				if #available(iOS 18.0, *) {
					BookmarkEntity.add(bookmark: bookmark)
				}

				Task {
					do {
						if try await bookmark.upload() {
							NcBookmarks.store()
						}
					}
					catch {
						Log.error(for: Self.self, "\(error)")
					}
				}
			}

			delegate?.needsReload()

			sceneGoneStoreImmediately = true
		}
	}


	// MARK: Private Methods

	@objc private func addNew() {
		if let url = cleanUrl() {
			bookmark = NcBookmark(url: url.absoluteString, title: titleRow.value ?? "", folder: folder)

			if insertAtTop {
				folder.bookmarks.insert(bookmark!, at: 0)
			}
			else {
				folder.bookmarks.append(bookmark!)
			}

			// Trigger store in #viewWillDisappear by setting index != nil.
			index = folder.bookmarks.firstIndex(of: bookmark!)

			if isSheetRoot {
				dismiss(animated: true)
			}
			else {
				navigationController?.popViewController(animated: true)
			}
		}
	}

	@objc private func closeSheet() {
		dismiss(animated: true)
	}

	@objc private func chooseIcon() {
		let sheet = UIAlertController(
			title: nil, message: nil, preferredStyle: .actionSheet)

		sheet.overrideUserInterfaceStyle = .dark

		sheet.addAction(UIAlertAction(
			title: CibulaL10n.tr("Choose from library", "Выбрать из галереи", "Обрати з галереї"),
			style: .default) { [weak self] _ in
				self?.showPhotoPicker()
			})

		if urlRow.value != nil {
			sheet.addAction(UIAlertAction(
				title: CibulaL10n.tr("Load from website", "Загрузить с сайта", "Завантажити з сайту"),
				style: .default) { [weak self] _ in
					self?.customIcon = false
					self?.acquireIcon()
				})
		}

		sheet.addAction(UIAlertAction(
			title: CibulaL10n.tr("Cancel", "Отмена", "Скасувати"), style: .cancel))

		sheet.popoverPresentationController?.sourceView = favIconRow.cell
		sheet.popoverPresentationController?.sourceRect = favIconRow.cell.bounds

		present(sheet, animated: true)
	}

	private func showPhotoPicker() {
		var configuration = PHPickerConfiguration()
		configuration.filter = .images
		configuration.selectionLimit = 1

		let picker = PHPickerViewController(configuration: configuration)
		picker.delegate = self

		present(picker, animated: true)
	}

	/// Cuts the picture to a square and makes it small enough for a bookmark.
	fileprivate func useCustomIcon(_ image: UIImage) {
		let side: CGFloat = 256
		let size = CGSize(width: side, height: side)

		let format = UIGraphicsImageRendererFormat()
		format.scale = 1

		let square = UIGraphicsImageRenderer(size: size, format: format).image { _ in
			let ratio = max(side / image.size.width, side / image.size.height)
			let drawn = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

			image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
								  width: drawn.width, height: drawn.height))
		}

		customIcon = true

		favIconRow.value = square
		favIconRow.reload()
	}

	private func acquireIcon() {
		// An icon the user has picked stays.
		guard !customIcon, let url = cleanUrl() else {
			return
		}

		Task {
			let image = await NcBookmark.icon(for: url)

			if self.customIcon {
				return
			}

			favIconRow.value = image
			favIconRow.reload()

			// User stored bookmark and left scene.
			// If we return to late, store the icon of the bookmark immediately,
			// so we don't loose that information.
			if self.sceneGoneStoreImmediately {
				self.bookmark?.icon = image
				NcBookmarks.store()
			}
		}
	}

	private func cleanUrl() -> URL? {
		guard let url = urlRow.value else {
			return nil
		}

		var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true)
		if urlc?.scheme?.isEmpty ?? true {
			urlc?.scheme = "https"
		}

		// When no URL formatting is given, a domain is always parsed as a path.
		// Users enter domains here most likely, though.
		if urlc?.host?.isEmpty ?? true {
			let host = urlc?.path

			if host?.isEmpty ?? true {
				return nil
			}

			urlc?.host = host
			urlc?.path = "/"
		}

		return urlc?.url
	}
}


extension BookmarkViewController: PHPickerViewControllerDelegate {

	func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
		picker.dismiss(animated: true)

		guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
			return
		}

		provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
			guard let image = object as? UIImage else {
				return
			}

			DispatchQueue.main.async {
				self?.useCustomIcon(image)
			}
		}
	}
}

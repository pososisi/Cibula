//
//  BrowsingViewController+Tabs.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright © 2012 - 2024, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension BrowsingViewController: UICollectionViewDataSource, UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate,
UICollectionViewDropDelegate, TabCellDelegate {

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return tabsCollection?.isHidden ?? true ? .default : .lightContent
	}


	private var cardWidth: CGFloat {
		let size = UIScreen.main.bounds.size

		// Could be 0 or less, so secure against becoming negative with minimum width of smallest iOS device.
		return (min(max(320, size.width), max(320, size.height)) - 8 * 2 /* left and right inset */) / 2 - 8 /* spacing */
	}

	private var cellSize: CGSize {
		let width = cardWidth

		// Cards in the proportions of Safari. The 24 points are the header of the card.
		return CGSize(width: width, height: width * BrowsingViewController.tabCardRatio + 24)
	}

	private var overviewBackground: UIColor {
		UIColor(red: 0.08, green: 0.02, blue: 0.16, alpha: 1)
	}

	private var overviewBarTag: Int { 7701 }


	@objc func showOverview() {
		unfocusSearchField()

		// The page is still visible here, so this is the moment to take its picture.
		captureSnapshot()

		// Reset before showing the overview. Would become cumbersome,
		// if we'd call everywhere, where a tab might change.
		for tab in tabs {
			tab.clearSnapshot()
		}

		// Reordering by drag and drop. On iPhone this is off by default.
		tabsCollection?.dragDelegate = self
		tabsCollection?.dropDelegate = self
		tabsCollection?.dragInteractionEnabled = true
		tabsCollection?.reorderingCadence = .immediate

		self.tabsCollection?.reloadData()

		view.backgroundColor = overviewBackground
		tabsCollection?.backgroundColor = .clear
		tabsCollection?.contentInset.bottom = 100

		// The page insets for the floating bars are not needed in the overview.
		updateFloatingMetrics(overview: true)

		// A page loading in the background would show its progress bar again,
		// even when hidden. Transparent stays invisible.
		progress?.alpha = 0

		// The old bottom bar would stay visible behind our floating bar.
		toolbar?.alpha = 0

		showOverviewBar()

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar?.isHidden = true
			self.progress?.isHidden = true
			self.container?.isHidden = true
			self.tabsCollection?.isHidden = false
			self.mainTools?.isHidden = true
			// The old bar is replaced by our floating glass bar.
			self.tabsTools?.isHidden = true

			// The search field of the start page doesn't belong into the overview.
			self.updateStartOverlay()
		})
	}

	@objc func newTabFromOverview() {
		addNewTab(transition: .notAnimated) { _ in
			self.hideOverview() { _ in
				self.searchFl?.becomeFirstResponder()
			}
		}
	}

	@objc func hideOverview() {
		hideOverview(completion: nil)
	}


	// MARK: UICollectionViewDataSource

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return tabsCollection?.isHidden ?? true ? 0 : tabs.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier, for: indexPath)

		if let cell = cell as? TabCell {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row > -1 && indexPath.row < tabs.count {
				let tab = tabs[indexPath.row]

				// Semi-transparent, so the glass effect of the header stays visible.
				cell.header.backgroundColor = tab == currentTab
					? UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 0.6)
					: UIColor(red: 0.10, green: 0.03, blue: 0.20, alpha: 0.6)
				cell.setName(displayName(for: tab))

				// Without a picture of its own (never shown in this session) a tab gets a calm placeholder.
				cell.preview.image = tabSnapshots[ObjectIdentifier(tab)] ?? placeholder(for: tab)

				tab.isHidden = false
			}

			cell.delegate = self
		}

		return cell
	}

	
	// MARK: UICollectionViewDelegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		// Crash reports show, that indexPath.row can sometimes be different then
		// the real size of `tabs`. No idea why that race condition happens, but
		// we should at least not crash, if so.
		if indexPath.row > -1 && indexPath.row < tabs.count {
			currentTab = tabs[indexPath.row]
			hideOverview(completion: nil)
		}
	}

	// MARK: UICollectionViewDelegateFlowLayout

	func collectionView(_ collectionView: UICollectionView, layout
		collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return cellSize
	}


	// MARK: UICollectionViewDragDelegate

	func collectionView(_ collectionView: UICollectionView, itemsForBeginning
		session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {

		guard indexPath.row > -1 && indexPath.row < tabs.count else {
			return []
		}

		// Haptic feedback, when a tab gets lifted.
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()

		let tab = tabs[indexPath.row]

		let dragItem = UIDragItem(itemProvider: NSItemProvider(object: tab.url.absoluteString as NSString))
		dragItem.localObject = tab

		return [dragItem]
	}

	func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
		return roundedPreview(collectionView, indexPath)
	}


	// MARK: UICollectionViewDropDelegate

	func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate
		session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?)
		-> UICollectionViewDropProposal {

			if tabsCollection?.hasActiveDrag ?? false {
				return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
			}

			return UICollectionViewDropProposal(operation: .forbidden)
	}

	func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
		if coordinator.proposal.operation == .move,
			let item = coordinator.items.first,
			let source = item.sourceIndexPath,
			let destination = coordinator.destinationIndexPath,
			source.row > -1 && source.row < tabs.count {

			var target = destination

			collectionView.performBatchUpdates({
				let tab = tabs.remove(at: source.row)

				let row = min(max(destination.row, 0), tabs.count)
				target = IndexPath(item: row, section: destination.section)

				tabs.insert(tab, at: row)
				currentTab = tab

				collectionView.deleteItems(at: [source])
				collectionView.insertItems(at: [target])
			})

			coordinator.drop(item.dragItem, toItemAt: target)

			UIImpactFeedbackGenerator(style: .light).impactOccurred()
		}
	}

	func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
		return roundedPreview(collectionView, indexPath)
	}


	// MARK: TabCellDelegate

	func close(_ sender: TabCell) {
		if let indexPath = tabsCollection?.indexPath(for: sender), indexPath.row > -1 {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row < tabs.count {
				tabsCollection?.performBatchUpdates({
					removeTab(tabs[indexPath.row])

					tabsCollection?.deleteItems(at: [indexPath])
				})
			}
		}
	}


	// MARK: Private Methods

	/// The title of a tab. The start page and empty tabs have none, so we make one up.
	private func displayName(for tab: Tab) -> String {
		let raw = (tab.title as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		if !raw.isEmpty {
			return raw
		}

		if tab.url == URL.start {
			return "Cibula"
		}

		return tab.url.host ?? ""
	}

	/// A dark card with a globe and the address, for tabs we have no picture of.
	private func placeholder(for tab: Tab) -> UIImage {
		let size = CGSize(width: cardWidth, height: cardWidth * BrowsingViewController.tabCardRatio)

		let lilac = UIColor(red: 0.82, green: 0.62, blue: 1, alpha: 0.6)

		return UIGraphicsImageRenderer(size: size).image { context in
			UIColor(red: 0.12, green: 0.04, blue: 0.24, alpha: 1).setFill()
			context.fill(CGRect(origin: .zero, size: size))

			let symbol = UIImage.SymbolConfiguration(pointSize: size.width * 0.3, weight: .light)

			if let globe = UIImage(systemName: "globe", withConfiguration: symbol)?
				.withTintColor(lilac, renderingMode: .alwaysOriginal) {

				globe.draw(at: CGPoint(x: (size.width - globe.size.width) / 2,
									   y: (size.height - globe.size.height) / 2 - 16))
			}

			let host = tab.url.host ?? ""

			if !host.isEmpty {
				let style = NSMutableParagraphStyle()
				style.alignment = .center
				style.lineBreakMode = .byTruncatingMiddle

				let attributes: [NSAttributedString.Key: Any] = [
					.font: UIFont.systemFont(ofSize: 12, weight: .medium),
					.foregroundColor: lilac,
					.paragraphStyle: style
				]

				NSAttributedString(string: host, attributes: attributes).draw(
					in: CGRect(x: 10, y: size.height / 2 + size.width * 0.18, width: size.width - 20, height: 18))
			}
		}
	}

	private func roundedPreview(_ collectionView: UICollectionView, _ indexPath: IndexPath) -> UIDragPreviewParameters? {
		guard let cell = collectionView.cellForItem(at: indexPath) else {
			return nil
		}

		let parameters = UIDragPreviewParameters()
		parameters.backgroundColor = .clear
		parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 20)

		return parameters
	}

	/// Floating glass bar with "+" and "Done", replaces the old grey toolbar.
	private func showOverviewBar() {
		if let existing = view.viewWithTag(overviewBarTag) {
			existing.isHidden = false
			view.bringSubviewToFront(existing)

			return
		}

		let bar: UIVisualEffectView

		if #available(iOS 26.0, *) {
			let glass = UIGlassEffect()
			glass.isInteractive = true
			bar = UIVisualEffectView(effect: glass)
		}
		else {
			bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
			bar.backgroundColor = UIColor(red: 0.16, green: 0.04, blue: 0.32, alpha: 0.35)
		}

		bar.tag = overviewBarTag
		bar.layer.cornerRadius = 28
		bar.layer.cornerCurve = .continuous
		bar.clipsToBounds = true
		bar.translatesAutoresizingMaskIntoConstraints = false

		let tint = UIColor(red: 0.90, green: 0.82, blue: 1, alpha: 1)

		var plusConfig = UIButton.Configuration.plain()
		plusConfig.image = UIImage(systemName: "plus",
								   withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
		plusConfig.baseForegroundColor = tint

		let plus = UIButton(configuration: plusConfig, primaryAction: UIAction { [weak self] _ in
			self?.newTabFromOverview()
		})
		plus.translatesAutoresizingMaskIntoConstraints = false

		var doneConfig = UIButton.Configuration.plain()
		doneConfig.title = CibulaL10n.tr("Done", "Готово", "Готово")
		doneConfig.baseForegroundColor = tint
		doneConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
			var outgoing = incoming
			outgoing.font = .systemFont(ofSize: 18, weight: .semibold)
			return outgoing
		}

		let done = UIButton(configuration: doneConfig, primaryAction: UIAction { [weak self] _ in
			self?.hideOverview()
		})
		done.translatesAutoresizingMaskIntoConstraints = false

		bar.contentView.addSubview(plus)
		bar.contentView.addSubview(done)
		view.addSubview(bar)

		NSLayoutConstraint.activate([
			bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
			bar.heightAnchor.constraint(equalToConstant: 56),

			plus.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor, constant: 14),
			plus.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
			plus.widthAnchor.constraint(equalToConstant: 48),
			plus.heightAnchor.constraint(equalToConstant: 48),

			done.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor, constant: -14),
			done.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
			done.heightAnchor.constraint(equalToConstant: 48)
		])
	}

	private func hideOverview(completion: ((_ finished: Bool) -> Void)?) {
		for tab in tabs {
			tab.isHidden = tab != currentTab
		}

		updateChrome()

		// Back to normal browsing: page insets for the floating bars, bars visible again.
		updateFloatingMetrics(overview: false)

		progress?.alpha = 1
		toolbar?.alpha = 1
		showToolbar(true, false)

		view.viewWithTag(overviewBarTag)?.isHidden = true

		self.view.backgroundColor = .systemBackground

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar?.isHidden = false
			self.tabsCollection?.isHidden = true
			self.container?.isHidden = false
			self.tabsTools?.isHidden = true
			self.mainTools?.isHidden = false

			// Back on the start page, its search field comes back.
			self.updateStartOverlay()
		}, completion)
	}
}

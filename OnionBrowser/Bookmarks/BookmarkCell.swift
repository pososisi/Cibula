//
//  BookmarkCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 19.12.19.
//  Copyright © 2019 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BookmarkCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

	class var height: CGFloat {
		return 56
	}

	/// Width and height of the icon.
	private static let iconSize: CGFloat = 36

	@IBOutlet weak var iconImg: UIImageView!
    @IBOutlet weak var iconWidth: NSLayoutConstraint!
    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var nameLeading: NSLayoutConstraint!


	override func awakeFromNib() {
		super.awakeFromNib()

		// Rounded corners, like the tiles on the start page.
		iconImg.clipsToBounds = true
		iconImg.layer.cornerRadius = 9
		iconImg.layer.cornerCurve = .continuous
	}

	func set(_ folder: NcFolder) -> BookmarkCell {
		iconImg.image = NcFolder.icon

		nameLb.text = folder.title

		iconWidth.constant = Self.iconSize
		nameLeading.constant = 12

		accessoryType = .disclosureIndicator

		return self
	}

	func set(_ bookmark: NcBookmark) -> BookmarkCell {
		iconImg.image = bookmark.icon

		nameLb.text = bookmark.title.isEmpty
			? bookmark.url
			: bookmark.title

		if iconImg.image == nil {
			iconWidth.constant = 0
			nameLeading.constant = 0
		}
		else {
			iconWidth.constant = Self.iconSize
			nameLeading.constant = 12
		}

		accessoryType = .none

		return self
	}
}

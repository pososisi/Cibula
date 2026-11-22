//
//  SecurityLevelCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 13.12.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SecurityLevelCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

	/// 64 points of card and 4 points of space above and below.
    class var height: CGFloat {
        return 72
    }

	static var shieldImage = UIImage(named: "shield")
	static var customShieldImage = UIImage(named: "custom-shield")

	/// The blue of the check mark and of the frame of the chosen card.
	private static let blue = UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1)


	override func awakeFromNib() {
        super.awakeFromNib()

		backgroundColor = .clear
		selectionStyle = .none

		// Every level is a rounded card.
		contentView.layer.cornerRadius = 20
		contentView.layer.cornerCurve = .continuous
		contentView.layer.borderWidth = 1.5
		contentView.clipsToBounds = true

		nameLb.textColor = .white

		// The explanation gets two lines and a normal font, not squeezed into one.
		explanationLb.textColor = UIColor.white.withAlphaComponent(0.65)
		explanationLb.font = .systemFont(ofSize: 12)
		explanationLb.numberOfLines = 2
		explanationLb.adjustsFontSizeToFitWidth = false
		explanationLb.lineBreakMode = .byTruncatingTail

		updateLook(selected: false)
    }

    @IBOutlet weak var shieldImg: UIImageView!
    @IBOutlet weak var numberLb: UILabel!
    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var explanationLb: UILabel!
	@IBOutlet weak var radioLb: UILabel! {
		didSet {
			radioLb.layer.borderColor = Self.blue.cgColor
			radioLb.clipsToBounds = true
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		// A little space around the card.
		contentView.frame = bounds.insetBy(dx: 12, dy: 4)
	}

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

		updateLook(selected: selected)
    }

	@discardableResult
	func set(_ preset: SecurityPreset) -> SecurityLevelCell {

		if preset == .custom {
			shieldImg.image = SecurityLevelCell.customShieldImage
			numberLb.isHidden = true
		}
		else {
			shieldImg.image = SecurityLevelCell.shieldImage
			shieldImg.tintColor = preset.color
			numberLb.isHidden = false
			numberLb.text = preset.shortcode
		}

		let text = NSMutableAttributedString(
			string: preset.description,
			attributes: [.foregroundColor: UIColor.white])

		if let recommendation = preset.recommendation {
			let size = nameLb.font.pointSize - 2
			var font = UIFont.systemFont(ofSize: size, weight: .bold)

			if let descriptor = font.fontDescriptor.withSymbolicTraits([.traitItalic, .traitBold]) {
				font = UIFont(descriptor: descriptor, size: size)
			}

			text.append(NSAttributedString(string: " "))
			text.append(NSAttributedString(string: recommendation, attributes: [
				.font: font,
				.foregroundColor: UIColor.white.withAlphaComponent(0.7)
			]))
		}

		nameLb.attributedText = text

		explanationLb.text = preset.explanation

		return self
	}


	// MARK: Private Methods

	/// The chosen card has a blue frame and a blue check mark.
	private func updateLook(selected: Bool) {
		let blue = Self.blue

		contentView.backgroundColor = selected
			? blue.withAlphaComponent(0.28)
			: UIColor.white.withAlphaComponent(0.08)

		contentView.layer.borderColor = selected ? blue.cgColor : UIColor.clear.cgColor

		radioLb.backgroundColor = selected ? blue : .clear
		radioLb.text = selected ? "\u{2713}" : nil
	}
}

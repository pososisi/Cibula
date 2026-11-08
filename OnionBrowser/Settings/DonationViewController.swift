//
//  DonationViewController.swift
//  OnionBrowser
//
//  The donation page of Cibula. The start page ("Donate") and the settings open this class,
//  so it keeps its name. The content comes from CibulaDonateViewController.
//

import UIKit

class DonationViewController: CibulaDonateViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		title = CibulaL10n.tr("Support Cibula", "Поддержать Cibula", "Підтримати Cibula")

		// Inside the navigation stack the bar has a back button, the inline "Done" is not needed.
		if navigationController != nil {
			for button in view.subviews.compactMap({ $0 as? UIButton }) {
				button.isHidden = true
			}
		}
	}
}

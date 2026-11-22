//
//  CircuitViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 04.12.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit
import TorCore
import IPtProxyUI_iOS


class CircuitViewController: UIViewController, UIPopoverPresentationControllerDelegate,
							 UITableViewDataSource, UITableViewDelegate, BridgesConfDelegate 
{

	struct Node {
		var title: String
		var ip: String?
		var note: String?

		init(title: String, ip: String? = nil, note: String? = nil) {
			self.title = title
			self.ip = ip
			self.note = note
		}

		init(_ torNode: OrbotKit.TorNode) {
			self.title = torNode.localizedCountryName ?? torNode.countryCode ?? torNode.nickName ?? ""
			self.ip = torNode.ipv4Address?.isEmpty ?? true ? torNode.ipv6Address : torNode.ipv4Address
		}
	}

	public var currentUrl: URL?

	/// The blue of the buttons.
	private static let blue = UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1)

	private static let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = CibulaL10n.tr("Tor Circuit", "Цепочка Tor", "Ланцюжок Tor")
		}
	}

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noCircuitsView: UIView!

    @IBOutlet weak var noCircuitsLb1: UILabel! {
        didSet {
            noCircuitsLb1.text = CibulaL10n.tr(
				"Your traffic goes through 3 different parts of the world.",
				"Ваш трафик проходит через 3 разные части света.",
				"Ваш трафік проходить через 3 різні частини світу.")
        }
    }
    @IBOutlet weak var noCircuitsLb2: UILabel! {
        didSet {
            noCircuitsLb2.text = CibulaL10n.tr(
				"Open a website to see your circuit.",
				"Откройте сайт, чтобы увидеть свою цепочку.",
				"Відкрийте сайт, щоб побачити свій ланцюжок.")
        }
    }

    @IBOutlet weak var newCircuitsBt: UIButton! {
		didSet {
			newCircuitsBt.setTitle(CibulaL10n.tr(
				"New Circuit for This Site",
				"Новая цепочка для сайта",
				"Новий ланцюжок для сайту"))
		}
	}

	@IBOutlet weak var bridgeConfigBt: UIButton! {
		didSet {
			bridgeConfigBt.setTitle(CibulaL10n.tr(
				"Bridge Settings",
				"Настройки мостов",
				"Налаштування мостів"))
		}
	}


	override var preferredContentSize: CGSize {
		get {
			// The picture of the world needs more room than the list of nodes.
			return CGSize(width: 300, height: (currentUrl?.isSpecial ?? true) ? 380 : 360)
		}
		set {
			// Ignore.
		}
	}

	private var nodes = [Node]()
	private var usedCircuits = [OrbotKit.TorCircuit]()

	private weak var mapView: CibulaCircuitMapView?

	private static let onionAddressRegex = try? NSRegularExpression(pattern: "^(.*\\.)?(.*?)\\.(onion|exit)$", options: .caseInsensitive)

	private static let beginningOfTime = Date(timeIntervalSince1970: 0)

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark

		styleForCibula()

		tableView.register(CibulaCircuitCell.self, forCellReuseIdentifier: CibulaCircuitCell.reuseId)

		if currentUrl?.isSpecial ?? true {
			tableView.isHidden = true
            noCircuitsView.isHidden = false
			newCircuitsBt.isHidden = true
		}
		else {
            noCircuitsView.isHidden = true
			reloadCircuits()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Purple glass, like the bars of the browser.
		popoverPresentationController?.backgroundColor = UIColor(red: 0.17, green: 0.07, blue: 0.34, alpha: 0.96)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// The four points show up one after the other, then the lines are drawn between them.
		if !noCircuitsView.isHidden {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
				self?.mapView?.startAnimation()
			}
		}
	}


	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return nodes.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: CibulaCircuitCell.reuseId, for: indexPath)
			as! CibulaCircuitCell

		cell.set(nodes[indexPath.row], isFirst: indexPath.row < 1, isLast: indexPath.row > nodes.count - 2)

		return cell
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return CibulaCircuitCell.height
	}


	// MARK: UIPopoverPresentationControllerDelegate

	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: BridgesConfDelegate

	var transport: IPtProxyUI_Shared.Transport {
		get {
			Settings.transport
		}
		set {
			Settings.transport = newValue
		}
	}

	var customBridges: [String]? {
		get {
			Settings.customBridges
		}
		set {
			Settings.customBridges = newValue
		}
	}

	var countryCode: String? {
		get {
			Settings.countryCode
		}
		set {
			Settings.countryCode = newValue
		}
	}

	func save() {
		TorManager.shared.updateConfig(Settings.transport)
	}


	// MARK: Actions

	@IBAction func newCircuits() {
		Task {
			if Settings.useBuiltInTor == true {
				await TorManager.shared.close(usedCircuits.compactMap({ $0.circuitId }))
			}
			else {
				await OrbotManager.shared.closeCircuits(usedCircuits)
			}

			await MainActor.run {
				view.sceneDelegate?.browsingUi.currentTab?.refresh()

				dismiss(animated: true)
			}
		}
	}

	@IBAction func showBridgeSelection(_ sender: UIView) {
		if Settings.useBuiltInTor == true {
			let vc = BridgesConfViewController()
			vc.delegate = self

			present(UINavigationController(rootViewController: vc))
		}
		else {
			Task {
				await OrbotKit.shared.open(.bridges)
			}
		}
	}

	private func reloadCircuits() {
		Task {
			let host = currentUrl?.host

			let okCircuits: [OrbotKit.TorCircuit]

			if Settings.useBuiltInTor == true {
				let circuits = await TorManager.shared.getCircuits()

				var candidates = TorCircuit.filter(circuits)

				if let host = host {
					var query: String?

					let matches = Self.onionAddressRegex?.matches(
						in: host, options: [],
						range: NSRange(host.startIndex ..< host.endIndex, in: host))

					if let match = matches?.first,
					   match.numberOfRanges > 1
					{
					   let nsRange = match.range(at: match.numberOfRanges - 2)

						if let range = Range(nsRange, in: host) {
							query = String(host[range])
						}
					}

					// Circuits used for .onion addresses can be identified by their
					// rendQuery, which is equal to the "domain".
					if let query = query {
						candidates = candidates.filter { circuit in
							circuit.purpose == TorCircuit.purposeHsClientRend
							&& circuit.rendQuery == query
						}
					}
					else {
						candidates = candidates.filter { circuit in
							circuit.purpose == TorCircuit.purposeGeneral || circuit.purpose == TorCircuit.purposeConfluxLinked
						}
					}
				}

				okCircuits = candidates.compactMap({ $0.toOrbotKitType() })
			}
			else {
				okCircuits = await OrbotManager.shared.getCircuits(host: host)
			}

			// Store in-use circuits (identified by having a SOCKS username,
			// so the user can close them and get fresh ones on #newCircuits.
			usedCircuits = okCircuits

			nodes.removeAll()

			nodes.append(Node(title: CibulaL10n.tr("This browser", "Этот браузер", "Цей браузер")))

			for node in okCircuits.first?.nodes ?? [] {
				nodes.append(Node(node))
			}
			if nodes.count > 1 {
				nodes[1].note = CibulaL10n.tr("Entry", "Входной", "Вхідний")
			}

			nodes.append(Node(title: BrowsingViewController.prettyTitle(currentUrl)))

			await MainActor.run {
				tableView.reloadData()
			}
		}
	}


	// MARK: Private Methods

	/// White texts, blue buttons, glass instead of white, and the animated map instead of the old picture.
	private func styleForCibula() {
		view.backgroundColor = .clear
		tableView.backgroundColor = .clear
		noCircuitsView.backgroundColor = .clear

		headerLb.textColor = .white
		headerLb.font = .systemFont(ofSize: 17, weight: .bold)

		noCircuitsLb1.textColor = .white
		noCircuitsLb1.font = .systemFont(ofSize: 17, weight: .bold)

		noCircuitsLb2.textColor = Self.lilac
		noCircuitsLb2.font = .systemFont(ofSize: 15)
		noCircuitsLb2.adjustsFontSizeToFitWidth = true
		noCircuitsLb2.minimumScaleFactor = 0.8

		newCircuitsBt.backgroundColor = Self.blue
		newCircuitsBt.setTitleColor(.white, for: .normal)
		newCircuitsBt.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
		newCircuitsBt.titleLabel?.adjustsFontSizeToFitWidth = true
		newCircuitsBt.titleLabel?.minimumScaleFactor = 0.7
		newCircuitsBt.titleLabel?.lineBreakMode = .byTruncatingTail
		newCircuitsBt.layer.cornerRadius = 18
		newCircuitsBt.layer.cornerCurve = .continuous

		bridgeConfigBt.setTitleColor(Self.lilac, for: .normal)

		// The picture from the layout file stays as a place holder, the map lies exactly over it.
		if let picture = noCircuitsView.subviews.compactMap({ $0 as? UIImageView }).first {
			picture.isHidden = true
			picture.constraints.first(where: { $0.firstAttribute == .height })?.constant = 162

			let map = CibulaCircuitMapView()
			map.translatesAutoresizingMaskIntoConstraints = false
			noCircuitsView.addSubview(map)

			NSLayoutConstraint.activate([
				map.topAnchor.constraint(equalTo: picture.topAnchor),
				map.bottomAnchor.constraint(equalTo: picture.bottomAnchor),
				map.centerXAnchor.constraint(equalTo: picture.centerXAnchor),
				map.widthAnchor.constraint(equalTo: map.heightAnchor, multiplier: CibulaCircuitMapView.aspect)
			])

			mapView = map
		}
	}
}


/// A node of the circuit: a dot on a line, the country, the address, and, for the first one, a mark.
private final class CibulaCircuitCell: UITableViewCell {

	static let reuseId = "CibulaCircuitCell"
	static let height: CGFloat = 46

	private let blue = UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1)

	private let topLine = UIView()
	private let bottomLine = UIView()
	private let dot = UIView()
	private let titleLabel = UILabel()
	private let ipLabel = UILabel()
	private let noteLabel = CircuitNoteLabel()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)

		backgroundColor = .clear
		selectionStyle = .none

		let lineColor = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 0.55)

		for line in [topLine, bottomLine] {
			line.translatesAutoresizingMaskIntoConstraints = false
			line.backgroundColor = lineColor
			contentView.addSubview(line)
		}

		dot.translatesAutoresizingMaskIntoConstraints = false
		dot.backgroundColor = blue
		dot.layer.cornerRadius = 7
		dot.layer.borderWidth = 2
		dot.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
		contentView.addSubview(dot)

		titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
		titleLabel.textColor = .white
		titleLabel.lineBreakMode = .byTruncatingMiddle

		ipLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
		ipLabel.textColor = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 0.85)
		ipLabel.lineBreakMode = .byTruncatingMiddle

		let texts = UIStackView(arrangedSubviews: [titleLabel, ipLabel])
		texts.translatesAutoresizingMaskIntoConstraints = false
		texts.axis = .vertical
		texts.spacing = 1
		contentView.addSubview(texts)

		noteLabel.translatesAutoresizingMaskIntoConstraints = false
		noteLabel.font = .systemFont(ofSize: 12, weight: .bold)
		noteLabel.textColor = .white
		noteLabel.backgroundColor = blue
		noteLabel.layer.cornerRadius = 10
		noteLabel.layer.cornerCurve = .continuous
		noteLabel.clipsToBounds = true
		noteLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
		contentView.addSubview(noteLabel)

		NSLayoutConstraint.activate([
			dot.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
			dot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			dot.widthAnchor.constraint(equalToConstant: 14),
			dot.heightAnchor.constraint(equalToConstant: 14),

			topLine.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
			topLine.widthAnchor.constraint(equalToConstant: 3),
			topLine.topAnchor.constraint(equalTo: contentView.topAnchor),
			topLine.bottomAnchor.constraint(equalTo: dot.topAnchor),

			bottomLine.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
			bottomLine.widthAnchor.constraint(equalToConstant: 3),
			bottomLine.topAnchor.constraint(equalTo: dot.bottomAnchor),
			bottomLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

			texts.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 14),
			texts.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			texts.trailingAnchor.constraint(lessThanOrEqualTo: noteLabel.leadingAnchor, constant: -8),

			noteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
			noteLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			noteLabel.heightAnchor.constraint(equalToConstant: 20)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func set(_ node: CircuitViewController.Node, isFirst: Bool, isLast: Bool) {
		titleLabel.text = node.title

		ipLabel.text = node.ip
		ipLabel.isHidden = node.ip?.isEmpty ?? true

		noteLabel.text = node.note
		noteLabel.isHidden = node.note?.isEmpty ?? true

		topLine.isHidden = isFirst
		bottomLine.isHidden = isLast
	}
}


/// A label with some space around the text, for the little blue mark.
private final class CircuitNoteLabel: UILabel {

	override func drawText(in rect: CGRect) {
		super.drawText(in: rect.inset(by: UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 9)))
	}

	override var intrinsicContentSize: CGSize {
		let size = super.intrinsicContentSize

		return CGSize(width: size.width + 18, height: size.height)
	}
}


/**
The world map of the "no circuit" screen. Four points show up one after the other,
and a line is drawn from each one to the next.
*/
final class CibulaCircuitMapView: UIView {

	/// Width divided by height of the map picture.
	static let aspect: CGFloat = 520.0 / 337.0

	private let imageView = UIImageView()
	private var pins = [CAShapeLayer]()
	private var lines = [CAShapeLayer]()

	/// Where the four points lie on the map (share of the width and of the height).
	private let points: [CGPoint] = [
		CGPoint(x: 0.215, y: 0.33),
		CGPoint(x: 0.295, y: 0.60),
		CGPoint(x: 0.490, y: 0.28),
		CGPoint(x: 0.745, y: 0.42)]

	private let pinSize = CGSize(width: 20, height: 28)

	private let lineColor = UIColor(red: 0.20, green: 0.45, blue: 0.98, alpha: 1)
	private let pinColor = UIColor(red: 0.49, green: 0.83, blue: 0.13, alpha: 1)

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		imageView.frame = bounds

		let tips = points.map { CGPoint(x: $0.x * bounds.width, y: $0.y * bounds.height) }

		for (index, pin) in pins.enumerated() {
			pin.bounds = CGRect(origin: .zero, size: pinSize)
			pin.position = tips[index]
		}

		for (index, line) in lines.enumerated() {
			let from = tips[index]
			let to = tips[index + 1]

			// The lines bend, once to one side, then to the other.
			let middle = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
			let dx = to.x - from.x
			let dy = to.y - from.y
			let bend: CGFloat = index % 2 == 0 ? -0.28 : 0.28

			let control = CGPoint(x: middle.x - dy * bend, y: middle.y + dx * bend)

			let path = UIBezierPath()
			path.move(to: from)
			path.addQuadCurve(to: to, controlPoint: control)

			line.frame = bounds
			line.path = path.cgPath
		}
	}

	func startAnimation() {
		layoutIfNeeded()

		let begin = CACurrentMediaTime() + 0.2

		for layer in pins + lines {
			layer.removeAllAnimations()
		}

		for (index, pin) in pins.enumerated() {
			let time = begin + Double(index)

			let scale = CASpringAnimation(keyPath: "transform.scale")
			scale.fromValue = 0.1
			scale.toValue = 1
			scale.damping = 9
			scale.initialVelocity = 6
			scale.duration = scale.settlingDuration
			scale.beginTime = time
			scale.fillMode = .backwards

			let fade = CABasicAnimation(keyPath: "opacity")
			fade.fromValue = 0
			fade.toValue = 1
			fade.duration = 0.15
			fade.beginTime = time
			fade.fillMode = .backwards

			pin.add(scale, forKey: "scale")
			pin.add(fade, forKey: "fade")
		}

		for (index, line) in lines.enumerated() {
			let draw = CABasicAnimation(keyPath: "strokeEnd")
			draw.fromValue = 0
			draw.toValue = 1
			draw.duration = 0.6
			draw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
			draw.beginTime = begin + Double(index) + 0.3
			draw.fillMode = .backwards

			line.add(draw, forKey: "draw")
		}
	}

	private func setup() {
		layer.cornerRadius = 16
		layer.cornerCurve = .continuous
		clipsToBounds = true

		imageView.image = CibulaMapImage.image
		imageView.contentMode = .scaleToFill
		addSubview(imageView)

		// Lines first, so the points lie over them.
		for _ in 0 ..< points.count - 1 {
			let line = CAShapeLayer()
			line.fillColor = nil
			line.strokeColor = lineColor.cgColor
			line.lineWidth = 3
			line.lineCap = .round

			layer.addSublayer(line)
			lines.append(line)
		}

		for _ in points {
			let pin = CAShapeLayer()
			pin.path = pinPath().cgPath
			pin.fillColor = pinColor.cgColor
			pin.anchorPoint = CGPoint(x: 0.5, y: 1)

			let dot = CAShapeLayer()
			let radius: CGFloat = 4
			dot.path = UIBezierPath(ovalIn: CGRect(x: pinSize.width / 2 - radius, y: pinSize.width / 2 - radius,
												   width: radius * 2, height: radius * 2)).cgPath
			dot.fillColor = UIColor.white.cgColor
			pin.addSublayer(dot)

			layer.addSublayer(pin)
			pins.append(pin)
		}
	}

	/// A drop with the tip at the bottom.
	private func pinPath() -> UIBezierPath {
		let w = pinSize.width
		let h = pinSize.height

		let path = UIBezierPath()
		path.move(to: CGPoint(x: w / 2, y: h))
		path.addCurve(to: CGPoint(x: 0, y: w / 2),
					  controlPoint1: CGPoint(x: w * 0.15, y: h * 0.62),
					  controlPoint2: CGPoint(x: 0, y: w * 0.85))
		path.addArc(withCenter: CGPoint(x: w / 2, y: w / 2), radius: w / 2,
					startAngle: .pi, endAngle: 0, clockwise: true)
		path.addCurve(to: CGPoint(x: w / 2, y: h),
					  controlPoint1: CGPoint(x: w, y: w * 0.85),
					  controlPoint2: CGPoint(x: w * 0.85, y: h * 0.62))
		path.close()

		return path
	}
}


/// The world map (520 px JPEG, base64), so it needs no file of its own.
private enum CibulaMapImage {

	static let image: UIImage? = {
		guard let bytes = Data(base64Encoded: encoded) else {
			return nil
		}

		return UIImage(data: bytes)
	}()

	private static let encoded = "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+txzadBYjycTbYkYGNjIAbrz2ovclhmmL69cQMI+wOLgD+6y+PW1Imswisa6fE4hDh4DnuGupcNLzRF0LCIiAiIgIiICIiAiIgIiICIiAiIgIiICIiAiIgIiICIiAiIgIiICIiAiIgL6jYZJGsbrbiANnS+UQWMcbieEMOy9ZEVvJPb/ACg47bzH0HoPVQbLZS1l7brVx/M8jQA7NHoAtWSWSTl8R7nco03mO9D0XwsseLjO7TuURGhERapEREBERBlERWXERCoRIiIpSFYRFVSRZWFlEwwshFhSeSyVhZWEkkREUIEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREGVhZWFKZllFhE2bZRNrCJ2IiKFRERBlFhFO07ZWERQiZEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERAREQEREBERB/9k="
}

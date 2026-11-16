//
//  NcBookmarks.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 23.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

extension Notification.Name {

	/// Posted, whenever the bookmarks were stored. The start page shows them, so it must be rebuilt.
	static let cibulaBookmarksChanged = Notification.Name("CibulaBookmarksChanged")
}

class NcBookmarks {

	static var rootDir = FileManager.default.docsDir

	static var root: NcFolder = {

		// Migrate from old storage format.
		if let oldStorageFile,
		   let data = NSDictionary(contentsOf: oldStorageFile)
		{
			let root = NcFolder(id: -1, title: "")

			for d in data["bookmarks"] as? [NSDictionary] ?? [] {
				if let url = d["url"] as? String,
				   let title = d["name"] as? String
				{
					let b = NcBookmark(
						url: url,
						title: title,
						lastModified: Int(d["last_updated"] as? TimeInterval ?? Date().timeIntervalSince1970),
						folder: root,
						iconName: d["icon"] as? String)

					root.bookmarks.append(b)
				}
			}

			if let storageFile {
				// Written a second time here to avoid a circular call.
				do {
					try encoder.encode(root).write(to: storageFile, options: .atomic)
				}
				catch {
					Log.error(for: NcBookmarks.self, "\(error)")
				}

				// Successfully stored in new format. Remove old stuff.
				if storageFile.exists {
					try? FileManager.default.removeItem(at: oldStorageFile)
				}
			}

			if #available(iOS 18.0, *) {
				BookmarkEntity.add(folder: root)
			}

			return root
		}

		if let storageFile,
		   let data = try? Data(contentsOf: storageFile),
		   let root = try? PropertyListDecoder().decode(NcFolder.self, from: data)
		{

			if #available(iOS 18.0, *) {
				BookmarkEntity.add(folder: root)
			}

			return root
		}

		return .init(id: -1, title: "")
	}()


	private static let storageFile = rootDir?.appendingPathComponent("nc_bookmarks.plist")
	private static let oldStorageFile = rootDir?.appendingPathComponent("bookmarks.plist")

	private static let encoder = PropertyListEncoder()

	private static var startPageNeedsUpdate = true

	// The favorites of Cibula. Every address is written down once, here.
	private static let urlOnionMy = "https://onion.my/"
	private static let urlAhmia = "http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion/"
	private static let urlBbc = "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/"
	private static let urlProPublica = "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/"
	private static let urlLegalizer = "https://www.legalizer.cc/"
	private static let urlHiddenWiki = "http://bj5hp4onm4tvpdb5rzf4zsbwoons67jnastvuxefe4s3v7kupjhgh6qd.onion/"
	private static let urlSearchEngine = "http://37djtvjcpiprohcrlyvlhfil45kdlfizsyvilqskgvdrafn5mocz4cid.onion/"

	/// The favorites of Cibula, in this order.
	private static let defaultBookmarks: [NcBookmark] = {
		var defaults = [NcBookmark]()

		defaults.append(.init(url: urlOnionMy, title: "onion.my"))
		defaults.append(.init(url: urlAhmia, title: "Ahmia"))
		defaults.append(.init(url: urlBbc, title: "BBC"))
		defaults.append(.init(url: urlProPublica, title: "ProPublica"))
		defaults.append(.init(url: urlLegalizer, title: "Legalizer"))
		defaults.append(.init(url: urlHiddenWiki, title: "Hidden Wiki"))
		defaults.append(.init(url: urlSearchEngine, title: "Search Engine"))

		return defaults
	}()

	/// Which bundled icon belongs to which favorite.
	private static let iconKeys: [String: String] = [
		urlOnionMy: "onionmy",
		urlLegalizer: "legalizer",
		urlProPublica: "propublica",
		urlHiddenWiki: "hiddenwiki",
		urlSearchEngine: "searchengine"]

	/// Favorites of the older builds. They are removed once, when the current list takes over.
	private static let oldDefaultUrls: Set<String> = [
		"https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/",
		"http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/",
		"https://www.dwnewsgngmhlplxy6o2twtfgjnrnjxbegbwqx6wnotdhkzt562tszfid.onion/",
		"https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/",
		"https://onionbrowser.com",
		"http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/",
		"http://tordexu73joywapk2txdr54jed4imqledpcvcuf75qsas2gwdgksvnyd.onion/"]

	private static let cibulaDefaultsKey = "CibulaDefaultBookmarksV2"

	private static let v2ToV3 = [
		"https://3g2upl4pq6kufc4m.onion/": "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/",
		"https://bbcnewsv2vjtpsuy.onion/": "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/",
		"https://m.facebookcorewwwi.onion/": "https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/",
		"https://www.propub3r6espa33w.onion/": "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/",
		"https://freedom.press/": "http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/",
		"http://expyuzz4wqqyqhjn.onion/": "http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/"]


	// MARK: Public Methods

	class func store() {
		guard let storageFile else {
			return
		}

		// Trigger update of start page when things changed.
		startPageNeedsUpdate = true

		do {
			try encoder.encode(root).write(to: storageFile, options: .atomic)
		}
		catch {
			Log.error(for: Self.self, "\(error)")
		}

		NotificationCenter.default.post(name: .cibulaBookmarksChanged, object: nil)
	}

	class func updateStartPage(force: Bool = false) {
		migrateToCibulaDefaults()

		guard let source = Bundle.main.url(forResource: "start", withExtension: "html") else {
			return
		}

		// Always update after start. Language could have been changed.
		if !startPageNeedsUpdate && !force {
			if let dm = (try? URL.start.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
			   let sm = (try? source.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
			{
				if dm > sm {
					return
				}
			}
		}

		try? FileTranslator.translate(
			Bundle.main.url(forResource: "security-levels", withExtension: "html"),
			to: .securityLevels, with: "SecurityLevels")

		guard var template = try? String(contentsOf: source) else {
			return
		}

		if Settings.disableBookmarksOnStartPage {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "display: none")
		}
		else {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "")

			let bookmarks = root.bookmarks

			// Render bookmarks. The start page has room for 7 of them (and the "+" tile).
			for i in 0 ... 6 {
				let url: String
				let name: String
				let icon: UIImage

				if bookmarks.count > i {
					let tempUrl = bookmarks[i].url

					url = tempUrl

					name = bookmarks[i].title.isEmpty ? URL(string: url)?.host ?? "" : bookmarks[i].title
					icon = tileIcon(bookmarks[i].icon, name)
				}
				else {
					if i < defaultBookmarks.count {
						// Make sure that the default bookmarks are available!
						url = defaultBookmarks[i].url
						name = defaultBookmarks[i].title.isEmpty ? URL(string: url)?.host ?? "" : defaultBookmarks[i].title
						icon = tileIcon(defaultBookmarks[i].icon, name)
					}
					else {
						url = ""
						name = ""
						icon = NcBookmark.defaultIcon
					}
				}

				template = template
					.replacingOccurrences(of: "{{ bookmark_url_\(i) }}", with: url)
					.replacingOccurrences(of: "{{ bookmark_name_\(i) }}", with: name)
					.replacingOccurrences(of: "{{ bookmark_icon_\(i) }}",
						with: "data:image/png;base64,\(icon.pngData()?.base64EncodedString() ?? "")")
			}
		}

		template = template
			.replacingOccurrences(of: "{{ Onion Browser }}",
								  with: Bundle.main.displayName)
			.replacingOccurrences(of: "{{ Learn more about Onion Browser }}",
								  with: String(format: NSLocalizedString("Learn more about %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Donate to Onion Browser }}",
								  with: String(format: NSLocalizedString("Donate to %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Subscribe to Tor Newsletter }}",
								  with: NSLocalizedString("Subscribe to Tor Newsletter", comment: ""))

		try? template.write(to: URL.start, atomically: true, encoding: .utf8)

		startPageNeedsUpdate = false
	}

	class func firstRunSetup() {
		migrateToCibulaDefaults()

		guard !Settings.bookmarkFirstRunDone else {
			return
		}

		// Only set up default list of bookmarks, when there's no others.
		guard root.bookmarks.count < 1 else {
			Settings.bookmarkFirstRunDone = true

			return
		}

		root.bookmarks.append(contentsOf: defaultBookmarks)

		store()

		Task {
			await recurse(root) { bookmark in
				if await bookmark.acquireIcon() {
					store()
				}

				return false
			}

			Settings.bookmarkFirstRunDone = true
		}
	}

	class func migrateToV3() {
		guard !Settings.bookmarksMigratedToOnionV3 else {
			return
		}

		recurse(root) { bookmark in
			if let v3 = v2ToV3[bookmark.url]
			{
				bookmark.url = v3
			}

			return false
		}

		store()

		Settings.bookmarksMigratedToOnionV3 = true

		Task {
			await recurse(root) { bookmark in
				if await bookmark.acquireIcon() {
					store()
				}

				return false
			}
		}
	}

	/**
	Puts the favorites of Cibula to the top of the list and removes the ones the older builds came with.
	Bookmarks the user added himself stay. The icons come with the app, nothing is downloaded.
	Happens only once.
	*/
	class func migrateToCibulaDefaults() {
		let defaults = UserDefaults.standard

		guard !defaults.bool(forKey: cibulaDefaultsKey) else {
			return
		}

		defaults.set(true, forKey: cibulaDefaultsKey)

		let wanted = defaultBookmarks

		// Use bookmarks which exist already, create the missing ones.
		var ordered = [NcBookmark]()

		for item in wanted {
			if let existing = root.bookmarks.first(where: { $0.url == item.url }) {
				existing.title = item.title
				ordered.append(existing)
			}
			else {
				ordered.append(item)
			}
		}

		for bookmark in ordered {
			if let key = iconKeys[bookmark.url], let image = CibulaIcons.image(for: key) {
				bookmark.icon = image
			}
		}

		let others = root.bookmarks.filter { bookmark in
			!oldDefaultUrls.contains(bookmark.url) && !wanted.contains(where: { $0.url == bookmark.url })
		}

		root.bookmarks = ordered + others

		store()

		Settings.bookmarkFirstRunDone = true
	}

	class func find(_ lambda: (_ bookmark: NcBookmark) -> Bool) -> [NcBookmark] {
		return recurse(root, lambda)
	}

	class func find(_ url: URL) -> NcBookmark? {
		let url = url.absoluteString

		return find({ bookmark in
			return bookmark.url == url
		}).first
	}

	/// The icon of a bookmark for the start page. Tiny icons look blurry when enlarged, they get a colored letter instead.
	class func tileIcon(_ icon: UIImage?, _ name: String) -> UIImage {
		if let icon, icon.size.width * icon.scale >= 64 {
			return icon
		}

		return letterIcon(name)
	}


	// MARK: Private Methods

	/// A colored square with the first letter of the name, for bookmarks without a good icon.
	private class func letterIcon(_ name: String) -> UIImage {
		let palette: [(UInt32, UInt32)] = [
			(0x35D07F, 0x1B8F52),
			(0x8456C9, 0x3C1D70),
			(0x2F4A7D, 0x162340),
			(0xFF9A3D, 0xD4571A),
			(0x2FC7C7, 0x17807F),
			(0xE0509C, 0x9B2A6B),
			(0x5B8DEF, 0x2F4FB0)]

		func color(_ hex: UInt32) -> UIColor {
			UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
					green: CGFloat((hex >> 8) & 0xFF) / 255,
					blue: CGFloat(hex & 0xFF) / 255,
					alpha: 1)
		}

		// Stable choice of the colors: the same name always gets the same ones.
		let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
		let colors = palette[seed % palette.count]

		let letter = String(name.trimmingCharacters(in: .whitespaces).first ?? "•").uppercased()

		let size = CGSize(width: 128, height: 128)

		let format = UIGraphicsImageRendererFormat()
		format.scale = 1

		return UIGraphicsImageRenderer(size: size, format: format).image { context in
			let cg = context.cgContext

			// The whole square must be painted, also beyond the start and end of the gradient.
			color(colors.1).setFill()
			cg.fill(CGRect(origin: .zero, size: size))

			let gradient = CGGradient(
				colorsSpace: CGColorSpaceCreateDeviceRGB(),
				colors: [color(colors.0).cgColor, color(colors.1).cgColor] as CFArray,
				locations: [0, 1])

			if let gradient {
				cg.drawLinearGradient(gradient,
									  start: CGPoint(x: 0, y: 0),
									  end: CGPoint(x: size.width * 0.4, y: size.height),
									  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
			}

			let attributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 68, weight: .heavy),
				.foregroundColor: UIColor.white
			]

			let text = NSAttributedString(string: letter, attributes: attributes)
			let textSize = text.size()

			text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2))
		}
	}

	@discardableResult
	private class func recurse(_ folder: NcFolder, _ lambda: (_ bookmark: NcBookmark) async -> Bool) async -> NcBookmark? {
		for bookmark in folder.bookmarks {
			if await lambda(bookmark) {
				return bookmark
			}
		}

		for folder in folder.folders {
			if let bookmark = await recurse(folder, lambda) {
				return bookmark
			}
		}

		return nil
	}

	@discardableResult
	private class func recurse(_ folder: NcFolder, _ lambda: (_ bookmark: NcBookmark) -> Bool) -> [NcBookmark] {
		var result = [NcBookmark]()

		for bookmark in folder.bookmarks {
			if lambda(bookmark) {
				result.append(bookmark)
			}
		}

		for folder in folder.folders {
			result.append(contentsOf: recurse(folder, lambda))
		}

		return result
	}
}


/// Icons of the default favorites (112 px JPEG, base64), so they look the same without network.
enum CibulaIcons {

	static func image(for key: String) -> UIImage? {
		guard let text = data[key], let bytes = Data(base64Encoded: text) else {
			return nil
		}

		return UIImage(data: bytes)
	}

	private static let data: [String: String] = [
		"onionmy": "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAcFBQYFBAcGBgYIBwcICxILCwoKCxYPEA0SGhYbGhkWGRgcICgiHB4mHhgZIzAkJiorLS4tGyIyNTEsNSgsLSz/2wBDAQcICAsJCxULCxUsHRkdLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCwsLCz/wAARCABwAHADASIAAhEBAxEB/8QAHAABAQEAAwEBAQAAAAAAAAAAAAIBAwQFBgcI/8QAMhAAAQMDAwIDBwIHAAAAAAAAAQACAwQFEQYSITFBEyJRBxUyYXGBkSOhFBaCkrHR8P/EABkBAQEAAwEAAAAAAAAAAAAAAAABAgMFBP/EACgRAAIBAwMDBAIDAAAAAAAAAAABEQIhMQMEEkFhgRMiJJEy8FFxof/aAAwDAQACEQMRAD8A/m1FRkeRguOFOSgCIiAIiIAiIgCIiAIiIAi0OI6LCcoC37T8Ldv9WVO35j8rXY6d1KiIgiIqUIiIAiIgCIiAIiIAmEVMZuPxNH1OEIUyaRhyxxafUcI6olf8Ujj9SoJ7AnCxSESFmASSiYTCpkEWgZKEcoDETCYQBEwmEAWhrj0BP2WDhWJXgYDiFCOehJY5vVpH1WDg88LS4uPJJ+qfZACT0yuajpnVlZFTsIDpXBgz0yThQ6KVjcvieAe5BCuiqXUdZFUNALonh4B6ZBysap4vjkxqb4vjk+2/kO2S1stpp71uu8TXZgdAWsLmjLgH/nnHZdej0hZ3abp7vW3t1NHLI6FzBTlxDx2HPIx3XYOuLTFcpbzT2mZt3la4l758xB7hhx24zjrxlePWaho59JUVpipJY5oJ3TvldIC1xIwcDHHZcShbyqE21ifx/hz4xHU4NFO+qhN1K6n8Zw58Yjqd6j01T2zXLbXXV7Y3Mcx0LxD4rZC4gtBbx1B5Uu006766ulHJUQwR0z5ZZ5Wx7WtY0+YtYP8ACqbVlqrNYi9VVuqHMZHHtjZMAQ9gABzjpx0VyaztseqJ7pSW2ZsVaySOrjll3F4efNtIA2/ur8ueUPlx7RP74HzJ5Q+XDtCf74k69bpa1+7PeVtuzqqkhmbFUOfAY3R7uhAz5u/4XqVPs8twrX26mvokuBg8eKF0BaHN27uXZODjJwvLrNTWhtoNrtttnp6WeZstT4s297tvQNOAB37LsnW9E3XEV8joJhCyn8AwmQFx8hZnOPTCjW9a9rdpieN8Qn/uOhKlvmva3aYnjfEJ+Zx0PjBH+pt7ZX6DF7Ore6ggqZb4yHNOypna6I5jY8cEevPC+V96Wsadmo/dua50+9lWXctZx5cf91Xtz65gloZacUb2mS3Q0Wd46sdnd9/RejdPc1x6M03vjFr9e56d293qR6M03vjFr9e/0c1L7OX/AMfcYqyqe2KikbGXU8LpnOLhkYaO2Op7LxNV6YOnZqZzZnSwVTC+MyRGJ/BwdzDyOV749olPLcrnJNSVLKWueyQCnqPDlY5rQ34x2wDxheTWmXWd4jgtMFR+nEcCqqvEce5O5xAH0C06Fe7p1FXuHFMXxGPvJp29e8p1FXuXFKV8Rj7yfKqmu5AyQPkvoLnom9WqgkrKqmYyCPG5wmY7GTjoDleHFSzzML44JJGtOCWtJAXWo1tPVp5UVJo7Gnr6WrTyoqTX9kySh4x4bR8wT/tcfCt29mWkAfYKdxxjj8LauxtXYzKIipkMplEQDKIiAIiIBlU15aeDhSiAt0rnDlxKkOd2JWLQCSpBISOUU0smXNbn7hS6CRp5b+4UH6Bb4h9G/wBoUuT3GEEdVi0knrj8LFkZBERAEREAREQBAcIiAovBAAY0fMZWZysWjPzUJBckb2nzADPoQVxoiIIIiKlCIiAIiIAiIgCIiAKhtxzuz8lKDqgP/9k=",
		"searchengine": "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",
		"legalizer": "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",
		"hiddenwiki": "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",
		"propublica": "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"
	]
}

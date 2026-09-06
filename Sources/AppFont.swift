import AppKit

enum AppFont {
    static var useComic: Bool { (UserDefaults.standard.object(forKey: "comicFont") as? Bool) ?? true }
    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if useComic, let font = NSFont(name: "ComicSansMS", size: size) ?? NSFont(name: "Comic Sans MS", size: size) { return font }
        return .systemFont(ofSize: size, weight: weight)
    }
    static func apply(to view: NSView?) {
        guard let view else { return }
        if let control = view as? NSControl { control.font = font(control.font?.pointSize ?? 13) }
        if let text = view as? NSTextView { text.font = font(text.font?.pointSize ?? 13) }
        view.subviews.forEach { apply(to: $0) }
    }
}

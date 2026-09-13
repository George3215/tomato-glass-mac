import AppKit
import CoreText

enum AppFont {
    private static let registered: Void = {
        for name in ["ComicNeue-Regular", "ComicNeue-Bold", "LXGWWenKaiLite-Regular"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }()
    static var useComic: Bool { (UserDefaults.standard.object(forKey: "comicFont") as? Bool) ?? true }
    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        _ = registered
        if useComic, let font = NSFont(name: weight >= .medium ? "ComicNeue-Bold" : "ComicNeue-Regular", size: size) {
            if let chinese = NSFont(name: "LXGWWenKaiLite-Regular", size: size) {
                let descriptor = font.fontDescriptor.addingAttributes([.cascadeList: [chinese.fontDescriptor]])
                return NSFont(descriptor: descriptor, size: size) ?? font
            }
            return font
        }
        return .systemFont(ofSize: size, weight: weight)
    }
    static func apply(to view: NSView?) {
        guard let view else { return }
        if let control = view as? NSControl, control.identifier?.rawValue != "tabular-timer" { control.font = font(control.font?.pointSize ?? 13, weight: control.font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) ? .bold : .regular } ?? .regular) }
        if let text = view as? NSTextView { text.font = font(text.font?.pointSize ?? 13) }
        view.subviews.forEach { apply(to: $0) }
    }
}

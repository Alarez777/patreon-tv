//
//  PostBody.swift
//  PatreonTV
//
//  Picks the post body from the two formats Patreon returns: legacy HTML
//  (`content`) and ProseMirror JSON (`content_json_string`). Prefers HTML so
//  existing formatting keeps working.
//

import Foundation

enum PostBody {

    /// Plain text for consumers like chapters and the player info panel.
    static func plainText(_ attributes: Post.Attributes) -> String? {
        if let html = attributes.content, !html.isEmpty {
            return HTMLRenderer.stripToPlainText(html)
        }
        if let json = attributes.contentJSONString,
           let text = ProseMirrorRenderer.plainText(from: json),
           !text.isEmpty {
            return text
        }
        return nil
    }

    /// Rich body for display. HTML goes through the Markdown renderer;
    /// ProseMirror becomes a plain AttributedString.
    static func attributed(_ attributes: Post.Attributes) -> AttributedString? {
        if let html = attributes.content, !html.isEmpty {
            return HTMLRenderer.attributedString(from: html)
        }
        if let json = attributes.contentJSONString,
           let text = ProseMirrorRenderer.plainText(from: json),
           !text.isEmpty {
            return AttributedString(text)
        }
        return nil
    }

    /// Raw-ish body for tag-stripping parsers (chapters). Falls back to the
    /// flattened ProseMirror text when `content` is null.
    static func source(_ attributes: Post.Attributes) -> String? {
        if let html = attributes.content, !html.isEmpty { return html }
        guard let json = attributes.contentJSONString else { return nil }
        return ProseMirrorRenderer.plainText(from: json)
    }
}

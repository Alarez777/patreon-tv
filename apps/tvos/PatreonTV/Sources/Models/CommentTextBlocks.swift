//
//  CommentTextBlocks.swift
//  PatreonTV
//
//  Splits a long comment body into reading-sized chunks so each chunk can be
//  its own tvOS focus target. A focused row taller than the screen can't be
//  scrolled with the D-pad; small focusable blocks let the viewer read down.
//

import Foundation

enum CommentTextBlocks {

    /// Splits attributed text at whitespace boundaries, keeping attributes.
    /// Blocks never exceed `maxCharacters` unless a single word is longer.
    static func split(_ text: AttributedString, maxCharacters: Int = 260) -> [AttributedString] {
        guard maxCharacters > 0 else { return [text] }

        let characters = text.characters
        guard !characters.isEmpty else { return [] }

        var blocks: [AttributedString] = []
        var start = characters.startIndex
        var cursor = start
        var lastWhitespace: AttributedString.Index?
        var count = 0

        while cursor < characters.endIndex {
            let character = characters[cursor]
            count += 1
            if character.isWhitespace {
                lastWhitespace = cursor
            }

            if count >= maxCharacters {
                let cut: AttributedString.Index
                if let lastWhitespace, lastWhitespace > start {
                    cut = lastWhitespace
                } else {
                    cut = cursor
                }
                // Include the whitespace at the cut in this block.
                let end = characters.index(after: cut)
                blocks.append(AttributedString(text[start..<end]))
                start = end
                cursor = end
                count = 0
                lastWhitespace = nil
                continue
            }

            cursor = characters.index(after: cursor)
        }

        if start < characters.endIndex {
            blocks.append(AttributedString(text[start..<characters.endIndex]))
        }
        return blocks
    }
}

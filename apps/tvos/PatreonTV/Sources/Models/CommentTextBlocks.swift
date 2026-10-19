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

    /// Splits attributed text first at line breaks, then at whitespace for
    /// lines longer than `maxCharacters`. Blocks keep the original attributes.
    static func split(_ text: AttributedString, maxCharacters: Int = 260) -> [AttributedString] {
        guard maxCharacters > 0 else { return [text] }

        return lines(in: text).flatMap { line in
            splitLine(line, maxCharacters: maxCharacters)
        }
    }

    /// Character ranges between newlines. Whitespace-only lines are dropped;
    /// the line break itself is represented by separating blocks.
    private static func lines(in text: AttributedString) -> [AttributedString] {
        let characters = text.characters
        var result: [AttributedString] = []
        var start = characters.startIndex
        var cursor = start

        while cursor < characters.endIndex {
            if characters[cursor].isNewline {
                if start < cursor {
                    let line = AttributedString(text[start..<cursor])
                    if line.characters.contains(where: { !$0.isWhitespace }) {
                        result.append(line)
                    }
                }
                cursor = characters.index(after: cursor)
                start = cursor
                continue
            }
            cursor = characters.index(after: cursor)
        }

        if start < characters.endIndex {
            let line = AttributedString(text[start..<characters.endIndex])
            if line.characters.contains(where: { !$0.isWhitespace }) {
                result.append(line)
            }
        }
        return result
    }

    private static func splitLine(_ line: AttributedString, maxCharacters: Int) -> [AttributedString] {
        let characters = line.characters
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
                blocks.append(AttributedString(line[start..<end]))
                start = end
                cursor = end
                count = 0
                lastWhitespace = nil
                continue
            }

            cursor = characters.index(after: cursor)
        }

        if start < characters.endIndex {
            blocks.append(AttributedString(line[start..<characters.endIndex]))
        }
        return blocks
    }
}

//
//  CommentTextBlocks.swift
//  PatreonTV
//
//  Splits a long comment body into reading-sized chunks so each chunk can be
//  its own tvOS focus target. Blocks stay large (~20 lines) and keep their
//  internal line breaks, so paragraphs read naturally. Long lines prefer a
//  nearby sentence/clause boundary, and list/heading markers start a new block
//  when they land near the limit.
//

import Foundation

enum CommentTextBlocks {

    static func split(
        _ text: AttributedString,
        maxLines: Int = 20,
        maxCharacters: Int = 1200
    ) -> [AttributedString] {
        guard maxLines > 0, maxCharacters > 0 else { return [text] }

        let lines = logicalLines(in: text)
        guard !lines.isEmpty else { return [] }

        var blocks: [AttributedString] = []
        var firstLine: Int?
        var lastLine: Int?
        var lineCount = 0
        var characterCount = 0

        func flushBlock() {
            if let firstLine, let lastLine {
                appendBlock(
                    from: lines[firstLine],
                    to: lines[lastLine],
                    of: text,
                    into: &blocks
                )
            }
            firstLine = nil
            lastLine = nil
            lineCount = 0
            characterCount = 0
        }

        for (index, line) in lines.enumerated() {
            let length = text.characters.distance(from: line.lowerBound, to: line.upperBound)
            let nearLimit = lineCount >= max(0, maxLines - 2)
                || characterCount >= maxCharacters * 4 / 5

            // A bullet or heading that lands near the limit starts the next
            // block, so the marker stays with its content.
            if startsWithMarker(text, range: line), nearLimit, lineCount > 0 {
                flushBlock()
            }

            if lineCount + 1 > maxLines || characterCount + length > maxCharacters {
                flushBlock()
            }

            if length > maxCharacters {
                // One line too large for any block: split it at sentences,
                // clauses, or whitespace.
                let lineText = AttributedString(text[line])
                blocks.append(contentsOf: splitLongLine(lineText, maxCharacters: maxCharacters))
                continue
            }

            if firstLine == nil {
                firstLine = index
            }
            lastLine = index
            lineCount += 1
            characterCount += length + 1
        }

        flushBlock()
        return blocks
    }

    // MARK: - Lines

    private static func logicalLines(in text: AttributedString) -> [Range<AttributedString.Index>] {
        let characters = text.characters
        var result: [Range<AttributedString.Index>] = []
        var start = characters.startIndex
        var cursor = start

        while cursor < characters.endIndex {
            if characters[cursor].isNewline {
                result.append(start..<cursor)
                cursor = characters.index(after: cursor)
                start = cursor
                continue
            }
            cursor = characters.index(after: cursor)
        }

        if start < characters.endIndex {
            result.append(start..<characters.endIndex)
        }
        return result
    }

    /// True when the first non-space character is a bullet/heading marker
    /// (`-`, `*`, `#`) or an ordered-list number (`1.`, `2)`).
    private static func startsWithMarker(
        _ text: AttributedString,
        range: Range<AttributedString.Index>
    ) -> Bool {
        let characters = text.characters
        var index = range.lowerBound
        while index < range.upperBound, characters[index].isWhitespace {
            index = characters.index(after: index)
        }
        guard index < range.upperBound else { return false }

        let first = characters[index]
        if first == "-" || first == "*" || first == "#" {
            return true
        }

        guard first.isNumber else { return false }
        var cursor = index
        while cursor < range.upperBound, characters[cursor].isNumber {
            cursor = characters.index(after: cursor)
        }
        guard cursor < range.upperBound else { return false }
        return characters[cursor] == "." || characters[cursor] == ")"
    }

    private static func appendBlock(
        from first: Range<AttributedString.Index>,
        to last: Range<AttributedString.Index>,
        of text: AttributedString,
        into blocks: inout [AttributedString]
    ) {
        guard first.lowerBound < last.upperBound else { return }
        let block = AttributedString(text[first.lowerBound..<last.upperBound])
        guard block.characters.contains(where: { !$0.isWhitespace }) else { return }
        blocks.append(block)
    }

    // MARK: - Long lines

    private static func splitLongLine(
        _ text: AttributedString,
        maxCharacters: Int
    ) -> [AttributedString] {
        let characters = text.characters
        guard !characters.isEmpty else { return [] }

        let lookback = max(50, maxCharacters / 5)
        var blocks: [AttributedString] = []
        var start = characters.startIndex
        var cursor = start
        var count = 0

        while cursor < characters.endIndex {
            count += 1
            if count >= maxCharacters {
                let cut = preferredCut(
                    in: characters,
                    start: start,
                    cursor: cursor,
                    lookback: lookback
                )
                let end = characters.index(after: cut)
                blocks.append(AttributedString(text[start..<end]))
                start = end
                cursor = end
                count = 0
                continue
            }
            cursor = characters.index(after: cursor)
        }

        if start < characters.endIndex {
            blocks.append(AttributedString(text[start..<characters.endIndex]))
        }
        return blocks
    }

    /// Latest boundary near the limit: sentence end first, then clause
    /// punctuation, then any whitespace.
    private static func preferredCut(
        in characters: AttributedString.CharacterView,
        start: AttributedString.Index,
        cursor: AttributedString.Index,
        lookback: Int
    ) -> AttributedString.Index {
        var sentence: AttributedString.Index?
        var clause: AttributedString.Index?
        var whitespace: AttributedString.Index?

        var index = cursor
        var distance = 0

        while index > start, distance <= lookback {
            let character = characters[index]
            if character.isWhitespace {
                if whitespace == nil {
                    whitespace = index
                }

                var previous = characters.index(before: index)
                while previous > start, characters[previous].isWhitespace {
                    previous = characters.index(before: previous)
                }

                if sentence == nil, characters[previous] == "." || characters[previous] == "?"
                    || characters[previous] == "!" {
                    sentence = index
                } else if clause == nil, characters[previous] == "," || characters[previous] == ";"
                    || characters[previous] == ":" {
                    clause = index
                }
            }

            index = characters.index(before: index)
            distance += 1
        }

        return sentence ?? clause ?? whitespace ?? cursor
    }
}

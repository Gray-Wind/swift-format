//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import SwiftSyntax

/// Extracts and returns the body text of a documentation comment represented as a trivia
/// collection.
///
/// This function should be used when only the text of the comment is important, not the structural
/// organization. It automatically handles trimming leading indentation from comments as well as
/// "ASCII art" in block comments (i.e., leading asterisks on each line).
///
/// This implementation is based on
/// https://github.com/apple/swift/blob/main/lib/Markup/LineList.cpp.
///
/// - Parameter trivia: The trivia collection from which to extract the comment text.
/// - Returns: If a comment was found, a tuple containing the `String` containing the extracted text
///   and the index into the trivia collection where the comment began is returned. Otherwise, `nil`
///   is returned.
public func documentationCommentText(extractedFrom trivia: Trivia)
  -> (text: String, startIndex: Trivia.Index)?
{
  /// Represents a line of text and its leading indentation.
  struct Line {
    var text: Substring
    var firstNonspaceDistance: Int
    
    init(_ text: Substring) {
      self.text = text
      self.firstNonspaceDistance = indentationDistance(of: text)
    }
  }

  // Look backwards from the end of the trivia collection to find the logical start of the comment.
  // We have to copy it into an array since `Trivia` doesn't support bidirectional indexing.
  let triviaArray = Array(trivia)
  let commentStartIndex: Array<TriviaPiece>.Index
  if
    let lastNonDocCommentIndex = triviaArray.lastIndex(where: {
      switch $0 {
      case .docBlockComment, .docLineComment,
          .newlines(1), .carriageReturns(1), .carriageReturnLineFeeds(1),
          .spaces, .tabs:
        return false
      default:
        return true
      }
    }),
    lastNonDocCommentIndex != trivia.endIndex
  {
    commentStartIndex = triviaArray.index(after: lastNonDocCommentIndex)
  } else {
    commentStartIndex = triviaArray.startIndex
  }

  // Determine the indentation level of the first line of the comment. This is used to adjust
  // block comments, whose text spans multiple lines.
  let leadingWhitespace = contiguousWhitespace(in: triviaArray, before: commentStartIndex)
  var lines = [Line]()
  
  // Extract the raw lines of text (which will include their leading comment punctuation, which is
  // stripped).
  for triviaPiece in trivia[commentStartIndex...] {
    switch triviaPiece {
    case .docLineComment(let line):
      lines.append(Line(line.dropFirst(3)))

    case .docBlockComment(let line):
      var cleaned = line.dropFirst(3)
      if cleaned.hasSuffix("*/") {
        cleaned = cleaned.dropLast(2)
      }
      
      var hasASCIIArt = false
      if cleaned.hasPrefix("\n") {
        cleaned = cleaned.dropFirst()
        hasASCIIArt = asciiArtLength(of: cleaned, leadingSpaces: leadingWhitespace) != 0
      }
      
      while !cleaned.isEmpty {
        var index = cleaned.firstIndex(where: \.isNewline) ?? cleaned.endIndex
        if hasASCIIArt {
          cleaned = cleaned.dropFirst(asciiArtLength(of: cleaned, leadingSpaces: leadingWhitespace))
          index = cleaned.firstIndex(where: \.isNewline) ?? cleaned.endIndex
        }

        // Don't add an unnecessary blank line at the end when `*/` is on its own line.
        guard cleaned.firstIndex(where: { !$0.isWhitespace }) != nil else {
          break
        }

        let line = cleaned.prefix(upTo: index)
        lines.append(Line(line))
        cleaned = cleaned[index...].dropFirst()
      }

    default:
      break
    }
  }

  // Concatenate the lines into a single string, trimming any leading indentation that might be
  // present.
  guard
    !lines.isEmpty,
    let firstLineIndex = lines.firstIndex(where: { !$0.text.isEmpty })
  else { return nil }

  let initialIndentation = indentationDistance(of: lines[firstLineIndex].text)
  var result = ""
  for line in lines[firstLineIndex...] {
    let countToDrop = min(initialIndentation, line.firstNonspaceDistance)
    result.append(contentsOf: "\(line.text.dropFirst(countToDrop))\n")
  }

  guard !result.isEmpty else { return nil }

  let commentStartDistance =
    triviaArray.distance(from: triviaArray.startIndex, to: commentStartIndex)
  return (text: result, startIndex: trivia.index(trivia.startIndex, offsetBy: commentStartDistance))
}

/// Returns the distance from the start of the string to the first non-whitespace character.
private func indentationDistance(of text: Substring) -> Int {
  return text.distance(
    from: text.startIndex,
    to: text.firstIndex { !$0.isWhitespace } ?? text.endIndex)
}

/// Returns the number of contiguous whitespace characters (spaces and tabs only) that precede the
/// given trivia piece.
private func contiguousWhitespace(
  in trivia: [TriviaPiece],
  before index: Array<TriviaPiece>.Index
) -> Int {
  var index = index
  var whitespace = 0
  loop: while index != trivia.startIndex {
    index = trivia.index(before: index)
    switch trivia[index] {
    case .spaces(let count): whitespace += count
    case .tabs(let count): whitespace += count
    default: break loop
    }
  }
  return whitespace
}

/// Returns the number of characters considered block comment "ASCII art" at the beginning of the
/// given string.
private func asciiArtLength(of string: Substring, leadingSpaces: Int) -> Int {
  let spaces = string.prefix(leadingSpaces)
  if spaces.count != leadingSpaces {
    return 0
  }
  if spaces.contains(where: { !$0.isWhitespace }) {
    return 0
  }

  let string = string.dropFirst(leadingSpaces)
  if string.hasPrefix(" * ") {
    return leadingSpaces + 3
  }
  if string.hasPrefix(" *\n") {
    return leadingSpaces + 2
  }
  return 0
}

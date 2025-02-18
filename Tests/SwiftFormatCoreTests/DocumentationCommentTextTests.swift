import SwiftFormatCore
import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

final class DocumentationCommentTextTests: XCTestCase {
  func testSimpleDocLineComment() throws {
    let decl: DeclSyntax = """
      /// A simple doc comment.
      func f() {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A simple doc comment.
      
      """
    )
  }
  
  func testOneLineDocBlockComment() throws {
    let decl: DeclSyntax = """
      /** A simple doc comment. */
      func f() {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A simple doc comment.\u{0020}
      
      """
    )
  }
  
  func testDocBlockCommentWithASCIIArt() throws {
    let decl: DeclSyntax = """
      /**
       * A simple doc comment.
       */
      func f() {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A simple doc comment.
      
      """
    )
  }
  
  func testDocBlockCommentWithoutASCIIArt() throws {
    let decl: DeclSyntax = """
      /**
         A simple doc comment.
       */
      func f() {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A simple doc comment.
      
      """
    )
  }
  
  func testMultilineDocLineComment() throws {
    let decl: DeclSyntax = """
      /// A doc comment.
      ///
      /// This is a longer paragraph,
      /// containing more detail.
      ///
      /// - Parameter x: A parameter.
      /// - Returns: A value.
      func f(x: Int) -> Int {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A doc comment.
      
      This is a longer paragraph,
      containing more detail.
      
      - Parameter x: A parameter.
      - Returns: A value.
      
      """
    )
  }
  
  func testDocLineCommentStopsAtBlankLine() throws {
    let decl: DeclSyntax = """
      /// This should not be part of the comment.
      
      /// A doc comment.
      func f(x: Int) -> Int {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      A doc comment.
      
      """
    )
  }
  
  func testDocBlockCommentStopsAtBlankLine() throws {
    let decl: DeclSyntax = """
      /** This should not be part of the comment. */
      
      /**
       * This is part of the comment.
       */
      /** so is this */
      func f(x: Int) -> Int {}
      """
    XCTAssertEqual(
      documentationCommentText(extractedFrom: decl.leadingTrivia)?.text,
      """
      This is part of the comment.
       so is this\u{0020}
      
      """
    )
  }

  func testNilIfNoComment() throws {
    let decl: DeclSyntax = """
      func f(x: Int) -> Int {}
      """
    XCTAssertNil(documentationCommentText(extractedFrom: decl.leadingTrivia))
  }
}

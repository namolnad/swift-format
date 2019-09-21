//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftFormatCore
import SwiftSyntax

/// Function calls with no arguments and a trailing closure should not have empty parentheses.
///
/// Lint: If a function call with a trailing closure has an empty argument list with parentheses,
///       a lint error is raised.
///
/// Format: Empty parentheses in function calls with trailing closures will be removed.
///
/// - SeeAlso: https://google.github.io/swift#trailing-closures
public final class NoEmptyTrailingClosureParentheses: SyntaxFormatRule {

  public override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
    guard node.argumentList.isEmpty else { return node }

    guard node.trailingClosure != nil && node.argumentList.isEmpty && node.leftParen != nil else {
      return node
    }
    guard let name = node.calledExpression.lastToken?.withoutTrivia() else {
      return node
    }

    diagnose(.removeEmptyTrailingParentheses(name: "\(name)"), on: node)

    let formattedExp = replaceTrivia(
      on: node.calledExpression,
      token: node.calledExpression.lastToken,
      trailingTrivia: .spaces(1)) as! ExprSyntax
    return node.withLeftParen(nil).withRightParen(nil).withCalledExpression(formattedExp)
  }
}

extension Diagnostic.Message {
  static func removeEmptyTrailingParentheses(name: String) -> Diagnostic.Message {
    return .init(.warning, "remove '()' after \(name)")
  }
}

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

/// Specifying an access level for an extension declaration is forbidden.
///
/// Lint: Specifying an access level for an extension declaration yields a lint error.
///
/// Format: The access level is removed from the extension declaration and is added to each
///         declaration in the extension; declarations with redundant access levels (e.g.
///         `internal`, as that is the default access level) have the explicit access level removed.
///
/// TODO: Find a better way to access modifiers and keyword tokens besides casting each declaration
///
/// - SeeAlso: https://google.github.io/swift#access-levels
public final class NoAccessLevelOnExtensionDeclaration: SyntaxFormatRule {

  public override func visit(_ node: ExtensionDeclSyntax) -> DeclSyntax {
    guard let modifiers = node.modifiers, !modifiers.isEmpty else { return node }
    guard let accessKeyword = modifiers.accessLevelModifier else { return node }

    let keywordKind = accessKeyword.name.tokenKind
    switch keywordKind {
    // Public, private, or fileprivate keywords need to be moved to members
    case .publicKeyword, .privateKeyword, .fileprivateKeyword:
      diagnose(.moveAccessKeyword(keyword: accessKeyword.name.text), on: accessKeyword)

      // The effective access level of the members of a `private` extension is `fileprivate`, so
      // we have to update the keyword to ensure that the result is correct.
      let accessKeywordToAdd: DeclModifierSyntax
      if keywordKind == .privateKeyword {
        accessKeywordToAdd
          = accessKeyword.withName(accessKeyword.name.withKind(.fileprivateKeyword))
      } else {
        accessKeywordToAdd = accessKeyword
      }

      let newMembers = SyntaxFactory.makeMemberDeclBlock(
        leftBrace: node.members.leftBrace,
        members: addMemberAccessKeywords(memDeclBlock: node.members, keyword: accessKeywordToAdd),
        rightBrace: node.members.rightBrace)
      let newKeyword = replaceTrivia(
        on: node.extensionKeyword,
        token: node.extensionKeyword,
        leadingTrivia: accessKeyword.leadingTrivia) as! TokenSyntax
      return node.withMembers(newMembers)
        .withModifiers(modifiers.remove(name: accessKeyword.name.text))
        .withExtensionKeyword(newKeyword)

    // Internal keyword redundant, delete
    case .internalKeyword:
      diagnose(
        .removeRedundantAccessKeyword(name: node.extendedType.description),
        on: accessKeyword)
      let newKeyword = replaceTrivia(
        on: node.extensionKeyword,
        token: node.extensionKeyword,
        leadingTrivia: accessKeyword.leadingTrivia) as! TokenSyntax
      return node.withModifiers(modifiers.remove(name: accessKeyword.name.text))
        .withExtensionKeyword(newKeyword)

    default:
      break
    }
    return node
  }

  // Adds given keyword to all members in declaration block
  func addMemberAccessKeywords(
    memDeclBlock: MemberDeclBlockSyntax,
    keyword: DeclModifierSyntax
  ) -> MemberDeclListSyntax {
    var newMembers: [MemberDeclListItemSyntax] = []
    let formattedKeyword = replaceTrivia(
      on: keyword,
      token: keyword.name,
      leadingTrivia: [])
      as! DeclModifierSyntax

    for memberItem in memDeclBlock.members {
      let member = memberItem.decl
      guard
        // addModifier relocates trivia for any token(s) displaced by the new modifier.
        let newDecl = addModifier(declaration: member, modifierKeyword: formattedKeyword)
        as? DeclSyntax
      else { continue }
      newMembers.append(memberItem.withDecl(newDecl))
    }
    return SyntaxFactory.makeMemberDeclList(newMembers)
  }
}

extension Diagnostic.Message {
  static func removeRedundantAccessKeyword(name: String) -> Diagnostic.Message {
    return .init(.warning, "remove redundant 'internal' access keyword from \(name)")
  }

  static func moveAccessKeyword(keyword: String) -> Diagnostic.Message {
    return .init(.warning, "specify \(keyword) access level for each member inside the extension")
  }
}

import AppKit

/// Outline view cannot work with structs, identifiers are necessary for diffing and diagnostics, hashing is necessary for supporting drag-n-drop and expand-collapse.
public protocol OutlineViewItem: Hashable, Identifiable {

  /// Used to allow or deny selection for this item.
  var isSelectable: Bool { get }

  /// Used to show or hide the expansion arrow.
  var isExpandable: Bool { get }

  /// Can be used for root items with ‘Show’ and ‘Hide’ buttons.
  var isGroup: Bool { get }
}

// MARK: -

public extension OutlineViewItem {

  /// Any item can be selected by default.
  var isSelectable: Bool { true }

  /// Any item can be expanded and collapsed by default.
  var isExpandable: Bool { true }

  /// No group items by default.
  var isGroup: Bool { false }
}

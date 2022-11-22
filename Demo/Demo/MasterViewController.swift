import AppKit
import Combine
import SwiftUI
import OutlineViewDiffableDataSource

/// Sidebar contents.
final class MasterViewController: NSViewController {

  /// An outline view enclosed into the scroll view.
  private lazy var scrollableOutlineView: (scrollView: NSScrollView, outlineView: NSOutlineView) = {

    let outlineColumn = NSTableColumn()
    outlineColumn.resizingMask = .autoresizingMask
    outlineColumn.isEditable = false

    let outlineView = NSOutlineView()
    outlineView.headerView = nil
    outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    outlineView.addTableColumn(outlineColumn)
    outlineView.outlineTableColumn = outlineColumn
    outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    outlineView.focusRingType = .none
    outlineView.allowsMultipleSelection = true
    outlineView.usesAutomaticRowHeights = true
    outlineView.selectionHighlightStyle = .sourceList
    outlineView.floatsGroupRows = false

    let scrollView = NSScrollView()
    scrollView.documentView = outlineView
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    return (scrollView, outlineView)
  }()

  /// Diffable data source similar to `NSCollectionViewDiffableDataSource`.
  private lazy var dataSource: OutlineViewDiffableDataSource = {
    let source = OutlineViewDiffableDataSource(outlineView: scrollableOutlineView.outlineView)
    source.draggingHandlers = OutlineViewDiffableDataSource.DraggingHandlers(validateDrop: { _, drop in

      // Option-, Control- and Command- modifiers are disabled
      guard drop.operation.contains(.move) else { return nil }

      // Dragging on, before and after self is denied
      guard drop.draggedItems.allSatisfy({ $0 !== drop.targetItem }) else { return nil }

      return drop
    }, acceptDrop: { sender, drop in

      var snapshot = sender.snapshot()
      snapshot.deleteItems(drop.draggedItems)
      switch drop.type {
      case .on:
        snapshot.appendItems(drop.draggedItems, into: drop.targetItem)
      case .before:
        snapshot.insertItems(drop.draggedItems, beforeItem: drop.targetItem)
      case .after:
        snapshot.insertItems(drop.draggedItems, afterItem: drop.targetItem)
      }
      sender.apply(snapshot, animatingDifferences: shouldAnimate)
      return true
    })
    return source
  }()
}

// MARK: -

extension MasterViewController {

  /// Master is a container for the scroll view.
  override func loadView() {
    view = scrollableOutlineView.scrollView
  }
}

// MARK: - Internal API

extension MasterViewController {

  /// Read-write snapshot of the sidebar data.
  var snapshotBinding: Binding<DiffableDataSourceSnapshot> {
    .init(get: { [dataSource] in
      dataSource.snapshot()
    }, set: { [dataSource] snapshot in
      dataSource.apply(snapshot, animatingDifferences: shouldAnimate)
    })
  }

  /// Read-only selection.
  var selectionPublisher: AnyPublisher<[MasterOutlineViewItem], Never> {
    NotificationCenter.default
      .publisher(for: NSOutlineView.selectionDidChangeNotification, object: scrollableOutlineView.outlineView)
      .compactMap { notification in notification.object as? NSOutlineView }
      .map { outlineView in
        outlineView.selectedRowIndexes.compactMap { selectedRow in
          outlineView.item(atRow: selectedRow) as? MasterOutlineViewItem
        }
      }
      .eraseToAnyPublisher()
  }
}

// MARK: - Actions

extension MasterViewController {

  /// Expands all outline view items.
  @IBAction func expandAllItems(_ sender: Any?) {
    NSAnimationContext.runAnimationGroup { context in
      if shouldAnimate == false { context.duration = 0 }
      scrollableOutlineView.outlineView.animator().expandItem(nil, expandChildren: true)
    }
  }

  /// Collapses all outline view items.
  @IBAction func collapseAllItems(_ sender: Any?) {
    NSAnimationContext.runAnimationGroup { context in
      if shouldAnimate == false { context.duration = 0 }
      scrollableOutlineView.outlineView.animator().collapseItem(nil, collapseChildren: true)
    }
  }
}

/// Returns true if the checkbox is set.
private var shouldAnimate: Bool { UserDefaults.standard.bool(forKey: "ShouldAnimate") }

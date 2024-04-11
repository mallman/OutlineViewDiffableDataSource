import AppKit

/// Offers a diffable interface for providing content for `NSOutlineView`.  It automatically performs insertions, deletions, and moves necessary to transition from one model-state snapshot to another.
open class OutlineViewDiffableDataSource<Item>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate where Item: Hashable & Identifiable {
    public typealias CellProvider = (_ outlineView: NSOutlineView, _ tableColumn: NSTableColumn, _ item: Item) -> NSView
    public typealias RowProvider = (_ outlineView: NSOutlineView, _ item: Item) -> NSTableRowView
    public typealias ItemCheck = (_ outlineView: NSOutlineView, _ item: Item) -> Bool

    /// Tree with data.
    private var diffableSnapshot: DiffableDataSourceSnapshot<Item>

    /// Associated outline view.
    private weak var outlineView: NSOutlineView?

    /// Re-targeting API for drag-n-drop.
    public struct ProposedDrop {
        /// Dropping type.
        public enum `Type` {
            case on, before, after
        }

        /// Dropping type.
        public var type: Type

        /// Target item.
        public var targetItem: Item

        /// Items being dragged.
        public var draggedItems: [Item]

        /// Proposed operation.
        public var operation: NSDragOperation

        /// Creates a new item drag-n-drop “proposal”.
        public init(type: Type, targetItem: Item, draggedItems: [Item], operation: NSDragOperation) {
            self.type = type
            self.targetItem = targetItem
            self.draggedItems = draggedItems
            self.operation = operation
        }

        public func copy(type: Type? = nil,
                         targetItem: Item? = nil,
                         draggedItems: [Item]? = nil,
                         operation: NSDragOperation? = nil) -> ProposedDrop {
          ProposedDrop(type: type ?? self.type,
                       targetItem: targetItem ?? self.targetItem,
                       draggedItems: draggedItems ?? self.draggedItems,
                       operation: operation ?? self.operation)
        }
    }

    /// Callbacks for drag-n-drop.
    public typealias DraggingHandlers = (
        pasteboardDataForItemId: (_ itemId: Item.ID) -> Data?,
        itemIdForPasteboardData: (_ pasteboardData: Data) -> Item.ID?,
        validateDrop: (_ sender: OutlineViewDiffableDataSource, _ drop: ProposedDrop) -> ProposedDrop?,
        acceptDrop: (_ sender: OutlineViewDiffableDataSource, _ drop: ProposedDrop) -> Bool
    )

    /// Assign non-nil value to enable drag-n-drop.
    public var draggingHandlers: DraggingHandlers?

    /// Cell provider.
    private let cellProvider: CellProvider

    /// The closure that configures and returns the table view’s row views from the diffable data source.
    ///
    /// This property replaces the ``tableView(_:rowViewForRow:)`` delegate method.
    public var rowViewProvider: RowProvider?

    public var isSelectableProvider: ItemCheck?
    public var isExpandableProvider: ItemCheck?
    public var isGroupProvider: ItemCheck?

    /// Creates a new data source as well as a delegate for the given outline view.
    /// - Parameters:
    ///   - outlineView: The initialized outline view object to connect to the diffable data source.
    ///   - cellProvider: A closure that creates and returns each of the cells for the outline view from the data the diffable data source provides. This replaces the ``tableView(_:viewFor:row:)`` delegate method.
    public init(outlineView: NSOutlineView, cellProvider: @escaping CellProvider) {
        self.diffableSnapshot = .init()
        self.cellProvider = cellProvider

        super.init()

        precondition(outlineView.dataSource == nil)
        precondition(outlineView.delegate == nil)
        outlineView.dataSource = self
        outlineView.delegate = self
        self.outlineView = outlineView
        outlineView.registerForDraggedTypes(outlineView.registeredDraggedTypes + [.itemID])
    }

    deinit {
        self.outlineView?.dataSource = nil
        self.outlineView?.delegate = nil
    }

    // MARK: - NSOutlineViewDataSource
    /// Available to override. Default implementation returns `nil`.
    open func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
      return nil
    }

    /// Available to override. Default implementation does nothing.
    open func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
    }

    /// Uses diffable snapshot.
    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        diffableSnapshot.numberOfItems(in: item as? Item)
    }

    /// Uses diffable snapshot.
    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        diffableSnapshot.childrenOfItem(item as? Item)[index]
    }

    /// Uses diffable snapshot.
    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        isExpandableProvider?(outlineView, item as! Item) ?? false
    }

    /// Enables dragging for items which return Pasteboard representation.
    public func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let item = item as? Item,
              let draggingHandlers,
              let itemId = diffableSnapshot.idForItem(item),
              let pasteboardData = draggingHandlers.pasteboardDataForItemId(itemId) else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setData(pasteboardData, forType: .itemID)
        return pasteboardItem
    }

    /// This override is necessary to disable special mouse down behavior in the outline view.
    override public func responds(to aSelector: Selector?) -> Bool {
        if draggingHandlers == nil, aSelector == #selector(outlineView(_:pasteboardWriterForItem:)) {
            return false
        } else {
            return super.responds(to: aSelector)
        }
    }

    /// Enables drag-n-drop validation of items from this outline view. Available to override to validate dropped items from outside of this outline view
    open func outlineView(
        _ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int
    ) -> NSDragOperation {
        // Calculate proposed change if allowed and take decision from the client handler
        guard let draggingHandlers,
              let proposedDrop = proposedDrop(using: info, proposedItem: item, proposedChildIndex: index),
              let drop = draggingHandlers.validateDrop(self, proposedDrop) else { return [] }
        switch drop.type {
            // Re-target drop on item
            case .on:
                if drop.operation.isEmpty == false {
                    outlineView.setDropItem(drop.targetItem, dropChildIndex: NSOutlineViewDropOnItemIndex)
                }
                return drop.operation

            // Re-target drop before item
            case .before:
                if drop.operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(drop.targetItem) {
                    let parentItem = diffableSnapshot.parentOfItem(drop.targetItem)
                    outlineView.setDropItem(parentItem, dropChildIndex: childIndex)
                }
                return drop.operation

            // Re-target drop after item
            case .after:
                if drop.operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(drop.targetItem) {
                    let parentItem = diffableSnapshot.parentOfItem(drop.targetItem)
                    outlineView.setDropItem(parentItem, dropChildIndex: childIndex + 1)
                }
                return drop.operation
        }
    }

    /// Accepts drag-n-drop after validation for items in this outline view. Available to override to accept dropped items from outside of this outline view
    open func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let draggingHandlers,
              let drop = proposedDrop(using: info, proposedItem: item, proposedChildIndex: index) else { return false }
        return draggingHandlers.acceptDrop(self, drop)
    }

    // MARK: - NSOutlineViewDelegate

    /// Enables special appearance for group items.
    public func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return isGroupProvider?(outlineView, item as! Item) ?? false
    }

    /// Creates a cell view for the given item,
    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        return cellProvider(outlineView, tableColumn!, item as! Item)
    }

    /// Available to override. Default implementation does nothing
    open func outlineViewSelectionDidChange(_ notification: Notification) {
    }

    /// Filters selectable items. Available to override
    open func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        proposedSelectionIndexes.filteredIndexSet {
            guard let item = outlineView.item(atRow: $0) as? Item else { return false }
            return isSelectableProvider?(outlineView, item) ?? false
        }
    }

    /// Available to override. Default implementation does nothing
    open func outlineViewItemDidExpand(_ notification: Notification) {
    }

    /// Available to override. Default implementation does nothing
    open func outlineViewItemDidCollapse(_ notification: Notification) {
    }

    /// Creates a row view for the given item,
    public func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return rowViewProvider?(outlineView, item as! Item)
    }
}

// MARK: - Public API

public extension OutlineViewDiffableDataSource {
    /// Returns current state of the data source. This property is thread-safe.
    func snapshot() -> DiffableDataSourceSnapshot<Item> {
        if Thread.isMainThread {
            return diffableSnapshot
        } else {
            return DispatchQueue.main.sync { diffableSnapshot }
        }
    }

    /// Applies the given snapshot to this data source in background.
    /// - Parameter snapshot: Snapshot with new data.
    /// - Parameter animatingDifferences: Pass false to disable animations.
    /// - Parameter completionHandler: Called asynchronously in the main thread when the new snapshot is applied.
    func apply(_ snapshot: DiffableDataSourceSnapshot<Item>, animatingDifferences: Bool, completionHandler: (() -> Void)? = nil) {
        // Source and Destination
        let oldSnapshot = self.snapshot()
        let newSnapshot = snapshot

        // Apply changes immediately if animation is disabled
        guard animatingDifferences else {
            func apply() {
                diffableSnapshot = newSnapshot
                outlineView?.reloadData()
                completionHandler?()
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
            return
        }

        // Calculate changes
        let oldIndexedIds = oldSnapshot.indexedIds()
        let newIndexedIds = newSnapshot.indexedIds()
        let difference = newIndexedIds.difference(from: oldIndexedIds)
        let differenceWithMoves = difference.inferringMoves()

        // Apply changes changes
        func apply() {
          guard !differenceWithMoves.isEmpty else { return }
            differenceWithMoves.forEach {
                switch $0 {
                    case let .insert(_, inserted, indexBefore):
                        if let indexBefore {
                            // Move outline view item
                            let oldIndexedItemId = oldIndexedIds[indexBefore]
                            let oldParent = oldIndexedItemId.parentId.flatMap(oldSnapshot.itemForId)
                            let oldIndex = oldIndexedItemId.itemPath.last!
                            let newParent = inserted.parentId.flatMap(newSnapshot.itemForId)
                            let newIndex = inserted.itemPath.last!
                            guard oldParent != newParent || oldIndex != newIndex else {
                                return
                            }
                            outlineView?.moveItem(at: oldIndex, inParent: oldParent, to: newIndex, inParent: newParent)

                        } else {
                            // Insert outline view item
                            let insertionIndexes = IndexSet(integer: inserted.itemPath.last!)
                            let parentItem = inserted.parentId.flatMap(newSnapshot.itemForId)
                            outlineView?.insertItems(at: insertionIndexes, inParent: parentItem, withAnimation: [.effectFade, .slideDown])
                        }

                    case let .remove(_, before, indexAfter):
                        if indexAfter == nil {
                            // Delete outline view item
                            let deletionIndexes = IndexSet(integer: before.itemPath.last!)
                            let oldParentItem = before.parentId.flatMap(oldSnapshot.itemForId)
                            outlineView?.removeItems(at: deletionIndexes, inParent: oldParentItem, withAnimation: [.effectFade, .slideUp])
                        }
                }
            }
        }

        // Animate with completion
        func applyWithAnimation() {
            NSAnimationContext.runAnimationGroup({ context in
                self.outlineView?.beginUpdates()
                self.diffableSnapshot = newSnapshot
                apply()
                self.outlineView?.endUpdates()
            }, completionHandler: completionHandler)
        }
        if Thread.isMainThread {
            applyWithAnimation()
        } else {
            DispatchQueue.main.sync(execute: applyWithAnimation)
        }
    }
}

// MARK: - Private API

private extension OutlineViewDiffableDataSource {
    /// Calculates proposed drop for the given input.
    func proposedDrop(using info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> ProposedDrop? {
        guard let pasteboardItems = info.draggingPasteboard.pasteboardItems,
              pasteboardItems.isEmpty == false else { return nil }

        // Retrieve dragged items
        let draggedItems: [Item] = pasteboardItems.compactMap { pasteboardItem in
            guard let draggingHandlers,
                  let pasteboardData = pasteboardItem.data(forType: .itemID),
                  let itemId = draggingHandlers.itemIdForPasteboardData(pasteboardData) else { return nil }
            return diffableSnapshot.itemForId(itemId)
        }
        guard draggedItems.count == pasteboardItems.count else { return nil }

        // Drop on the item
        let parentItem = item as? Item
        if index == NSOutlineViewDropOnItemIndex {
            return parentItem.map { .init(type: .on, targetItem: $0, draggedItems: draggedItems, operation: info.draggingSourceOperationMask) }
        }

        // Drop into the item
        let childItems = diffableSnapshot.childrenOfItem(parentItem)
        guard childItems.isEmpty == false else { return nil }

        // Use “before” or “after” depending on index
        return index > 0
            ? .init(type: .after, targetItem: childItems[index - 1], draggedItems: draggedItems, operation: info.draggingSourceOperationMask)
            : .init(type: .before, targetItem: childItems[index], draggedItems: draggedItems, operation: info.draggingSourceOperationMask)
    }
}

private extension NSPasteboard.PasteboardType {
    /// Custom dragging type.
    static let itemID: NSPasteboard.PasteboardType = .init("OutlineViewDiffableDataSource.ItemID")
}

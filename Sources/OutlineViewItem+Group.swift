import AppKit

/// Default root item with buttons ‘Show’ and ‘Hide’, not intended for subclassing.
public final class GroupOutlineViewItem: OutlineViewItem {
    /// Unique identifier for diffing.
    public let id: String

    /// Display string.
    public let title: String

    /// Show as Group.
    public let isGroup = true

    /// Deny selection.
    public let isSelectable = false

    /// Creates a “standard” root item for the sidebar.
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    /// Returns an appropriate cell view type.
    public func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type { GroupTableCellView.self }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
    }

    public static func == (lhs: GroupOutlineViewItem, rhs: GroupOutlineViewItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Private API

/// Private implementation not intended for subclassing.
private final class GroupTableCellView: NSTableCellView {
    /// Creates a cell with a label that will be configure by AppKit.
    public init() {
        super.init(frame: .zero)

        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.allowsExpansionToolTips = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        label.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
        addSubview(label)

        self.textField = label
        self.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 2),
            self.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 1),
            self.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
            self.heightAnchor.constraint(equalToConstant: 23)
        ])
    }

    @available(*, unavailable, message: "Use init")
    override init(frame frameRect: NSRect) {
        fatalError()
    }

    @available(*, unavailable, message: "Use init")
    public required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: -

    /// Erases previous title.
    override func prepareForReuse() {
        super.prepareForReuse()

        if let label = textField {
            label.stringValue = ""
        }
    }

    /// Retrieves new title from the associated group item.
    override var objectValue: Any? {
        didSet {
            if let label = textField, let groupItem = objectValue as? GroupOutlineViewItem {
                label.stringValue = groupItem.title
            }
        }
    }
}

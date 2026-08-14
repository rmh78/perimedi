import SwiftUI
import UIKit

/// Scroll offset isolated so sticky labels can redraw without rebuilding the plot.
final class PlotScrollState: ObservableObject {
    @Published var offsetX: CGFloat = 0
    weak var scroller: PlotScrollView?

    /// Today button: always ease the day to the center, immediately.
    func centerDay(_ index: Int) {
        scroller?.scrollToColumn(index, animated: true)
    }

    /// Pager / tap: recenter only when that day is the first or last visible column.
    func centerIfAtBoundary(_ index: Int) {
        guard let scroller, scroller.isFirstOrLastVisible(index) else { return }
        scroller.scrollToColumn(index, animated: true)
    }
}

/// Held by CycleView as a `StateObject` with no published fields of its own, so
/// plot-scroll ticks only invalidate `DoseLabelOverlay`.
@MainActor
final class PlotScrollHandle: ObservableObject {
    let state = PlotScrollState()

    func centerDay(_ index: Int) { state.centerDay(index) }
    func centerIfAtBoundary(_ index: Int) { state.centerIfAtBoundary(index) }
}

/// Native UIScrollView plot with a dedicated short-press recognizer so a finger
/// tap selects a day even while the view can also scroll.
struct CyclePlotScroll<Content: View>: UIViewRepresentable {
    var contentWidth: CGFloat
    var contentHeight: CGFloat
    var columnWidth: CGFloat
    var columnCount: Int
    var contentRevision: Int
    var focusColumn: Int
    var focusToken: String
    var onOffset: (CGFloat) -> Void
    var scrollState: PlotScrollState
    var onSelectDayIndex: (Int) -> Void
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content())
    }

    func makeUIView(context: Context) -> PlotScrollView {
        let scroll = PlotScrollView()
        context.coordinator.bind(scroll, state: scrollState, onSelect: onSelectDayIndex, onOffset: onOffset)
        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.safeAreaRegions = []
        scroll.contentHost.addSubview(host.view)
        return scroll
    }

    func updateUIView(_ scroll: PlotScrollView, context: Context) {
        context.coordinator.bind(scroll, state: scrollState, onSelect: onSelectDayIndex, onOffset: onOffset)
        scroll.columnWidth = columnWidth
        scroll.columnCount = columnCount
        let saved = scroll.contentOffset
        let sizeChanged = abs(context.coordinator.contentWidth - contentWidth) > 0.5
            || abs(context.coordinator.columnWidth - columnWidth) > 0.5
        if context.coordinator.contentRevision != contentRevision || sizeChanged {
            context.coordinator.contentRevision = contentRevision
            context.coordinator.contentWidth = contentWidth
            context.coordinator.columnWidth = columnWidth
            context.coordinator.host.rootView = content()
        }
        let size = CGSize(width: max(contentWidth, 1), height: max(contentHeight, 1))
        scroll.contentSize = size
        scroll.contentHost.frame = CGRect(origin: .zero, size: size)
        context.coordinator.host.view.frame = CGRect(origin: .zero, size: size)
        if context.coordinator.focusToken != focusToken {
            context.coordinator.focusToken = focusToken
            scroll.scrollToColumn(focusColumn, animated: false)
        } else {
            if abs(scroll.contentOffset.x - saved.x) > 0.5 {
                scroll.contentOffset = saved
            }
            scroll.snapToFullCells(animated: false)
        }
    }

    final class Coordinator {
        let host: UIHostingController<Content>
        var contentRevision: Int?
        var contentWidth: CGFloat = 0
        var columnWidth: CGFloat = 0
        var focusToken: String?
        weak var scrollState: PlotScrollState?
        var onSelect: ((Int) -> Void)?
        var onOffset: ((CGFloat) -> Void)?

        init(content: Content) {
            host = UIHostingController(rootView: content)
        }

        func bind(
            _ scroll: PlotScrollView,
            state: PlotScrollState,
            onSelect: @escaping (Int) -> Void,
            onOffset: @escaping (CGFloat) -> Void
        ) {
            self.onSelect = onSelect
            self.onOffset = onOffset
            scrollState = state
            state.scroller = scroll
            scroll.onSelect = { [weak self] index in
                self?.onSelect?(index)
                self?.scrollState?.centerIfAtBoundary(index)
            }
            scroll.onOffset = { [weak self] x in
                self?.onOffset?(x)
            }
        }
    }
}

/// Discrete tap that fails only after the finger has clearly started a pan.
final class ShortPressRecognizer: UIGestureRecognizer {
    var allowedMovement: CGFloat = 14
    private var start = CGPoint.zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        start = touch.location(in: view)
        state = .possible
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        let point = touch.location(in: view)
        if hypot(point.x - start.x, point.y - start.y) > allowedMovement {
            state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible {
            state = .recognized
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    override func reset() {
        start = .zero
    }
}

final class PlotScrollView: UIScrollView, UIGestureRecognizerDelegate {
    let contentHost = UIView()
    var onSelect: ((Int) -> Void)?
    var onOffset: ((CGFloat) -> Void)?
    var columnWidth: CGFloat = 22
    var columnCount: Int = 1
    private var pendingFocusIndex: Int?
    private let tap = ShortPressRecognizer()
    private var animator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        delegate = self
        alwaysBounceHorizontal = true
        alwaysBounceVertical = false
        isDirectionalLockEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delaysContentTouches = false
        canCancelContentTouches = true
        bounces = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        panGestureRecognizer.delegate = self
        addSubview(contentHost)
        contentHost.isUserInteractionEnabled = false

        tap.addTarget(self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func scrollToColumn(_ index: Int, animated: Bool) {
        pendingFocusIndex = index
        guard columnWidth > 0, bounds.width > 1 else { return }
        let target = CGPoint(x: offsetLeavingColumnFullyVisible(index), y: 0)
        pendingFocusIndex = nil
        guard abs(target.x - contentOffset.x) > 0.5 else { return }

        animator?.stopAnimation(true)
        guard animated else {
            contentOffset = target
            return
        }
        let next = UIViewPropertyAnimator(duration: 0.28, controlPoint1: CGPoint(x: 0.2, y: 0.9), controlPoint2: CGPoint(x: 0.2, y: 1)) {
            self.contentOffset = target
        }
        next.startAnimation()
        animator = next
    }

    /// True only for the first or last fully visible column, or a column off-screen.
    func isFirstOrLastVisible(_ index: Int) -> Bool {
        guard columnWidth > 1, bounds.width > 1, columnCount > 0 else { return false }
        let first = firstFullyVisibleColumn
        let last = lastFullyVisibleColumn
        if index < first || index > last { return true }
        return index == first || index == last
    }

    func snapToFullCells(animated: Bool) {
        guard !isDragging, !isDecelerating, animator?.isRunning != true else { return }
        let x = snappedOffsetX(contentOffset.x)
        guard abs(x - contentOffset.x) > 0.5 else { return }
        animator?.stopAnimation(true)
        if animated {
            setContentOffset(CGPoint(x: x, y: 0), animated: true)
        } else {
            contentOffset = CGPoint(x: x, y: 0)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let index = pendingFocusIndex, bounds.width > 1, columnWidth > 0 {
            scrollToColumn(index, animated: false)
            return
        }
        snapToFullCells(animated: false)
    }

    private var visibleColumnCount: Int {
        guard columnWidth > 0.5, bounds.width > 1 else { return 1 }
        return max(1, Int((bounds.width / columnWidth).rounded()))
    }

    private var firstFullyVisibleColumn: Int {
        guard columnWidth > 0.5 else { return 0 }
        return max(0, min(columnCount - 1, Int((contentOffset.x / columnWidth).rounded())))
    }

    private var lastFullyVisibleColumn: Int {
        min(columnCount - 1, firstFullyVisibleColumn + visibleColumnCount - 1)
    }

    private var maxOffsetX: CGFloat {
        max(0, contentSize.width - bounds.width)
    }

    private func snappedOffsetX(_ x: CGFloat) -> CGFloat {
        guard columnWidth > 0.5 else { return min(max(0, x), maxOffsetX) }
        let maxPage = max(0, columnCount - visibleColumnCount)
        let page = Int((x / columnWidth).rounded())
        return CGFloat(min(max(0, page), maxPage)) * columnWidth
    }

    private func offsetLeavingColumnFullyVisible(_ index: Int) -> CGFloat {
        let visible = visibleColumnCount
        let maxFirst = max(0, columnCount - visible)
        let first = min(max(0, index - visible / 2), maxFirst)
        return snappedOffsetX(CGFloat(first) * columnWidth)
    }

    @objc private func handleTap(_ gesture: ShortPressRecognizer) {
        guard gesture.state == .ended || gesture.state == .recognized else { return }
        selectDay(at: gesture.location(in: contentHost))
    }

    private func selectDay(at pointInContent: CGPoint) {
        guard columnWidth > 0, columnCount > 0 else { return }
        let index = Int(floor(pointInContent.x / columnWidth))
        guard index >= 0, index < columnCount else { return }
        onSelect?(index)
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

extension PlotScrollView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onOffset?(scrollView.contentOffset.x)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        animator?.stopAnimation(true)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        targetContentOffset.pointee.x = snappedOffsetX(targetContentOffset.pointee.x)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToFullCells(animated: true)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToFullCells(animated: true)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        false
    }
}

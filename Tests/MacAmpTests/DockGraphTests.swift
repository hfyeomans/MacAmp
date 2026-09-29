import Testing
import CoreGraphics
@testable import MacAmp

/// Boxes use top-left coordinates (y grows downward), as in `SnapUtils`.
@Suite("DockGraph", .tags(.window))
struct DockGraphTests {
    private let main = Box(x: 0, y: 0, width: 275, height: 116)
    private let eq = Box(x: 0, y: 116, width: 275, height: 116)
    private let playlist = Box(x: 0, y: 232, width: 275, height: 232)

    @Test("A closed EQ still links Main to the Playlist docked below it")
    func closedMiddleWindowKeepsChain() {
        let withClosedEQ: [String: Box] = ["main": main, "eq": eq, "playlist": playlist]
        #expect(DockGraph.cluster(from: "main", boxes: withClosedEQ) == ["main", "eq", "playlist"])

        let withoutEQ: [String: Box] = ["main": main, "playlist": playlist]
        #expect(DockGraph.cluster(from: "main", boxes: withoutEQ) == ["main"])
    }

    @Test("Docking tolerance is 10 px (Winamp default)")
    func tenPixelTolerance() {
        #expect(SnapUtils.SNAP_DISTANCE == 10)
        let nineAway = Box(x: 0, y: 125, width: 275, height: 116)
        let elevenAway = Box(x: 0, y: 127, width: 275, height: 116)
        #expect(DockGraph.areDocked(main, nineAway))
        #expect(!DockGraph.areDocked(main, elevenAway))
    }

    @Test("Chains are transitive across stacked and side-by-side windows")
    func transitiveChain() {
        let beside = Box(x: 275, y: 116, width: 275, height: 116)
        let far = Box(x: 1000, y: 1000, width: 275, height: 116)
        let boxes: [String: Box] = ["main": main, "eq": eq, "beside": beside, "far": far]
        #expect(DockGraph.cluster(from: "main", boxes: boxes) == ["main", "eq", "beside"])
    }

    private let order = ["main", "eq", "playlist", "video", "milkdrop", "under"]
    private let shade = CGSize(width: 275, height: 14)

    /// IDs whose box changed position (size changes of the resized window itself don't count).
    private func moved(_ before: [String: Box], _ after: [String: Box]) -> Set<String> {
        Set(before.keys.filter { before[$0]?.x != after[$0]?.x || before[$0]?.y != after[$0]?.y })
    }

    @Test("Shading Main moves only the windows attached below it")
    func shadeMovesChainBelow() {
        let video = Box(x: 275, y: 0, width: 275, height: 116)  // beside Main, not below
        let boxes: [String: Box] = ["main": main, "eq": eq, "playlist": playlist, "video": video]
        let after = DockGraph.followResize(boxes: boxes, newSizes: ["main": shade], order: order)
        #expect(moved(boxes, after) == ["eq", "playlist"])
        #expect(after["eq"]?.y == 14 && after["playlist"]?.y == 130)
    }

    @Test("Unshading Main pushes the chain back down")
    func unshadePushesDown() {
        let shadedMain = Box(x: 0, y: 0, width: 275, height: 14)
        let raisedEQ = Box(x: 0, y: 14, width: 275, height: 116)
        let after = DockGraph.followResize(boxes: ["main": shadedMain, "eq": raisedEQ],
                                           newSizes: ["main": CGSize(width: 275, height: 116)], order: order)
        #expect(after["eq"]?.y == 116)
    }

    @Test("A window beside the EQ follows the EQ when Main shades")
    func besideEQFollows() {
        let video = Box(x: 275, y: 116, width: 275, height: 116)
        let boxes: [String: Box] = ["main": main, "eq": eq, "video": video]
        let after = DockGraph.followResize(boxes: boxes, newSizes: ["main": shade], order: order)
        #expect(moved(boxes, after) == ["eq", "video"])
        #expect(after["video"]?.y == after["eq"]?.y)
    }

    @Test("A window hanging from one that stays doesn't follow, nor what hangs from it")
    func hangingFromStayingWindowStays() {
        let playlist = Box(x: 0, y: 232, width: 275, height: 174)
        let video = Box(x: 275, y: 0, width: 275, height: 174)       // beside Main, tops level
        let milkdrop = Box(x: 275, y: 174, width: 275, height: 232)  // under Video, beside the Playlist
        let under = Box(x: 275, y: 406, width: 275, height: 116)     // under Milkdrop
        let boxes: [String: Box] = ["main": main, "eq": eq, "playlist": playlist,
                                    "video": video, "milkdrop": milkdrop, "under": under]
        let after = DockGraph.followResize(boxes: boxes, newSizes: ["main": shade], order: order)
        #expect(moved(boxes, after) == ["eq", "playlist"])
    }

    @Test("A window beside Main follows Main's width change")
    func besideMainFollowsWidth() {
        let doubledMain = Box(x: 0, y: 0, width: 550, height: 232)
        let video = Box(x: 550, y: 0, width: 275, height: 232)
        let after = DockGraph.followResize(boxes: ["main": doubledMain, "video": video],
                                           newSizes: ["main": CGSize(width: 275, height: 116)], order: order)
        #expect(after["video"]?.x == 275 && after["video"]?.y == 0)
    }

    @Test("Double → normal size in the owner's layout: no overlaps; a round trip restores it")
    func doubleSizeOwnerLayout() {
        // Double size: Main/EQ/Playlist stacked 550 wide; Milkdrop beside Main+EQ; Video under Milkdrop, beside the Playlist.
        let doubled: [String: Box] = [
            "main": Box(x: 0, y: 0, width: 550, height: 232),
            "eq": Box(x: 0, y: 232, width: 550, height: 232),
            "playlist": Box(x: 0, y: 464, width: 550, height: 348),
            "milkdrop": Box(x: 550, y: 0, width: 550, height: 464),
            "video": Box(x: 550, y: 464, width: 550, height: 348),
        ]
        let normal = DockGraph.followResize(boxes: doubled, newSizes: ["main": CGSize(width: 275, height: 116), "eq": CGSize(width: 275, height: 116)], order: order)
        #expect(normal["eq"]?.y == 116)
        #expect(normal["playlist"]?.y == 232)
        #expect(normal["milkdrop"] == doubled["milkdrop"] && normal["video"] == doubled["video"])
        let boxes = Array(normal.values)
        for a in boxes.indices {
            for b in boxes.indices where b > a {
                let overlap = boxes[a].x < boxes[b].x + boxes[b].width && boxes[b].x < boxes[a].x + boxes[a].width
                    && boxes[a].y < boxes[b].y + boxes[b].height && boxes[b].y < boxes[a].y + boxes[a].height
                #expect(!overlap)
            }
        }
        let back = DockGraph.followResize(boxes: normal, newSizes: ["main": CGSize(width: 550, height: 232), "eq": CGSize(width: 550, height: 232)],
                                          order: order)
        #expect(back == doubled)
    }

    @Test("clusters partitions AppKit frames into docked groups")
    func clustersPartition() {
        let main = CGRect(x: 100, y: 1200, width: 550, height: 232)
        let eq = CGRect(x: 100, y: 968, width: 550, height: 232)
        let far = CGRect(x: 2000, y: 200, width: 275, height: 116)
        let rects = ["main": main, "eq": eq, "far": far]
        let groups = DockGraph.clusters(boxes: rects.mapValues(DockGraph.box(for:)))
        #expect(Set(groups) == [["main", "eq"], ["far"]])
    }

    @Test("Snapping picks the nearest target on each axis, whatever the order")
    func snapPicksNearest() {
        // Dragged window's top is 2 px below A's bottom and 7 px below B's bottom; both within snap range.
        let dragged = Box(x: 0, y: 118, width: 275, height: 116)
        let a = Box(x: 0, y: 0, width: 275, height: 116)
        let b = Box(x: 0, y: 0, width: 275, height: 111)
        for others in [[a, b], [b, a]] {
            #expect(SnapUtils.snapToMany(dragged, others).y == 116)
        }
    }

    @Test("A resize with nothing attached moves nothing")
    func nothingAttached() {
        let after = DockGraph.followResize(boxes: ["main": main], newSizes: ["main": shade], order: order)
        #expect(after["main"]?.x == 0 && after["main"]?.y == 0 && after["main"]?.height == 14)
    }
}

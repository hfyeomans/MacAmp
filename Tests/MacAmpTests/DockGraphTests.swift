import Testing
import CoreGraphics
@testable import MacAmp

/// Boxes use top-left coordinates (y grows downward), as in `SnapUtils`.
@Suite("DockGraph", .tags(.window))
struct DockGraphTests {
    private let main = Box(x: 0, y: 0, width: 275, height: 116)
    private let eq = Box(x: 0, y: 116, width: 275, height: 116)
    private let playlist = Box(x: 0, y: 232, width: 275, height: 232)

    @Test("A closed EQ still links Main to the Playlist docked below it (#78)")
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

    @Test("Shading Main moves only the windows docked below it")
    func dockedBelowOnShade() {
        let video = Box(x: 275, y: 0, width: 275, height: 116)  // beside Main, not below
        let shadedMain = Box(x: 0, y: 0, width: 275, height: 14)
        let boxes: [String: Box] = ["main": shadedMain, "eq": eq, "playlist": playlist, "video": video]
        #expect(DockGraph.dockedBelow("main", oldBox: main, boxes: boxes) == ["eq", "playlist"])
    }

    @Test("Unshading Main pushes the docked chain back down")
    func dockedBelowOnUnshade() {
        let shadedMain = Box(x: 0, y: 0, width: 275, height: 14)
        let raisedEQ = Box(x: 0, y: 14, width: 275, height: 116)
        let boxes: [String: Box] = ["main": main, "eq": raisedEQ]
        #expect(DockGraph.dockedBelow("main", oldBox: shadedMain, boxes: boxes) == ["eq"])
    }

    @Test("A window resized with nothing docked below moves nothing")
    func nothingBelow() {
        let boxes: [String: Box] = ["main": main]
        #expect(DockGraph.dockedBelow("main", oldBox: main, boxes: boxes).isEmpty)
    }
}

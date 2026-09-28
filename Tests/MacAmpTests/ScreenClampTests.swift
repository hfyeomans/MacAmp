import Testing
import CoreGraphics
@testable import MacAmp

/// AppKit coordinates (bottom-left origin). Screen: 3840×1600 with a 30 px menu bar.
@Suite("ScreenClamp", .tags(.window))
struct ScreenClampTests {
    private let lg = CGRect(x: 0, y: 0, width: 3840, height: 1570)
    private let main = CGRect(x: 100, y: 1200, width: 550, height: 232)
    private let eq = CGRect(x: 100, y: 968, width: 550, height: 232)

    @Test("A group already on screen doesn't move")
    func onScreenNoop() {
        let moved = ScreenClamp.clamp(groups: [["main", "eq"]], frames: ["main": main, "eq": eq],
                                      visible: ["main", "eq"], visibleFrames: [lg])
        #expect(moved.isEmpty)
    }

    @Test("An off-screen docked group moves back as a unit, keeping its offsets")
    func groupMovesAsUnit() throws {
        let low = ["main": main.offsetBy(dx: 0, dy: -2000), "eq": eq.offsetBy(dx: 0, dy: -2000)]
        let moved = ScreenClamp.clamp(groups: [["main", "eq"]], frames: low,
                                      visible: ["main", "eq"], visibleFrames: [lg])
        let newMain = try #require(moved["main"]), newEQ = try #require(moved["eq"])
        #expect(newEQ.minY == lg.minY)
        #expect(newMain.minY - newEQ.maxY == 0)  // still docked
        #expect(newMain.minX == newEQ.minX)
    }

    @Test("A group taller than the screen keeps its top edge on screen")
    func tallGroupPinsTop() {
        let tall = CGRect(x: 593, y: -21312, width: 400, height: 1566 + 100)
        let moved = ScreenClamp.clamp(groups: [["playlist"]], frames: ["playlist": tall],
                                      visible: ["playlist"], visibleFrames: [lg])
        #expect(moved["playlist"]?.maxY == lg.maxY)
    }

    @Test("Top edge above the visible frame (menu bar) is pulled down")
    func aboveMenuBar() {
        let high = ["main": main.offsetBy(dx: 0, dy: 500)]
        let moved = ScreenClamp.clamp(groups: [["main"]], frames: high, visible: ["main"], visibleFrames: [lg])
        #expect(moved["main"]?.maxY == lg.maxY)
    }

    @Test("A window on a vanished display moves to the main screen")
    func lostDisplay() throws {
        let laptop = CGRect(x: 0, y: 0, width: 1512, height: 949)
        let wasOnLG = ["main": CGRect(x: 3000, y: 1200, width: 550, height: 232)]
        let moved = ScreenClamp.clamp(groups: [["main"]], frames: wasOnLG, visible: ["main"], visibleFrames: [laptop])
        let frame = try #require(moved["main"])
        #expect(laptop.contains(frame))
    }

    @Test("The screen overlapping the group most is chosen")
    func picksBestScreen() {
        let left = CGRect(x: -1512, y: 0, width: 1512, height: 949)
        let partlyOffLeft = CGRect(x: -1300, y: 900, width: 550, height: 232)  // mostly on `left`, above its top
        let target = ScreenClamp.screen(for: partlyOffLeft, visibleFrames: [lg, left])
        #expect(target == left)
    }

    @Test("A hidden-only group is measured by its own frames")
    func hiddenOnlyGroup() {
        let hidden = ["video": CGRect(x: 5000, y: 300, width: 1200, height: 725)]
        let moved = ScreenClamp.clamp(groups: [["video"]], frames: hidden, visible: [], visibleFrames: [lg])
        #expect(moved["video"]?.maxX == lg.maxX)
    }

    @Test("Visible members decide the offset; hidden members move with them")
    func hiddenMemberFollows() throws {
        let frames = ["main": main.offsetBy(dx: 0, dy: -2000), "eq": eq.offsetBy(dx: 0, dy: -2000)]
        let moved = ScreenClamp.clamp(groups: [["main", "eq"]], frames: frames, visible: ["main"], visibleFrames: [lg])
        let newMain = try #require(moved["main"]), newEQ = try #require(moved["eq"])
        #expect(newMain.minY == lg.minY)
        #expect(newMain.minY - newEQ.maxY == 0)
    }

    @Test("A primary-display change re-bases coordinates; groups follow their own display")
    func translateFollowsDisplay() throws {
        // LG was primary at (0,0); the built-in became primary and the LG moved to (1800,-431).
        let old: [UInt32: CGRect] = [1: CGRect(x: 0, y: 0, width: 3840, height: 1600)]
        let new: [UInt32: CGRect] = [1: CGRect(x: 1800, y: -431, width: 3840, height: 1600),
                                     2: CGRect(x: 0, y: 0, width: 1800, height: 1169)]
        let result = ScreenClamp.translate(groups: [["main", "eq"]], frames: ["main": main, "eq": eq],
                                           from: old, to: new)
        let newMain = try #require(result["main"]), newEQ = try #require(result["eq"])
        #expect(newMain.origin == CGPoint(x: main.minX + 1800, y: main.minY - 431))
        #expect(newMain.minY - newEQ.maxY == 0)  // still docked
    }

    @Test("A group whose display is gone keeps its frames for the clamp to handle")
    func translateLostDisplay() {
        let old: [UInt32: CGRect] = [1: CGRect(x: 0, y: 0, width: 3840, height: 1600)]
        let new: [UInt32: CGRect] = [2: CGRect(x: 0, y: 0, width: 1800, height: 1169)]
        let result = ScreenClamp.translate(groups: [["main"]], frames: ["main": main], from: old, to: new)
        #expect(result["main"] == main)
    }

    @Test("Stranded groups that fit together move by one offset, keeping their arrangement")
    func strandedGroupsMoveTogether() throws {
        let laptop = CGRect(x: 0, y: 0, width: 1800, height: 1130)
        let video = CGRect(x: 900, y: 1200, width: 550, height: 464)  // right of the Main/EQ group, off-screen above
        let frames = ["main": main, "eq": eq, "video": video]
        let moved = ScreenClamp.clamp(groups: [["main", "eq"], ["video"]], frames: frames,
                                      visible: ["main", "eq", "video"], visibleFrames: [laptop])
        let newMain = try #require(moved["main"]), newVideo = try #require(moved["video"])
        #expect(newVideo.minX - newMain.minX == video.minX - main.minX)
        #expect(newVideo.minY - newMain.minY == video.minY - main.minY)
        #expect(laptop.contains(newMain) && laptop.contains(newVideo))
    }

    @Test("DockGraph.clusters partitions windows into docked groups")
    func clustersPartition() {
        let far = CGRect(x: 2000, y: 200, width: 275, height: 116)
        let rects = ["main": main, "eq": eq, "far": far]
        let groups = DockGraph.clusters(boxes: rects.mapValues(DockGraph.box(for:)))
        #expect(Set(groups) == [["main", "eq"], ["far"]])
    }
}

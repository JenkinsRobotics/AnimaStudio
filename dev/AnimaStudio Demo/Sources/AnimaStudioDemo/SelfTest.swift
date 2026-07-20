// Headless self-check: `AnimaStudioDemo --selftest` exercises the pure logic
// (pose math, mate authoring, geometry import) and exits non-zero on failure.
// Lets the engine be verified without driving the GUI.
import Foundation
import GeomKit
import simd

@MainActor
enum SelfTest {
  private static var failures = 0

  static func runAndExit() -> Never {
    print("AnimaStudio Demo — self test")
    renderingDefaults()
    viewCube()
    picking()
    poseMath()
    mateAuthoring()
    animation()
    hardware()
    persistence()
    projectFolder()
    toolLifecycle()
    geometry()
    print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILURE(S)")
    exit(failures == 0 ? 0 : 1)
  }

  private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    if ok {
      print("  ok   \(name)")
    } else {
      failures += 1
      print("  FAIL \(name) \(detail)")
    }
  }

  private static func nearly(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ eps: Float = 1e-4) -> Bool {
    simd_length(a - b) < eps
  }

  private static func apply(_ m: simd_float4x4, _ p: SIMD3<Float>) -> SIMD3<Float> {
    let r = m * SIMD4<Float>(p, 1)
    return SIMD3(r.x, r.y, r.z)
  }

  // MARK: - Rendering defaults
  // Guards the "everything looks orange" regression: the selection highlight
  // must be OFF by default, and themes must preserve imported STEP colors.

  static func renderingDefaults() {
    print("\nRendering defaults")
    let session = BenchSession()
    check("model starts unselected (true STEP colors show)", session.isModelSelected == false)
    session.toggleModelSelection()
    check("clicking selects", session.isModelSelected == true)
    session.toggleModelSelection()
    check("clicking again deselects", session.isModelSelected == false)
    check("default theme preserves imported colors",
      BenchTheme.studioBlue.overrideColor == nil)
    let imported = SIMD4<Float>(0.1, 0.1, 0.1, 1)   // a black tire
    check("displayColor passes imported through when not overridden",
      BenchTheme.studioBlue.displayColor(for: imported) == imported)
  }

  // MARK: - View cube

  static func viewCube() {
    print("\nView cube")
    let size = CGSize(width: 72, height: 72)
    // Looking straight down +Z (front view): only the front face is visible.
    let front = SIMD3<Float>(0, 0, 1)
    let frontFaces = ViewCubeGeometry.faces(in: size, direction: front)
    check("front view shows exactly one face", frontFaces.count == 1, "got \(frontFaces.count)")
    check("that face is FRONT", frontFaces.first?.face == .front)

    // Isometric: three faces visible, never the opposite ones.
    let iso = simd_normalize(SIMD3<Float>(1, 1, 1))
    let isoFaces = ViewCubeGeometry.faces(in: size, direction: iso)
    check("isometric shows three faces", isoFaces.count == 3, "got \(isoFaces.count)")
    let visible = Set(isoFaces.map(\.face))
    check("isometric shows front/top/right", visible == [.front, .top, .right])
    check("back-facing faces are culled", !visible.contains(.back) && !visible.contains(.left))

    // Painting order must be back-to-front.
    check("faces are depth sorted back-to-front",
      zip(isoFaces, isoFaces.dropFirst()).allSatisfy { $0.depth <= $1.depth })

    // Hit-testing: the centre of the front view is the FRONT face.
    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
    check("centre hit-tests to the facing face",
      ViewCubeGeometry.face(at: centre, in: size, direction: front) == .front)
    check("a point outside the cube hits nothing",
      ViewCubeGeometry.face(at: CGPoint(x: 2, y: 2), in: size, direction: front) == nil)

    // Every face's camera angles must actually look at that face.
    for face in ViewCubeFace.allCases {
      let a = face.cameraAngles
      let dir = SIMD3<Float>(cos(a.pitch) * sin(a.yaw), sin(a.pitch), cos(a.pitch) * cos(a.yaw))
      check("\(face.title) angles face the camera at it", simd_dot(dir, face.normal) > 0.95,
        "dot=\(simd_dot(dir, face.normal))")
    }

    // Point-in-polygon sanity on a known square.
    let square = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0),
                  CGPoint(x: 10, y: 10), CGPoint(x: 0, y: 10)]
    check("polygon contains an interior point",
      ViewCubeGeometry.contains(CGPoint(x: 5, y: 5), polygon: square))
    check("polygon excludes an exterior point",
      !ViewCubeGeometry.contains(CGPoint(x: 15, y: 5), polygon: square))
  }

  // MARK: - Picking

  static func picking() {
    print("\nPicking")
    // A unit triangle in the z=0 plane, ray straight down -Z from z=5.
    let a = SIMD3<Float>(-1, -1, 0), b = SIMD3<Float>(1, -1, 0), c = SIMD3<Float>(0, 1, 0)
    let down = PickRay(origin: [0, 0, 5], direction: [0, 0, -1])
    let hit = Picking.rayTriangle(down, a, b, c)
    check("ray hits the triangle at the expected distance",
      hit.map { abs($0 - 5) < 1e-4 } == true, "got \(String(describing: hit))")

    let miss = PickRay(origin: [9, 9, 5], direction: [0, 0, -1])
    check("ray beside the triangle misses", Picking.rayTriangle(miss, a, b, c) == nil)

    let away = PickRay(origin: [0, 0, 5], direction: [0, 0, 1])
    check("ray pointing away misses", Picking.rayTriangle(away, a, b, c) == nil)

    let parallel = PickRay(origin: [0, 0, 5], direction: [1, 0, 0])
    check("ray parallel to the triangle misses", Picking.rayTriangle(parallel, a, b, c) == nil)

    // Camera ray: the viewport centre must look straight at the target.
    let viewport = CGSize(width: 800, height: 600)
    let centre = Picking.cameraRay(
      point: CGPoint(x: 400, y: 300), viewport: viewport,
      position: [0, 0, 5], target: .zero)
    check("centre ray points at the target",
      nearly(centre.direction, [0, 0, -1], 1e-5))
    let right = Picking.cameraRay(
      point: CGPoint(x: 700, y: 300), viewport: viewport,
      position: [0, 0, 5], target: .zero)
    check("a right-side click aims to the right", right.direction.x > 0)
    let upper = Picking.cameraRay(
      point: CGPoint(x: 400, y: 100), viewport: viewport,
      position: [0, 0, 5], target: .zero)
    check("an upper click aims upward", upper.direction.y > 0)

    // Ray transforms round-trip through a matrix and its inverse.
    let m = RigPose.translation([3, -2, 1])
    let there = Picking.transform(down, by: m)
    let back = Picking.transform(there, by: m.inverse)
    check("ray survives a transform round-trip",
      nearly(back.origin, down.origin) && nearly(back.direction, down.direction))

    // Selection levels behave like CAD.
    let pick = SelectionModel.shared
    pick.clear()
    check("nothing selected initially", !pick.hasSelection)
    pick.selectFace(7, node: 2, part: nil, at: .zero)
    check("single click selects a face", pick.level == .face && pick.faceID == 7)
    check("only the picked face highlights", pick.highlights(face: 7, node: 2))
    check("a sibling face does not highlight", !pick.highlights(face: 8, node: 2))
    check("another part does not highlight", !pick.highlights(face: 7, node: 3))
    check("face selection shows no move controls", !pick.showsMoveControls)

    pick.selectBody(node: 2, part: nil, at: .zero)
    check("double click promotes to the body", pick.level == .body)
    check("whole body highlights", pick.highlights(face: 99, node: 2))
    check("other parts still excluded", !pick.highlights(face: 99, node: 3))
    check("body selection opens move controls", pick.showsMoveControls)

    pick.clear()
    check("clearing removes the selection", !pick.hasSelection && !pick.showsMoveControls)
  }

  // MARK: - Pose math

  /// Builds a character with `n` parts and returns their stable PartIDs.
  @discardableResult
  private static func fixtureParts(_ n: Int) -> [PartID] {
    let project = ProjectModel.shared
    project.characters.removeAll()
    project.addCharacter(named: "Test")
    guard let index = project.activeIndex else { return [] }
    var ids: [PartID] = []
    for node in 0..<n {
      let part = CharacterPart(assetName: "test.step", node: node, name: "Part \(node)")
      project.characters[index].parts.append(part)
      ids.append(part.id)
    }
    return ids
  }

  static func poseMath() {
    print("\nPose math")
    let p0 = UUID(), p1 = UUID(), p2 = UUID()
    let r = RigPose.rotation(axis: [0, 0, 1], degrees: 90, about: .zero)
    check("revolute 90° about Z maps +X to +Y", nearly(apply(r, [1, 0, 0]), [0, 1, 0]))

    let pivot = SIMD3<Float>(2, 3, 4)
    let aboutPivot = RigPose.rotation(axis: [0, 1, 0], degrees: 37, about: pivot)
    check("rotation leaves its pivot fixed", nearly(apply(aboutPivot, pivot), pivot))

    var slider = Mate(name: "s", type: .slider, parent: p0, child: p1)
    slider.axis = .x
    slider.value = 250
    check("slider 250mm becomes 0.25m",
      nearly(apply(RigPose.local(slider, pivot: .zero), .zero), [0.25, 0, 0]))

    let fastened = Mate(name: "f", type: .fastened, parent: p0, child: p1)
    check("fastened contributes identity",
      RigPose.local(fastened, pivot: .zero) == matrix_identity_float4x4)

    var a = Mate(name: "a", type: .revolute, parent: p0, child: p1)
    a.value = 90
    var b = Mate(name: "b", type: .revolute, parent: p1, child: p2)
    b.value = 90
    let pose = RigPose.evaluate(mates: [a, b], pivots: [p1: SIMD3<Float>.zero, p2: SIMD3<Float>.zero])
    check("chained mates accumulate to 180°",
      nearly(apply(pose[p2] ?? matrix_identity_float4x4, [1, 0, 0]), [-1, 0, 0]))
    check("unmated part gets no pose entry", pose[p0] == nil)

    var c1 = Mate(name: "c1", type: .revolute, parent: p1, child: p2)
    c1.value = 10
    var c2 = Mate(name: "c2", type: .revolute, parent: p2, child: p1)
    c2.value = 10
    check("cyclic mates terminate", RigPose.evaluate(mates: [c1, c2], pivots: [:]).count == 2)
  }

  // MARK: - Mate authoring

  static func mateAuthoring() {
    print("\nMate authoring")
    let rig = RigModel.shared
    let ids = fixtureParts(8)
    rig.mates.removeAll()
    rig.selectedParts = []
    rig.selectedMateID = nil

    check("no mate is created without two parts", rig.addMate(.revolute) == nil)

    rig.togglePart(ids[3], extending: true)
    rig.togglePart(ids[7], extending: true)
    check("two parts selected", rig.selectedParts.count == 2)

    let mate = rig.addMate(.revolute)
    check("mate created from the selection", mate != nil)
    check("parent/child taken from selection", mate?.parent == ids[3] && mate?.child == ids[7])
    check("new mate becomes selected", rig.selectedMateID == mate?.id)
    check("revolute is a driven axis", mate?.type.isDriven == true)

    rig.togglePart(ids[3], extending: true)
    check("toggling removes a part from selection", !rig.selectedParts.contains(ids[3]))

    if let id = mate?.id { rig.removeMate(id) }
    check("mate removed", rig.mates.isEmpty)
    check("selection cleared after removal", rig.selectedMateID == nil)

    rig.selectedParts = []
  }

  // MARK: - Animation

  static func animation() {
    print("\nAnimation")
    let keys = [
      Keyframe(time: 0, value: 0),
      Keyframe(time: 2, value: 100),
      Keyframe(time: 4, value: 50),
    ]
    check("no value without keys", AnimationModel.value([], at: 1) == nil)
    check("clamps before the first key", AnimationModel.value(keys, at: -5) == 0)
    check("clamps after the last key", AnimationModel.value(keys, at: 99) == 50)
    check("hits keys exactly", AnimationModel.value(keys, at: 2) == 100)
    let mid = AnimationModel.value(keys, at: 1) ?? -1
    check("interpolates linearly (t=1 → 50)", abs(mid - 50) < 1e-6, "got \(mid)")
    let back = AnimationModel.value(keys, at: 3) ?? -1
    check("interpolates descending (t=3 → 75)", abs(back - 75) < 1e-6, "got \(back)")
    check("unsorted keys still evaluate",
      AnimationModel.value(keys.reversed(), at: 1).map { abs($0 - 50) < 1e-6 } == true)

    // Authoring + playback against a real mate.
    let rig = RigModel.shared
    let anim = AnimationModel.shared
    let ids = fixtureParts(4)
    rig.mates.removeAll()
    rig.selectedParts = [ids[0], ids[1]]
    guard let mate = rig.addMate(.revolute) else {
      check("mate available for animation", false)
      return
    }
    anim.clips = [Clip(name: "Test", duration: 4)]
    anim.selectedClipID = anim.clips[0].id

    anim.time = 0
    anim.addKey(for: mate.id, value: 0)
    anim.time = 4
    anim.addKey(for: mate.id, value: 90)
    check("track created for the mate", anim.clip?.tracks.count == 1)
    check("two keys recorded", anim.clip?.tracks.first?.keys.count == 2)

    // Re-keying at the same time replaces rather than stacking.
    anim.addKey(for: mate.id, value: 45)
    check("re-key replaces at same time", anim.clip?.tracks.first?.keys.count == 2)

    anim.scrub(toProgress: 0)
    check("apply drives mate to 0 at t=0", abs((rig.mates.first?.value ?? -1) - 0) < 1e-6)
    anim.scrub(toProgress: 0.5)
    let half = rig.mates.first?.value ?? -1
    check("apply interpolates at t=2 (→22.5)", abs(half - 22.5) < 1e-6, "got \(half)")

    check("progress tracks time", abs(anim.progress - 0.5) < 1e-6)
    anim.advance(by: 10)   // loops
    check("playback loops within duration", anim.time < anim.duration, "t=\(anim.time)")

    // Pose actually changes when the mate is driven.
    rig.mates[0].value = 90
    let posed = RigPose.evaluate(mates: rig.mates, pivots: [rig.mates[0].child: .zero])
    let moved = posed[rig.mates[0].child] ?? matrix_identity_float4x4
    check("driven mate produces a non-identity pose", moved != matrix_identity_float4x4)

    anim.pause()
    rig.mates.removeAll()
    rig.selectedParts = []
    anim.clips = [Clip(name: "Greeting", duration: 8)]
    anim.selectedClipID = nil
    anim.time = 0
  }

  // MARK: - Hardware binding

  static func hardware() {
    print("\nHardware binding")
    // Pure mapping first.
    check("trim offsets the commanded angle",
      HardwareModel.commandedDegrees(mateValue: 20, trim: 5, inverted: false) == 25)
    check("invert flips before trim",
      HardwareModel.commandedDegrees(mateValue: 20, trim: 5, inverted: true) == -15)
    check("fraction maps mid-range to 0.5",
      abs(HardwareModel.fraction(value: 0, min: -90, max: 90) - 0.5) < 1e-9)
    check("fraction clamps below range",
      HardwareModel.fraction(value: -200, min: -90, max: 90) == 0)
    check("fraction clamps above range",
      HardwareModel.fraction(value: 200, min: -90, max: 90) == 1)
    check("degenerate limits do not divide by zero",
      HardwareModel.fraction(value: 5, min: 10, max: 10) == 0)
    check("pulse maps 0.5 to the midpoint",
      abs(HardwareModel.pulse(fraction: 0.5, minPulse: 500, maxPulse: 2500) - 1500) < 1e-9)

    // Binding against a real rig.
    let rig = RigModel.shared
    let hw = HardwareModel.shared
    let ids = fixtureParts(5)
    rig.mates.removeAll()
    hw.channels.removeAll()

    rig.selectedParts = [ids[0], ids[1]]
    guard let revolute = rig.addMate(.revolute) else {
      check("mate available for binding", false)
      return
    }
    rig.selectedParts = [ids[2], ids[3]]
    _ = rig.addMate(.fastened)   // not driven — should NOT get a channel

    hw.sync()
    check("one channel per driven mate", hw.channels.count == 1, "got \(hw.channels.count)")
    check("channel bound to the revolute", hw.channels.first?.mateID == revolute.id)
    check("channel names follow the mate", hw.channels.first?.name == revolute.name)

    // Live value follows the rig (this is what playback drives).
    if let index = rig.mates.firstIndex(where: { $0.id == revolute.id }) {
      rig.mates[index].value = 45
    }
    if let channel = hw.channels.first {
      check("live angle tracks the mate", abs(hw.degrees(channel) - 45) < 1e-9)
      check("live fraction inside 0...1", (0...1).contains(hw.fraction(channel)))
      // Manual jog writes back into the rig.
      hw.setDegrees(channel, to: -30)
      check("jogging a servo drives the mate",
        abs((rig.mates.first { $0.id == revolute.id }?.value ?? 0) + 30) < 1e-9)
    }

    // Removing the mate drops its channel.
    rig.mates.removeAll { $0.id == revolute.id }
    hw.sync()
    check("channel released when its mate is deleted",
      !hw.channels.contains { $0.mateID == revolute.id })

    rig.mates.removeAll()
    rig.selectedParts = []
    hw.channels.removeAll()
    hw.armed = false
  }

  // MARK: - Persistence

  static func persistence() {
    print("\nPersistence")
    let rig = RigModel.shared
    let anim = AnimationModel.shared
    let hw = HardwareModel.shared

    // Author a small project.
    let ids = fixtureParts(3)
    rig.mates.removeAll()
    hw.channels.removeAll()
    rig.selectedParts = [ids[0], ids[1]]
    guard let mate = rig.addMate(.revolute) else {
      check("mate available to save", false)
      return
    }
    anim.clips = [Clip(name: "Wave", duration: 5)]
    anim.selectedClipID = anim.clips[0].id
    anim.time = 1
    anim.addKey(for: mate.id, value: 30)
    hw.sync()
    RenderState.shared.theme = .named("Blueprint")

    let saved = ProjectStore.snapshot(name: "TestProject")
    check("snapshot captures the character", saved.characters.count == 1)
    check("snapshot captures mates on the character",
      saved.characters.first?.mates.count == 1)
    check("snapshot captures character parts",
      saved.characters.first?.parts.count == 3)
    check("snapshot captures clips", saved.clips.count == 1)
    check("snapshot captures channels", saved.channels.count == 1)
    check("snapshot captures theme", saved.themeName == "Blueprint")

    // JSON round-trip.
    do {
      let data = try ProjectStore.encode(saved)
      let restored = try ProjectStore.decode(data)
      check("round-trips through JSON", restored == saved)
      check("mate identity survives", restored.characters.first?.mates.first?.id == mate.id)
      check("part identity survives",
        restored.characters.first?.parts.first?.id == ids[0])
      check("keyframe values survive",
        restored.clips.first?.tracks.first?.keys.first?.value == 30)
      check("track still points at its mate",
        restored.clips.first?.tracks.first?.mateID == mate.id)
      check("channel still bound to its mate", restored.channels.first?.mateID == mate.id)

      // Restoring into a cleared app rebuilds the authored state.
      ProjectStore.newProject()
      check("new project clears mates", rig.mates.isEmpty)
      check("new project clears channels", hw.channels.isEmpty)

      ProjectStore.restoreState(from: restored)
      check("restore brings mates back", rig.mates.count == 1)
      check("restore brings character parts back", rig.parts.count == 3)
      check("restore brings clips back", anim.clips.first?.name == "Wave")
      check("restore brings channels back", hw.channels.count == 1)
      check("restore applies the theme", RenderState.shared.theme.name == "Blueprint")

      // Animation still drives the restored mate through the restored track.
      anim.scrub(toProgress: 1)
      check("restored animation drives the restored mate",
        abs((rig.mates.first?.value ?? 0) - 30) < 1e-9)
    } catch {
      check("round-trips through JSON", false, "\(error)")
    }

    // Write/read an actual file.
    let tmp = FileManager.default.temporaryDirectory
      .appendingPathComponent("selftest-\(UUID().uuidString).animastudio")
    do {
      try ProjectStore.write(to: tmp, name: "TestProject")
      let reread = try ProjectStore.read(from: tmp)
      check("writes and reads a document on disk",
        reread.characters.first?.mates.count == 1)
      try? FileManager.default.removeItem(at: tmp)
    } catch {
      check("writes and reads a document on disk", false, "\(error)")
    }

    ProjectStore.newProject()
    RenderState.shared.theme = .studioBlue
    rig.selectedParts = []
  }

  // MARK: - Project folders

  static func projectFolder() {
    print("\nProject folders")
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("selftest-\(UUID().uuidString)")
    let folder = root.appendingPathComponent("My Project")

    do {
      let meta = try StudioProject.createSkeleton(at: folder, name: "My Project")
      check("project.json written", StudioProject.isProjectFolder(folder))
      check("meta carries the name", meta.name == "My Project")
      for child in ["characters", "scenes", "assets"] {
        var isDir: ObjCBool = false
        let exists = fm.fileExists(
          atPath: folder.appendingPathComponent(child).path, isDirectory: &isDir)
        check("\(child)/ created", exists && isDir.boolValue)
      }

      let reread = try StudioProject.readMeta(at: folder)
      check("meta round-trips from disk", reread.name == "My Project")

      // A plain folder is not a project.
      let plain = root.appendingPathComponent("just-a-folder")
      try fm.createDirectory(at: plain, withIntermediateDirectories: true)
      check("a plain folder is rejected", !StudioProject.isProjectFolder(plain))

      // Opening adopts it and records a recent entry.
      RecentProjects.clear()
      try StudioProject.shared.open(folder)
      check("open adopts the project", StudioProject.shared.isOpen)
      check("project name adopted", StudioProject.shared.name == "My Project")
      check("subfolder URLs resolve", StudioProject.shared.charactersURL?.lastPathComponent == "characters")
      check("recents recorded the project", RecentProjects.list().first?.name == "My Project")

      // Re-opening de-dupes rather than stacking.
      try StudioProject.shared.open(folder)
      check("recents de-dupe on re-open", RecentProjects.list().count == 1)

      StudioProject.shared.close()
      check("close clears the project", !StudioProject.shared.isOpen)

      RecentProjects.remove(folder.path)
      check("recents can be removed", RecentProjects.list().isEmpty)
    } catch {
      check("project folder created", false, "\(error)")
    }

    // Archetypes route somewhere real.
    check("hardware character lands in the Character tab",
      StartArchetype.hardwareCharacter.workspace == .character)
    check("show control lands in Show", StartArchetype.showControl.workspace == .show)
    check("digital character is flagged a preview", StartArchetype.digitalCharacter.isPreview)

    try? fm.removeItem(at: root)
    RecentProjects.clear()
  }

  // MARK: - Tool lifecycle (arm → commit → repeat/cancel)

  static func toolLifecycle() {
    print("\nTool lifecycle")
    let tools = ToolState.shared
    let group = RibbonGroup("Create", "plus.square", .teal, [RibbonTool("cube", "Box")])
    let tool = group.tools[0]

    tools.disarm()
    check("starts idle", !tools.isArmed)

    tools.arm(tool, in: group)
    check("arming sets the tool", tools.isArmed && tools.groupName == "Create")
    check("prompt names the tool", tools.prompt.contains("Box"))

    let design = DesignModel.shared
    let viewSide = ViewSidebarState.shared
    design.shapes.removeAll()
    design.place(tool, tint: tools.tint, at: CGPoint(x: 0.5, y: 0.5))
    check("commit places one element", design.shapes.count == 1)
    check("placed element is selected", design.selectedID == design.shapes.first?.id)

    tools.repeats = true
    tools.committed()
    check("stays armed when repeating", tools.isArmed)

    tools.repeats = false
    tools.committed()
    check("disarms when not repeating", !tools.isArmed)

    tools.arm(tool, in: group)
    tools.disarm()
    check("escape disarms", !tools.isArmed)

    design.remove(design.shapes[0].id)
    check("delete clears selection", design.shapes.isEmpty && design.selectedID == nil)
    tools.repeats = true

    // The Design shell's core rule: camera actions and object tools are
    // mutually exclusive, so "move camera" can never be mistaken for
    // "move object".
    tools.arm(tool, in: group)
    viewSide.navMode = .orbit
    ToolState.shared.disarm()
    check("camera action disarms the object tool", !tools.isArmed)
    check("camera nav is independent state", viewSide.navMode == .orbit)
    viewSide.navMode = .select

    // Left rail switches panels; re-clicking the active tab collapses it.
    check("every workspace-sidebar tab has an icon",
      WorkspaceTab.allCases.allSatisfy { !$0.icon.isEmpty })
    check("every view-sidebar tab has an icon",
      ViewTab.allCases.allSatisfy { !$0.icon.isEmpty })
    check("every nav mode has an icon",
      NavMode.allCases.allSatisfy { !$0.icon.isEmpty })
    // The shared panel engine drives both sidebars identically.
    let V = ViewTab.view.rawValue, E = ViewTab.environment.rawValue
    let panels = viewSide.panels
    panels.enabled = [V]; panels.floatingOffset = [:]
    check("view sidebar starts with one panel", panels.isOpen)
    panels.toggle(E)
    check("a second view panel stacks", panels.enabled == [V, E])
    check("stacked order follows the tab order", panels.stacked == [V, E])
    panels.toggle(V)
    check("toggling a panel off leaves the other", panels.enabled == [E])

    // Tear-off: a panel floats out of the stack and docks back.
    panels.enabled = [V, E]; panels.floatingOffset = [:]
    panels.detach(V)
    check("detached panel leaves the stack",
      panels.stacked == [E] && panels.floating == [V])
    check("detached panel has a position", panels.isFloating(V))
    panels.restack(V)
    check("restacked panel returns to the stack",
      panels.stacked == [V, E] && panels.floating.isEmpty)
    panels.toggle(V)
    check("hiding a panel also clears its floating state", !panels.isFloating(V))

    // Exclusive (browser) mode: opening one closes the others.
    let ex = PanelStackState(order: ["A", "B", "C"], defaults: ["A"], side: .left, exclusive: true)
    ex.toggle("B")
    check("exclusive open closes the previous", ex.enabled == ["B"])
    ex.toggle("B")
    check("exclusive re-click collapses", ex.enabled.isEmpty)

    panels.enabled = [V]; panels.floatingOffset = [:]
    check("tool sidebar covers the reference tools",
      DesignTools.primary.count == 13,
      "got \(DesignTools.primary.count)")
    check("palette labels are unique",
      Set(DesignTools.primary.map(\.label)).count == DesignTools.primary.count)

    // Density is presentation only — it must never change the tool catalog.
    let settings = RibbonSettings.shared
    let baseline = DesignTools.primary.map(\.label)
    for density in ToolDensity.allCases {
      settings.density = density
      check("\(density.rawValue) keeps every tool",
        DesignTools.primary.map(\.label) == baseline)
      check("\(density.rawValue) has an icon", !density.icon.isEmpty)
    }
    settings.density = .standard
    check("groups cover the flat catalog",
      DesignTools.groups.flatMap(\.tools).count == DesignTools.primary.count)
    check("every group is named",
      DesignTools.groups.allSatisfy { !$0.name.isEmpty })
  }

  // MARK: - Geometry pipeline

  static func geometry() {
    print("\nGeometry + pivots")
    do {
      let doc = try GeometryDocument.demo()
      check("OCCT demo document loads", doc.triangleCount > 0, "tris=\(doc.triangleCount)")
      check("render projection built", !doc.renderGeometry.positions.isEmpty)
      check("batches carry assembly nodes", !doc.renderGeometry.batches.isEmpty)
      let pivots = RigPose.pivots(for: doc)
      check("per-part pivots computed", !pivots.isEmpty, "count=\(pivots.count)")
      for (node, pivot) in pivots {
        check("pivot \(node) is finite", pivot.x.isFinite && pivot.y.isFinite && pivot.z.isFinite)
        break
      }
    } catch {
      check("OCCT demo document loads", false, "\(error)")
    }
  }
}

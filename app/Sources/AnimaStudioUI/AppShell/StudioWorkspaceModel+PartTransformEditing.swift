import AnimaCADViewport
import AnimaCoreClient
import AnimaModel
import Foundation
import RealityKitViewport
import simd

/// Direct part movement: viewport drags, the transform gizmo, and
/// Inspector edits all land here, and every accepted edit is pushed into
/// the live AnimaCore handle so later pose refreshes keep it.
/// Behavior-preserving extraction from StudioWorkspaceModel (2026-07-31);
/// stored state remains on the model until this becomes its own
/// controller with an owned contract.
extension StudioWorkspaceModel {

  /// Renderer input for the part origin expressed in the assembly frame.
  /// Values are the editable AnimaCore rest transform already projected into
  /// `project.rig`; no pose or mate semantics are reconstructed here.
  func cadPartRestTransform(for id: PartID) -> CADPartRestTransform? {
    guard let part = project.rig.parts.first(where: { $0.id == id }) else { return nil }
    return CADPartRestTransform(
      positionMeters: [part.positionMeters.x, part.positionMeters.y, part.positionMeters.z],
      rotationEulerRadians: [
        part.rotationEulerRadians.x,
        part.rotationEulerRadians.y,
        part.rotationEulerRadians.z,
      ])
  }

  func setPartPosition(id: PartID, to positionMeters: RigVector3) {
    guard !isComponentLocked(id), isPartRestTransformEditable(id),
      positionMeters.x.isFinite, positionMeters.y.isFinite, positionMeters.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].positionMeters = positionMeters
    updateEnginePartTransform(id: id)
  }

  func setPartRotation(id: PartID, to rotationEulerRadians: RigVector3) {
    guard !isComponentLocked(id), isPartRestTransformEditable(id),
      rotationEulerRadians.x.isFinite, rotationEulerRadians.y.isFinite,
      rotationEulerRadians.z.isFinite,
      let index = project.rig.parts.firstIndex(where: { $0.id == id })
    else { return }
    project.rig.parts[index].rotationEulerRadians = rotationEulerRadians
    updateEnginePartTransform(id: id)
  }

  func isPartRestTransformEditable(_ id: PartID) -> Bool {
    guard let part = enginePart(for: id) else { return true }
    if part.isGrounded { return false }
    return !engineMates.contains { !$0.isSuppressed && $0.childPart == part.name }
  }

  func isComponentGroupTransformEditable(_ id: UUID) -> Bool {
    guard !isComponentGroupLocked(id) else { return false }
    let groupIDs = descendantComponentGroupIDs(of: id)
    guard groupIDs.allSatisfy({ !isComponentGroupLocked($0) }) else { return false }
    let partIDs = componentIDs(inGroupIncludingDescendants: id)
    return !partIDs.isEmpty
      && partIDs.allSatisfy {
        !isComponentLocked($0) && isPartRestTransformEditable($0)
      }
  }

  func setComponentGroupTransform(id: UUID, to transform: CADPartRestTransform) {
    guard isComponentGroupTransformEditable(id),
      let groupIndex = componentGroups.firstIndex(where: { $0.id == id }),
      let current = cadComponentGroupTransform(id)
    else { return }
    let delta = transform.matrix * simd_inverse(current.matrix)
    let childGroupIDs = descendantComponentGroupIDs(of: id).subtracting([id])
    let updatedChildTransforms = Dictionary(
      uniqueKeysWithValues: childGroupIDs.compactMap { childID in
        cadComponentGroupTransform(childID).map {
          (childID, $0.applyingAssemblyDelta(delta))
        }
      })
    let updatedPartTransforms = Dictionary(
      uniqueKeysWithValues: componentIDs(inGroupIncludingDescendants: id).compactMap { partID in
        cadPartRestTransform(for: partID).map {
          (partID, $0.applyingAssemblyDelta(delta))
        }
      })

    componentGroups[groupIndex].positionMeters = Self.rigVector(transform.positionMeters)
    componentGroups[groupIndex].rotationEulerRadians =
      Self.rigVector(transform.rotationEulerRadians)
    for (childID, childTransform) in updatedChildTransforms {
      guard let childIndex = componentGroups.firstIndex(where: { $0.id == childID }) else {
        continue
      }
      componentGroups[childIndex].positionMeters = Self.rigVector(childTransform.positionMeters)
      componentGroups[childIndex].rotationEulerRadians =
        Self.rigVector(childTransform.rotationEulerRadians)
    }
    for (partID, partTransform) in updatedPartTransforms {
      setPartPosition(id: partID, to: Self.rigVector(partTransform.positionMeters))
      setPartRotation(id: partID, to: Self.rigVector(partTransform.rotationEulerRadians))
    }
    documentEditRevision += 1
  }

  func updateEnginePartTransform(id: PartID) {
    guard let document = engineRigDocument,
      let name = enginePartName(for: id),
      let part = project.rig.parts.first(where: { $0.id == id })
    else {
      // TEMP transform diagnostics (remove after the regression is fixed).
      StudioDiagLog.append(
        "XFORM-DIAG silent bail id=\(id) hasDoc=\(engineRigDocument != nil) "
          + "engineName=\(enginePartName(for: id) ?? "nil") "
          + "inLocalRig=\(project.rig.parts.contains { $0.id == id }) "
          + "idMapCount=\(enginePartIDsByName.count)")
      return
    }
    do {
      engineRigDocument = try AnimaCoreRigDocumentEditor.settingPartTransform(
        named: name,
        positionMeters: [part.positionMeters.x, part.positionMeters.y, part.positionMeters.z],
        rotationEulerRadians: [
          part.rotationEulerRadians.x,
          part.rotationEulerRadians.y,
          part.rotationEulerRadians.z,
        ],
        in: document
      )
      // Dropping the stale pose keeps direct manipulation responsive; the
      // engine handle is then updated asynchronously below so any later
      // playhead refresh resolves the EDITED transform instead of snapping
      // the part back (the drag-reset regression).
      engineResolvedPartPoses.removeValue(forKey: id)
      documentEditRevision += 1
      StudioDiagLog.append(
        "XFORM-DIAG applied id=\(id) name=\(name) "
          + "pos=[\(part.positionMeters.x), \(part.positionMeters.y), \(part.positionMeters.z)]")
      schedulePartTransformPush(id: id)
    } catch {
      animaCoreErrorMessage = error.localizedDescription
    }
  }

  /// Pushes one part's edited canonical entry into the live engine handle via
  /// `update_part`. Task-latest: rapid drag updates cancel the prior push so
  /// only the newest transform reaches the engine.
  func schedulePartTransformPush(id: PartID) {
    enginePartTransformPushRevision += 1
    let revision = enginePartTransformPushRevision
    enginePartTransformPushTask?.cancel()
    enginePartTransformPushTask = Task { [weak self] in
      await self?.pushPartTransformToEngine(id: id, revision: revision)
    }
  }

  /// Awaits the in-flight `update_part` push. Tests use this to make the
  /// asynchronous drag → engine handoff deterministic.
  func flushPendingEnginePartTransformPush() async {
    await enginePartTransformPushTask?.value
  }

  func pushPartTransformToEngine(id: PartID, revision: Int) async {
    guard let animaCoreClient, let handle = animaCoreHandle,
      let document = engineRigDocument,
      let name = enginePartName(for: id)
    else { return }
    do {
      let partDocument = try AnimaCoreRigDocumentEditor.partDocument(
        named: name, from: document)
      _ = try await animaCoreClient.updatePart(handle: handle, part: partDocument)
      // The local engineRigDocument already carries this edit; adopting the
      // response here could clobber a mate/relation commit that landed while
      // the push was in flight, so success needs no further state change.
    } catch is CancellationError {
      return
    } catch {
      guard revision == enginePartTransformPushRevision else { return }
      animaCoreErrorMessage = error.localizedDescription
    }
  }
}

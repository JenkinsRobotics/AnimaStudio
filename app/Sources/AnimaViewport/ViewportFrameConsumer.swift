import AnimaEvaluation

@MainActor
public protocol ViewportFrameConsumer: AnyObject {
  func display(frame: EvaluatedFrame)
}

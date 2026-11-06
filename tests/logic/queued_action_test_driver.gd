extends RefCounted
## Advance the real visual walker deterministically without wall-clock sleeps.
static func finish(scene: FieldPrototypePresenter) -> bool:
	if scene.world_view.farmer_agent == null:
		return false
	for step: int in range(6000):
		if not scene.farming_controller.has_pending_actions():
			return true
		scene.world_view.farmer_agent._process(1.0 / 60.0)
	return false

extends Node
## Ad abstraction. Template file: copy unchanged to every game.
##
## v0.1 is a stub: it fires signals and logs, so gameplay code is already
## written against the final interface. When integrating a real network
## (AdMob via the official Godot plugin, or AppLovin MAX), only this file
## changes — no gameplay code is touched.

signal interstitial_closed
signal rewarded_completed(reward_granted: bool)

func maybe_show_interstitial() -> void:
	## Call on game over (fire-and-forget), then `await Ads.interstitial_closed`.
	## Frequency is remote-config driven so it can be tuned live without an
	## app update. The emit is deferred one frame so callers' awaits always
	## register before the signal fires.
	var every_n: int = int(Backend.cfg("interstitial_every_n_deaths", 3))
	if every_n > 0 and GameState.total_deaths > 0 and GameState.total_deaths % every_n == 0:
		Analytics.track("ad_interstitial_shown", {"death_count": GameState.total_deaths})
		# TODO real ad call here; stub closes after one frame:
	await get_tree().process_frame
	interstitial_closed.emit()

func show_rewarded() -> void:
	Analytics.track("ad_rewarded_requested", {})
	# TODO real ad call here; stub grants after one frame:
	await get_tree().process_frame
	rewarded_completed.emit(true)

class_name Updater
extends Node
## Self updater: checks the GitHub releases feed on launch, downloads the
## matching binary for this CPU and swaps itself on restart.
## Debug flags: --pretend-old forces an update offer, --auto-update-now
## installs without clicking (used by automated tests).

signal update_available(version: String)
signal status(text: String)

const REPO := "OutBlade/neon-harbor"
const HEADERS: PackedStringArray = ["User-Agent: NeonHarbor-Updater", "Accept: application/vnd.github+json"]

var latest := ""
var asset_url := ""
var downloading := false

func check() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_check_done.bind(req))
	var err := req.request("https://api.github.com/repos/%s/releases/latest" % REPO, HEADERS)
	if err != OK:
		req.queue_free()

func _on_check_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	latest = str(data.get("tag_name", "")).trim_prefix("v")
	var current := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	if "--pretend-old" in OS.get_cmdline_user_args():
		current = "0.0.1"
	if not _is_newer(latest, current):
		print("Updater: up to date (%s)" % current)
		return
	var arch_tag := "win-arm64" if OS.has_feature("arm64") else "win-x64"
	for a in data.get("assets", []):
		var name_: String = a.get("name", "")
		if arch_tag in name_ and name_.ends_with(".exe") and not "Setup" in name_:
			asset_url = a.get("browser_download_url", "")
			break
	if asset_url == "":
		return
	print("Updater: update available v%s, asset %s" % [latest, asset_url])
	update_available.emit(latest)
	if "--auto-update-now" in OS.get_cmdline_user_args():
		download_and_install()

func _is_newer(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in 3:
		var na := int(pa[i]) if i < pa.size() else 0
		var nb := int(pb[i]) if i < pb.size() else 0
		if na != nb:
			return na > nb
	return false

func download_and_install() -> void:
	if downloading or asset_url == "":
		return
	downloading = true
	status.emit("Downloading v%s..." % latest)
	var req := HTTPRequest.new()
	add_child(req)
	req.download_file = "user://update.exe"
	req.request_completed.connect(_on_download_done.bind(req))
	var err := req.request(asset_url, HEADERS)
	if err != OK:
		downloading = false
		req.queue_free()
		status.emit("Update failed to start")

func _on_download_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status.emit("Download failed. Opening the releases page instead")
		OS.shell_open("https://github.com/%s/releases/latest" % REPO)
		return
	if OS.has_feature("editor"):
		status.emit("Editor run: downloaded to user://update.exe, not swapping")
		print("Updater: editor run, swap skipped")
		return
	# cmd.exe needs backslashes; Godot paths come with forward slashes.
	var exe := OS.get_executable_path().replace("/", "\\")
	var new_file := ProjectSettings.globalize_path("user://update.exe").replace("/", "\\")
	var bat_path := ProjectSettings.globalize_path("user://apply_update.bat").replace("/", "\\")
	var f := FileAccess.open(bat_path, FileAccess.WRITE)
	if f == null:
		status.emit("Could not write updater script")
		return
	f.store_string("\r\n".join([
		"@echo off",
		"title Neon Harbor updater",
		"echo Updating Neon Harbor to v%s ..." % latest,
		"set tries=0",
		":loop",
		"timeout /t 1 /nobreak >nul",
		"set /a tries+=1",
		"if %tries% gtr 30 goto fail",
		"copy /y \"" + new_file + "\" \"" + exe + "\" >nul 2>&1",
		"if errorlevel 1 goto loop",
		"del \"" + new_file + "\" >nul 2>&1",
		"start \"\" \"" + exe + "\"",
		"del \"%~f0\"",
		"exit",
		":fail",
		"echo Update failed, the game file was locked.",
		"pause",
	]))
	f.flush()
	f = null
	status.emit("Restarting to finish the update")
	OS.create_process("cmd.exe", ["/c", bat_path])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()

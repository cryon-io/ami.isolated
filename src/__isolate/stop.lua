local _ok, _systemctl = am.plugin.safe_get("systemctl")
ami_assert(_ok, "Failed to load systemctl plugin")

local _ok, _error = _systemctl.safe_stop_service(am.app.get("id") .. "-" .. am.app.get_model("SERVICE_NAME", "isolated"))
ami_assert(_ok, "Failed to stop " .. am.app.get("id") .. "-" .. am.app.get_model("SERVICE_NAME", "isolated") .. ".service " .. (_error or ""))

log_success("App services succesfully stopped.")

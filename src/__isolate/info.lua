local _json = am.options.OUTPUT_FORMAT == "json"

local _ok, _systemctl = am.plugin.safe_get("systemctl")
ami_assert(_ok, "Failed to load systemctl plugin", EXIT_PLUGIN_LOAD_ERROR)

local _appId = am.app.get("id", "unknown")
local _ok, _status = _systemctl.safe_get_service_status(_appId .. "-" .. am.app.get_model("SERVICE_NAME", "isolated"))
ami_assert(_ok, "Failed to start " .. _appId .. "-" .. am.app.get_model("SERVICE_NAME", "isolated") .. " " .. (_status or ""), EXIT_PLUGIN_EXEC_ERROR)

local _info = {
    isolated_app = _status,
    level = "ok",
    version = am.app.get_version(),
    type = am.app.get_type() .. "-" .. am.app.get({ "app", "type" }, "unknown")
}

if _info.isolated_app == "running" then
    am.execute("pass")
else
    _info.level = "error"
    if _json then
        print(hjson.stringify_to_json(_info, {indent = false}))
    else
        print(hjson.stringify(_info))
    end
end


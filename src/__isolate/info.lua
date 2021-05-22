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
    local _ok, _podman = am.plugin.safe_get("podman")
    ami_assert(_ok, "Failed to load podman plugin - " .. tostring(_podman), EXIT_PLUGIN_LOAD_ERROR)
    local _user = am.app.get("user", "root")
    local _args = {}
    for _, _arg in ipairs(am.get_proc_args()) do
        if type(_arg) == "string" and not _arg:match("^%-%-local%-sources=") then
            table.insert(_args, _arg)
        end
    end
    _podman.exec(_appId .. "_isolated", string.join_strings(" ", "ami", table.unpack(_args)), {runas = _user, stdPassthrough = true })
else
    _info.level = "error"
    if _json then
        print(hjson.stringify_to_json(_info, {indent = false}))
    else
        print(hjson.stringify(_info))
    end
end


if type(am.app.get_config()) ~= "table" then
    ami_error("Configuration not found...", EXIT_INVALID_CONFIGURATION)
end

local _entry = am.app.get_config("entrypoint", "/lib/systemd/systemd")

local _args = am.app.get_config("STARTUP_ARGS", {})
local _addr = am.app.get_config("OUTBOUND_ADDR")
if type(_addr) == "string"  then 
   table.insert(_args, "--network=slirp4netns:outbound_addr=" .. _addr)
end
  
am.app.set_model(
    {
        SERVICE_CONFIGURATION = util.merge_tables(
            {
                TimeoutStopSec = 315, -- 300 standard systemctl timeout used by ami apps
            },
            type(am.app.get_config("SERVICE_CONFIGURATION")) == "table" and am.app.get_config("SERVICE_CONFIGURATION") or {},
            true
        ),
        ENTRYPOINT = _entry,
        DATA_DIR = path.combine(os.cwd(), "data"),
        ADDITIONAL_LIBS = am.app.get_config("ADDITIONAL_LIBS", {}),
        ENABLE_LINGER = am.app.get_config("ENABLE_LINGER", am.app.get("user", "root") ~= "root" and _entry:match("systemd")),
        STARTUP_ARGS = _args
    }
)

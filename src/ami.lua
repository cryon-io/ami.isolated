local _nestedInterface = {}
if fs.exists("data/ami.lua") then
    local _ok, _new_base = pcall(loadfile, "data/ami.lua")
    if not _ok then
        log_warn("Failed to load interface of isolated app - " .. ("data/ami.lua" or "undefined") .. "!")
    end
    _ok, _nestedInterface = pcall(_new_base)
    if not _ok then
        log_warn("Failed to load interface of isolated app - " .. ("data/ami.lua" or "undefined") .. "!")
    end
end

local function _pass_to_nested_app()
    local _ok, _podman = am.plugin.safe_get("podman")
    ami_assert(_ok, "Failed to load podman plugin - " .. tostring(_podman), EXIT_PLUGIN_LOAD_ERROR)
    local _appId = am.app.get("id") .. "_isolated"
    local _user = am.app.get("user", "root")
    local _args = {}
	local _patternsToIgnore = {
		"^%-%-local%-sources=",
		"^%-local%-sources=",
		"^%-%-ls=",
		"^%-ls=",
		"^%-%-path=",
		"^%-path=",
		"^%-%-p=",
		"^%-p=",
	}
    for _, _arg in ipairs(am.get_proc_args()) do
		-- skip non string args and pass arg
		if type(_arg) ~= "string" or _arg == "pass" then goto CONTINUE end

		-- skip local-sources and path arg
		for _, _pattern in ipairs(_patternsToIgnore) do
			if _arg:match(_pattern) then goto CONTINUE end
		end
      
		table.insert(_args, _arg)
		::CONTINUE::
    end
    _podman.exec(_appId, string.join_strings(" ", "ami", table.unpack(_args)), {runas = _user, stdPassthrough = true })
end

-- we proxy only top level commands (anything nested will be proxied through these anyway)
if type(_nestedInterface) == "table" then
    if type(_nestedInterface.commands) == "table" and not util.is_array(_nestedInterface.commands) then
        for _, _cmd in pairs(_nestedInterface.commands) do
            _cmd.action = _pass_to_nested_app
        end
    end
end

local _commands = {
    setup = {
        options = {
            configure = {
                description = "Configures application, renders templates and installs services"
            },
            environment = {
                index = 0,
                aliases = {"env"},
                description = "Creates application environment"
            }
        },
        action = function(_options, _, _, _)
            local _noOptions = #table.keys(_options) == 0
            if _noOptions or _options.environment then
                am.app.prepare()
            end

            if _noOptions or _options.configure then
                am.app.render()
                -- runs setup inside pod as well
                am.execute_extension("__isolate/configure.lua", {contextFailExitCode = EXIT_APP_CONFIGURE_ERROR})
            end
        end
    },
    start = {
        description = "ami 'start' sub command",
        summary = "Starts the isolated app",
        action = "__isolate/start.lua",
        contextFailExitCode = EXIT_APP_START_ERROR
    },
    stop = {
        description = "ami 'stop' sub command",
        summary = "Stops the isolated app",
        action = "__isolate/stop.lua",
        contextFailExitCode = EXIT_APP_STOP_ERROR
    },
    validate = {
        description = "ami 'validate' sub command",
        summary = "Validates app configuration and platform support",
        action = function(_options, _, _, _cli)
            if _options.help then
                am.print_help(_cli)
                return
            end
            -- //TODO: Validate platform
            ami_assert(proc.EPROC, "etho node AMI requires extra api - eli.proc.extra", EXIT_MISSING_API)
            ami_assert(fs.EFS, "etho node AMI requires extra api - eli.fs.extra", EXIT_MISSING_API)

            ami_assert(type(am.app.get("id")) == "string", "id not specified!", EXIT_INVALID_CONFIGURATION)
            ami_assert(type(am.app.get_config()) == "table", "configuration not found in app.h/json!", EXIT_INVALID_CONFIGURATION)
            ami_assert(type(am.app.get("app_configuration")) == "table", "app_configuration not found in app.h/json!", EXIT_INVALID_CONFIGURATION)
            ami_assert(type(am.app.get_type()) == "table" or type(am.app.get_type()) == "string", "Invalid app type!", EXIT_INVALID_CONFIGURATION)
            log_success("isolate.pod configuration validated.")
        end
    },
    info = {
        description = "ami 'info' sub command",
        summary = "Display information about isolated app",
        action = "__isolate/info.lua",
        contextFailExitCode = EXIT_APP_INFO_ERROR
    },
    remove = {
        index = 7,
		options = {
			all = {
				description = "Removes entire application!"
			}
		},
        action = function(_options, _, _, _cli)
            if _options.all then
                am.app.remove()
                log_success("Application removed.")
            else
                am.app.remove_data()
                log_success("Application data removed successfully")
            end
            return
        end
    },
    pass = {
       description = "ami 'pass' sub command",
       summary = "Passes any passed arguments directly to isolated app. (Isolated app has to be running.)",
       index = 8, 
       type = "raw",
       action = _pass_to_nested_app,
       contextFailExitCode = EXIT_APP_INTERNAL_ERROR
    },
    ["podman-system-prune"] = {
        action = function()
            local _ok, _podman = am.plugin.safe_get("podman")
            ami_assert(_ok, "Failed to load podman plugin - " .. tostring(_podman), EXIT_PLUGIN_LOAD_ERROR)
            local _user = am.app.get("user", "root")
            _podman.raw_exec("system prune -a -f", { runas = _user })
        end
    }
}

return util.merge_tables(
    _nestedInterface,
    {
        title = "Isolated app interface - isolate.pod",
        base = "base",
        commands = _commands
    },
    true
)

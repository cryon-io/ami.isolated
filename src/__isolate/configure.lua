local _user = am.app.get("user", "root")
local _appId = am.app.get("id")

local _ok, _uid = fs.safe_getuid(_user)
if not _ok or not _uid then
    log_info("Creating user - " .. _user .. "...")
    local _ok = os.execute('adduser --disabled-login --disabled-password --gecos "" ' .. _user)
    ami_assert(_ok, "Failed to create user - " .. _user, EXIT_INVALID_CONFIGURATION)
    log_info("User " .. _user .. " created.")
else
    log_info("User " .. _user .. " found.")
end

local _unprivilegedPortStart = am.app.get_configuration("UNPRIVILEGED_PORT_START")
if _user ~= "root" and type(_unprivilegedPortStart) == "string" or type(_unprivilegedPortStart) == "number" then 
	log_trace("Non root user with custom UNPRIVILEGED_PORT_START. Setting net.ipv4.ip_unprivileged_port_start...")
	local _sysctl = am.plugin.get("sysctl")
	local _ok, _port = _sysctl.safe_get("net.ipv4.ip_unprivileged_port_start")
	ami_assert(_ok, "Failed to determine net.ipv4.ip_unprivileged_port_start. Can not configure UNPRIVILEGED_PORT_START!")
	if tonumber(_port) <= tonumber(_unprivilegedPortStart) then 
		log_info("UNPRIVILEGED_PORT_START (net.ipv4.ip_unprivileged_port_start) already configured to required value.")
	else
		local _ok = _sysctl.safe_set("net.ipv4.ip_unprivileged_port_start", _unprivilegedPortStart)
		ami_assert(_ok, "Failed to set net.ipv4.ip_unprivileged_port_start to " .. _unprivilegedPortStart .. "!")
		log_success("UNPRIVILEGED_PORT_START (net.ipv4.ip_unprivileged_port_start) set configured to required value.")
	end
end

local _containersConfig = "/home/".._user.."/.config/containers/containers.conf"
if _user ~= "root" and not fs.exists(_containersConfig) then 
   log_trace("Containers configuration not found. Default configuration will be added into " .. _containersConfig .. ".")
   local _ok, _error = fs.safe_mkdirp(path.dir(_containersConfig))
   ami_assert(_ok, "Failed to create directory for containers configuration - ".. (_error or ''))
   local _ok, _error = fs.safe_write_file(_containersConfig, '[engine]\ncgroup_manager = "cgroupfs"')
   ami_assert(_ok, "Failed to initialize containers configuration - ".. (_error or ''))
end

if am.app.get_model("ENABLE_LINGER") then 
   ami_assert(os.execute("loginctl enable-linger " .. _user), "Failed to enable linger for user - " .. _user .. ".")
end

local _image = am.app.get_config("image", "ubuntu_systemd")
local _ok, _podman = am.plugin.safe_get("podman")
ami_assert(_ok, "Failed to load podman plugin - " .. tostring(_podman))
_podman.install() -- setup podman

local _imageId = "ami_isolate_" .. _appId .. "_tmp"
local _ok, _error = fs.safe_chown("__isolate/assets/recipes", _uid, _uid, { recurse = true })
if not _ok then
    ami_error("Failed to chown __isolate/assets/recipes - " .. (_error or ""))
end

-- remove preexisting image
_podman.raw_exec("image rm -f ami_isolate_" .. _appId, { runas = _user })
-- build new image
_podman.build(path.combine("__isolate/assets/recipes", _image), _imageId, { runas = _user })

local _ok, _systemctl = am.plugin.safe_get("systemctl")
ami_assert(_ok, "Failed to load systemctl plugin - " .. tostring(_systemctl))

local _addLibs = am.app.get_model("ADDITIONAL_LIBS")
if util.is_array(_addLibs) then   
  for _, _lib in ipairs(_addLibs) do 
      local _ok, _error = _podman.safe_install_lib(_lib)
      if not _ok then 
         log_warn("Failed to install " .. _lib .. " - " .. _error .. "!")
      end
  end
end

local _ok, _error = _systemctl.safe_install_service("__isolate/assets/isolated.service",  am.app.get("id") .. "-" .. am.app.get_model("SERVICE_NAME", "isolated"))
ami_assert(_ok, "Failed to install " .. am.app.get("id") .. "-" .. am.app.get_model("SERVICE_NAME", "isolated") .. ".service " .. (_error or ""))

local _appConfiguration = am.app.get("app")
local _ok, _error = fs.safe_mkdir("data")
ami_assert(_ok, "Failed to create app directory - " .. (_error or "") .. "!")

if type(_appConfiguration.id) ~= "string" then
    _appConfiguration.id = _appId
end
if type(_appConfiguration.user) ~= "string" then
    _appConfiguration.user = _user
end

local _ok, _error = fs.safe_write_file(path.combine(am.app.get_model("DATA_DIR"), "app.hjson"), hjson.stringify(_appConfiguration))
ami_assert(_ok, "Failed to write isolated app.hjson - " .. (_error or "") .. "!")

local _ok, _error = fs.safe_chown(am.app.get_model("DATA_DIR"), _uid, _uid, { recurse = true })
if not _ok then
    ami_error("Failed to chown data directory - " .. (_error or "") .. "!")
end

_podman.raw_exec("rm -f " .. _appId .. "_tmp", { runas = _user })
local _ok = _podman.run(_imageId, "ami setup", { runas = _user, container = _appId .. "_tmp", args = "-it --mount 'type=bind,src=" .. am.app.get_model("DATA_DIR") .. ",target=/app'", useOsExec = true })
assert(_ok, "Failed to setup isolated app!")
local _result = _podman.raw_exec("commit " ..  _appId .. "_tmp ami_isolate_" .. _appId, { runas = _user })
assert(_result.exitcode == 0, "Failed to create isolated app container image!")
local _result = _podman.raw_exec("image rm -f " .. _imageId, { runas = _user })
if _result.exitcode ~= 0 then 
   log_warn("Failed to remove temporary container image: " .. _imageId .. "!")
end

-- http://lua-users.org/wiki/StringTrim
function trim6(s)
   return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function get_config()
  return vim.g.dark_switcher_config or {}
end

-- See https://github.com/neovim/neovim/issues/12544
function edit_config(fn)
  local edit = vim.g.dark_switcher_config or {}
  fn(edit)
  vim.g.dark_switcher_config = edit
end

function apply_mode(mode)
  local config = get_config()
  local sel = config.schemes[mode] or {}
  local name = sel.name or nil
  local bg = sel.background or mode
  local lltheme = sel.lightline or nil

  vim.api.nvim_command('set background=' .. bg)
  if name ~= nil then
    vim.api.nvim_command('colorscheme ' .. name)
  end

  -- now try to reload lightline
  local reloader = config.lightline_loaders[lltheme]
  local lightline = vim.call("exists", "g:loaded_lightline")

  if lightline == 1 then
    local update = false
    if lltheme ~= nil then
      vim.api.nvim_command("let g:lightline.colorscheme = \"" .. lltheme .. "\"")
      update = true
    end
    if reloader ~= nil then
      vim.api.nvim_command("source " .. reloader)
      update = true
    end
    if update then
      vim.api.nvim_command("call lightline#init()")
      vim.api.nvim_command("call lightline#colorscheme()")
      vim.api.nvim_command("call lightline#update()")
    end
  end
end

function apply_current_mode()
  local mode = vim.fn.system('dark-notify --exit')
  mode = trim6(mode)
  apply_mode(mode)
end

function init_dark_notify()
  -- Docs on this vim.loop stuff: https://github.com/luvit/luv

  local function onclose()
  end

  local handle, pid
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local stdin = vim.loop.new_pipe(false)

  local function onread(err, chunk)
    assert(not err, err)
    if (chunk) then
      local mode = trim6(chunk)
      if not (mode == "light" or mode == "dark") then
        error("dark-notify output not expected: " .. chunk)
        return
      end
      apply_mode(mode)
    end
  end

  local function onshutdown(err)
    if err == "ECANCELED" then
      return
    end
    vim.loop.close(handle, onclose)
    edit_config(function (conf)
      conf.initialized = false
    end)
  end

  local function onexit()
    edit_config(function (conf)
      conf.initialized = false
    end)
  end

  handle, pid = vim.loop.spawn(
    "dark-notify",
    { stdio = {stdin, stdout, stderr} },
    vim.schedule_wrap(onexit)
  )

  vim.loop.read_start(stdout, vim.schedule_wrap(onread))
  edit_config(function (conf)
    conf.initialized = true
  end)
end

function run(config)
  local lightline_loaders = config.lightline_loaders or {}
  local schemes = config.schemes or {}

  for _, mode in pairs({ "light", "dark" }) do
    if type(schemes[mode]) == "string" then
      schemes[mode] = { name = schemes[mode] }
    end
  end

  edit_config(function (conf)
    conf.lightline_loaders = lightline_loaders
    conf.schemes = schemes
  end)

  if not get_config().initialized then
    init_dark_notify()
  else
    apply_current_mode()
  end
end

return { run=run, update=apply_current_mode }

-- init.lua or init.vim in a lua <<EOF
-- require('dark_notify').run({
--  lightline_loaders = {
--    my_colorscheme = "path_to_my_colorscheme's lightline autoload file"
--  },
--  schemes {
--    dark  = "dark colorscheme name",
--    light = { name = "light scheme name", background = "optional override, either light or dark" }
--  }
-- })

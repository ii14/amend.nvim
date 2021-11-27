local M = {}

-- TODO: c C s S (save inserted text)
-- TODO: extensions, somehow. surround, commentary, targets
-- TODO: figure out what's up with targets.vim and why it's messing up {i,a} commands

-- last action
local last = nil
-- buffer
local buf = nil
-- current position in the tree
local pos = nil

-- keep visited tables, so they're preprocessed only once
local s1 = {}
local s2 = {}

--- Preprocess tree
---@param tree table<string, table|boolean>
local function preprocess(tree)
  -- step 1: expand keys
  local function step1(t)
    if s1[t] then return t end
    local keys = vim.tbl_keys(t)
    for _, k in ipairs(keys) do
      local v = t[k]
      if type(v) == 'table' then
        v = step1(v)
      end
      if type(k) == 'table' then
        for _, sk in ipairs(k) do
          t[sk] = v
        end
        t[k] = nil
      else
        t[k] = v
      end
    end
    s1[t] = true
    return t
  end

  -- step 2: expand count
  local function step2(t)
    if s2[t] then return t end
    for k, v in pairs(t) do
      if type(v) == 'table' then
        t[k] = step2(v)
      end
    end

    local num = t['%d']
    if num then
      t['%d'] = nil

      num['0'] = num
      num['1'] = num
      num['2'] = num
      num['3'] = num
      num['4'] = num
      num['5'] = num
      num['6'] = num
      num['7'] = num
      num['8'] = num
      num['9'] = num

      t['1'] = num
      t['2'] = num
      t['3'] = num
      t['4'] = num
      t['5'] = num
      t['6'] = num
      t['7'] = num
      t['8'] = num
      t['9'] = num
    end

    s2[t] = true
    return t
  end

  tree = step1(tree)
  tree = step2(tree)
  return tree
end

--- Split string to array of characters
---@param  str string
---@return string[]
local function s(str)
  local res = {}
  for c in str:gmatch('.') do
    table.insert(res, c)
  end
  return res
end

local tree = (function()
  local regs = s'"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-*+_/'

  local marks = preprocess {
    [s'0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ[]<>\'`"^.(){}'] = true,
  }

  local g = preprocess {
    [s'geEjkmM0$^_;,'] = true,
    ["'"] = marks,
    ['`'] = marks,
  }

  local ia = preprocess { [s'wWsp][)(b><t}{B"\'`'] = true }
  local bs = preprocess { [s'[]()mM#*/\'`'] = true }

  local motions = 'hjklwWbBeEG(){}$^_-+;,HML'

  local function any(char)
    return char:match('%C') ~= nil
  end

  local d = preprocess {
    ['%d'] = {
      [s('d'..motions)] = true,
      ['g'] = g,
      [s'ia'] = ia,
      [s']['] = bs,
      [s"'`"] = marks,
      [s'fFtT'] = any,
    },
    [s('d'..motions)] = true,
    ['g'] = g,
    [s'ia'] = ia,
    [s']['] = bs,
    [s"'`"] = marks,
    [s'fFtT'] = any,
  }

  local y = preprocess {
    ['%d'] = {
      [s('y'..motions)] = true,
      ['g'] = g,
      [s'ia'] = ia,
      [s']['] = bs,
      [s"'`"] = marks,
      [s'fFtT'] = any,
    },
    [s('y'..motions)] = true,
    ['g'] = g,
    [s'ia'] = ia,
    [s']['] = bs,
    [s"'`"] = marks,
    [s'fFtT'] = any,
  }

  return preprocess {
    ['"'] = {
      [regs] = {
        ['%d'] = {
          [s'xXDYJ'] = true,
          ['d'] = d,
          ['y'] = y,
        },
        [s'xXDYJ'] = true,
        ['d'] = d,
        ['y'] = y,
      },
    },
    ['%d'] = {
      [s'xXDYJ'] = true,
      ['d'] = d,
      ['y'] = y,
    },
    [s'xXDYJ'] = true,
    ['d'] = d,
    ['y'] = y,
  }
end)()

-- free visited tables
s1 = nil
s2 = nil

local MODES = {
  ['n'] = true,
  ['no'] = true,
  ['nov'] = true,
  ['noV'] = true,
  ['no\22'] = true,
  ['niI'] = true,
  ['niR'] = true,
  ['niV'] = true,
  ['nt'] = true,
}

vim.on_key(function(char)
  -- only insert mode
  if not MODES[vim.api.nvim_get_mode().mode] then
    buf = nil
    pos = nil
    return
  end

  local m

  if pos ~= nil then
    -- there is no way for the nodes at the root to be functions
    -- right now, so this check is only here
    if type(pos) == 'function' then
      m = pos(char)
    else
      m = pos[char]
    end
    if m == true then
      last = (buf or '')..char
      buf = nil
      pos = nil
      return
    elseif m ~= nil and m ~= false then
      buf = (buf or '')..char
      pos = m
      return
    end
  end

  m = tree[char]
  if m == true then
    last = (buf or '')..char
    buf = nil
    pos = nil
    return
  elseif m ~= nil then
    buf = (buf or '')..char
    pos = m
    return
  end

  buf = nil
  pos = nil
end)

local function echoerr(msg)
  vim.api.nvim_echo({{'Amend: '..msg, 'ErrorMsg'}}, true, {})
end

-- TODO: move everything to lua/
function _G.amend(args)
  if not last then
    return echoerr('History is empty')
  end

  if args == '' then
    local res = vim.fn.input('Amend: ', last)
    if not res or res == '' then return end
    vim.api.nvim_feedkeys(res, 't', false)
  elseif args == '?' then
    if not last then
      return echoerr('History is empty')
    end
    print(last)
  else
    local sign, number = args:match('^%s*([%+%-])%s*(%d*)%s*$')
    if not sign or not number then
      return echoerr('Invalid argument')
    end

    if number ~= '' then
      number = tonumber(number)
    else
      number = 1
    end
    if sign == '-' then
      number = -number
    end

    local b, e, m = last:find('(%d+)')
    if b == nil or e == nil or m == nil then
      return echoerr('Last command does not have a count')
    end

    local count = tonumber(m) + number
    if count < 1 then
      count = 1
    end

    local res = last:sub(1, b - 1)..count..last:sub(e + 1)
    vim.api.nvim_feedkeys(res, 't', false)
  end
end

vim.cmd([[command! -nargs=? Amend lua amend(<q-args>)]])
vim.api.nvim_set_keymap('n', 'g.', '<cmd>Amend<CR>', { noremap = true })

return M

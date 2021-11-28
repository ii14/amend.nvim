local M = {}

-- TODO: save inserted text for c/C/s/S
-- TODO: extensions, somehow. surround, commentary, targets
-- TODO: figure out what's up with targets.vim and why it's messing up {i,a} commands


-- STATE
---@type table|function|nil current node in the tree
local node = nil
---@type string|nil buffer
local buf = nil
---@type string|nil last action
local last = nil
---@type string|nil last inserted text
local insert = nil


-- PARSER LOOKUP TABLE
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

    local num = t['<count>']
    if num then
      t['<count>'] = nil

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

local LOOKUP = (function()
  -- registers for "
  local regs = s'"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-*+_/'

  -- marks for '/`/g'/g`
  local marks = preprocess {
    [s'0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ[]<>\'`"^.(){}'] = true,
  }

  -- g motions
  local g = preprocess {
    [s'geEjkmM0$^_;,'] = true,
    [s"'`"] = marks,
  }

  -- i/a motions
  local ia = preprocess { [s'wWsp][)(b><t}{B"\'`'] = true }
  -- ]/[ motions
  local bs = preprocess { [s'[]()mM#*/\'`'] = true }

  -- one character motions
  local motions = 'hjklwWbBeEG(){}$^_-+;,HML'

  -- match any character for f/F/t/T
  local function any(char)
    return char:match('%C') ~= nil
  end

  -- delete command
  local d = preprocess {
    ['<count>'] = {
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

  -- yank command
  local y = preprocess {
    ['<count>'] = {
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

  -- change command
  -- TODO: save inserted text
  local c = preprocess {
    ['<count>'] = {
      [s('c'..motions)] = true,
      ['g'] = g,
      [s'ia'] = ia,
      [s']['] = bs,
      [s"'`"] = marks,
      [s'fFtT'] = any,
    },
    [s('c'..motions)] = true,
    ['g'] = g,
    [s'ia'] = ia,
    [s']['] = bs,
    [s"'`"] = marks,
    [s'fFtT'] = any,
  }

  return preprocess {
    ['"'] = {
      [regs] = {
        ['<count>'] = {
          [s'xXDYJC'] = true,
          ['d'] = d,
          ['y'] = y,
          ['c'] = c,
        },
        [s'xXDYJC'] = true,
        ['d'] = d,
        ['y'] = y,
        ['c'] = c,
      },
    },
    ['<count>'] = {
      [s'xXDYJC'] = true,
      ['d'] = d,
      ['y'] = y,
      ['c'] = c,
    },
    [s'xXDYJC'] = true,
    ['d'] = d,
    ['y'] = y,
    ['c'] = c,
  }
end)()

-- free visited tables
s1 = nil
s2 = nil


-- PARSER
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

local skip = false

local function on_key(char)
  if skip then return end
  -- only insert mode
  if not MODES[vim.api.nvim_get_mode().mode] then
    buf = nil
    node = nil
    return
  end

  local m

  if node ~= nil then
    if type(node) == 'function' then
      m = node(char)
    else
      m = node[char]
    end
    if m == true then
      last = (buf or '')..char
      buf = nil
      node = nil
      return
    elseif m ~= nil and m ~= false then
      buf = (buf or '')..char
      node = m
      return
    end
  end

  m = LOOKUP[char]
  if m == true then
    last = (buf or '')..char
    buf = nil
    node = nil
    return
  elseif m ~= nil and m ~= false then
    buf = (buf or '')..char
    node = m
    return
  end

  buf = nil
  node = nil
end


-- COMMAND
local function echoerr(msg)
  vim.api.nvim_echo({{'Amend: '..msg, 'ErrorMsg'}}, true, {})
end

-- TODO: move everything to lua/
function _G.amend(args, bang)
  bang = bang ~= 0

  if args == '' then
    -- :Amend
    if not last then
      return echoerr('History is empty')
    end
    local res = vim.fn.input('Amend: ', last)
    if not res or res == '' then return end

    if bang then skip = true end
    vim.api.nvim_feedkeys(res, 't', false)
    if bang then vim.schedule(function() skip = false end) end
  elseif args == '?' then
    -- :Amend?
    if bang then
      return echoerr('Invalid argument')
    end
    if not last then
      return echoerr('History is empty')
    end
    print(last)
  else
    -- :Amend{count}
    local sign, number = args:match('^%s*([%+%-])%s*(%d*)%s*$')
    if not sign or not number then
      return echoerr('Invalid argument')
    end

    if not last then
      return echoerr('History is empty')
    end

    if number ~= '' then
      number = tonumber(number)
    else
      number = 1
    end
    if sign == '-' then
      number = -number
    end

    local res
    local b, e, m = last:find('(%d+)')
    if b ~= nil and e ~= nil and m ~= nil then
      local count = tonumber(m) + number
      if count < 1 then
        count = 1
      end
      res = last:sub(1, b - 1)..count..last:sub(e + 1)
    else
      local count = 1 + number
      if count < 1 then
        count = 1
      end
      res = count..last
    end

    if bang then skip = true end
    vim.api.nvim_feedkeys(res, 't', false)
    if bang then vim.schedule(function() skip = false end) end
  end
end


-- SETUP
vim.on_key(on_key)
vim.cmd([[command! -bang -nargs=? Amend call luaeval('amend(_A[1], _A[2])', [<q-args>, <bang>0])]])
vim.api.nvim_set_keymap('n', 'g.', '<cmd>Amend<CR>', { noremap = true })

return M

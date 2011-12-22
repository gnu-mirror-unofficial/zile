-- Curses terminal
--
-- Copyright (c) 2009-2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

local attr_map, codetokey, keytocode, key_buf

local ESC      = 0x1b
local ESCDELAY = 500

local function keypad (on)
  local capstr = curses.tigetstr (on and "smkx" or "rmkx")
  if capstr then
    io.stdout:write (capstr)
    io.stdout:flush ()
  end
end

function term_init ()
  curses.initscr ()

  attr_map = {
    [FONT_REVERSE] = curses.A_REVERSE,
    [FONT_UNDERLINE] = curses.A_UNDERLINE,
  }

  key_buf = {}

  -- from curses key presses to zile keycodes
  codetokey = tree.new ()

  -- from zile keycodes back to curses keypresses
  keytocode = {}

  -- Starting with specially named keys:
  for code, key in pairs {
    [0x9]     = "\\TAB",
    [0xd]     = "\\RET",
    [0x20]    = "\\SPC",
    ["kdch1"] = "\\DELETE",
    ["kcud1"] = "\\DOWN",
    ["kend"]  = "\\END",
    ["kf1"]   = "\\F1",
    ["kf2"]   = "\\F2",
    ["kf3"]   = "\\F3",
    ["kf4"]   = "\\F4",
    ["kf5"]   = "\\F5",
    ["kf6"]   = "\\F6",
    ["kf7"]   = "\\F7",
    ["kf8"]   = "\\F8",
    ["kf9"]   = "\\F9",
    ["kf10"]  = "\\F10",
    ["kf11"]  = "\\F11",
    ["kf12"]  = "\\F12",
    ["khome"] = "\\HOME",
    ["kich1"] = "\\INSERT",
    ["kcub1"] = "\\LEFT",
    ["knp"]   = "\\PAGEDOWN",
    ["kpp"]   = "\\PAGEUP",
    ["kcuf1"] = "\\RIGHT",
    ["kspd"]  = "\\C-z",
    ["kcuu1"] = "\\UP"
  } do
    local codes = nil
    if type (code) == "string" then
      local s = curses.tigetstr (code)
      if s then
        codes = {}
        for i=1,#s do
          table.insert (codes, s:byte (i))
        end
      end
    else
      codes = {code}
    end

    if codes then
      key = keycode (key)
      keytocode[key]   = codes
      codetokey[codes] = key
    end
  end

  -- Reverse lookup of a lone ESC.
  keytocode[keycode "\\e"] = { ESC }

  -- ...fallback on 0x7f for backspace if terminfo doesn't know better
  if not curses.tigetstr ("kbs") then
    keytocode[keycode "\\BACKSPACE"] = {0x7f}
  end
  if not codetokey[{0x7f}] then codetokey[{0x7f}] = keycode "\\BACKSPACE" end

  -- ...inject remaining ASCII key codes
  for code=0,0x7f do
    local key = nil
    if not codetokey[{code}] then
      -- control keys
      if code < 0x20 then
        key = keycode ("\\C-" .. string.lower (string.char (code + 0x40)))

      -- printable keys
      elseif code < 0x80 then
        key = keycode (string.char (code))

      -- meta keys
      else
        local basekey = codetokey[{code - 0x80}]
        if type (basekey) == "table" and basekey.key then
          key = "\\M-" + basekey
        end
      end

      if key ~= nil then
        codetokey[{code}] = key
        keytocode[key]    = {code}
      end
    end
  end

  curses.echo (false)
  curses.nl (false)
  curses.raw (true)
  curses.stdscr ():meta (true)
  curses.stdscr ():intrflush (false)
  curses.stdscr ():keypad (false)

  -- Put terminal in application mode.
  keypad (true)
end

function term_close ()
  -- Revert terminal to cursor mode before exiting.
  keypad (false)

  curses.endwin ()
end

function term_reopen ()
  curses.flushinp ()
  -- FIXME: implement def_shell_mode in lcurses
  --curses.def_shell_mode ()
  curses.doupdate ()
end

function term_getkey_unfiltered (delay)
  if #key_buf > 0 then
    return table.remove (key_buf)
  end

  curses.stdscr ():timeout (delay)

  local c
  repeat
    c = curses.stdscr ():getch ()
    if curses.KEY_RESIZE == c then
      resize_windows ()
    end
  until curses.KEY_RESIZE ~= c

  curses.stdscr ():timeout (-1)

  return c
end

local function unget_codes (codes)
  key_buf = list.concat (key_buf, list.reverse (codes))
end

function term_getkey (delay)
  local codes, key = {}

  local c = term_getkey_unfiltered (delay)
  if c == ESC then
    -- Detecting ESC is tricky...
    c = term_getkey_unfiltered (ESCDELAY)
    if c == nil then
      -- ...if nothing follows quickly enough, assume ESC keypress...
      key = keycode "\\e"
    else
      -- ...see whether the following chars match an escape sequence...
      codes = { ESC }
      while true do
        table.insert (codes, c)
        key = codetokey[codes]
        if key and key.key then
          -- ...return the codes for the matched escape sequence.
          break
        elseif key == nil then
          -- ...no match, rebuffer unmatched chars and return ESC.
          unget_codes (list.tail (codes))
          key = keycode "\\e"
          break
        end
        -- ...partial match, fetch another char and try again.
        c = term_getkey_unfiltered (GETKEY_DEFAULT)
      end
    end
  else
    -- Detecting non-ESC involves fetching chars and matching...
    while true do
      table.insert (codes, c)
      key = codetokey[codes]
      if key and key.key then
        -- ..code lookeup matched a key, return it.
        break
      elseif key == nil then
        -- ...or return nil for an invalid lookup code.
        key = nil
        break
      end
      -- ...for a partial match, fetch another char and try again.
      c = term_getkey_unfiltered (GETKEY_DEFAULT)
    end
  end

  if key == keycode "\\e" then
    local another = term_getkey (GETKEY_DEFAULT)
    if another then key = "\\M-" + another end
  end

  return key
end


-- If key can be represented as an ASCII byte, return it, otherwise
-- return nil.
function term_keytobyte (key)
  local codes = keytocode[key]
  if codes then
    codes = codes[1]
    if 0xff >= codes then
      return codes
    end
  end
  return nil
end


local function keytocodes (key)
  local codevec = {}

  if key ~= nil then
    if key.META then
      codevec = { ESC }
      key = key - "\\M-"
    end

    local code = keytocode[key]
    if code then
      codevec = list.concat (codevec, code)
    end
  end

  return codevec
end

function term_ungetkey (key)
  unget_codes (keytocodes (keycode (key)))
end

function term_buf_len ()
  return #key_buf
end

function term_move (y, x)
  curses.stdscr ():move (y, x)
end

function term_clrtoeol ()
  curses.stdscr ():clrtoeol ()
end

function term_refresh ()
  curses.stdscr ():refresh ()
end

function term_clear ()
  curses.stdscr ():clear ()
end

function term_addch (c)
  curses.stdscr ():addch (c)
end

function term_addstr (s)
  curses.stdscr ():addstr (s)
end

function term_attrset (attrs)
  local cattrs = 0
  for i, v in pairs (attr_map) do
    if bit.band (attrs, i) ~= 0 then
      cattrs = bit.bor (cattrs, v)
    end
  end
  curses.stdscr ():attrset (cattrs)
end

function term_beep ()
  curses.beep ()
end

function term_width ()
  return curses.cols ()
end

function term_height ()
  return curses.lines ()
end

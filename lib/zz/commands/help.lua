-- Self documentation facility commands.
--
-- Copyright (c) 2010-2013 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- This program is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <htt://www.gnu.org/licenses/>.

local eval = require "zz.eval"
local Defun, zz = eval.Defun, eval.sandbox


local function write_function_description (name, doc)
  insert_string (string.format (
     '%s is %s built-in function in ' .. [[`Lua source code']] .. '.\n\n%s',
     name,
     eval.get_function_interactive (name) and 'an interactive' or 'a',
     doc))
end


Defun ("describe_function",
  {"string"},
[[
Display the full documentation of a function.
]],
  true,
  function (func)
    if not func then
      func = minibuf_read_function_name ('Describe function: ')
      if not func then
        return false
      end
    end

    local doc = eval.get_function_doc (func)
    if not doc then
      return false
    else
      write_temp_buffer ('*Help*', true, write_function_description, func, doc)
    end

    return true
  end
)


local function write_key_description (name, doc, binding)
  local _interactive = eval.get_function_interactive (name)
  assert (_interactive ~= nil)

  insert_string (string.format (
    '%s runs the command %s, which is %s built-in\nfunction in ' ..
    [[`Lua source code']] .. '.\n\n%s',
    binding, name, _interactive and 'an interactive' or 'a', doc))
end


Defun ("describe_key",
  {"string"},
[[
Display documentation of the command invoked by a key sequence.
]],
  true,
  function (keystr)
    local func, binding
    if keystr then
      local keys = keystrtovec (keystr)
      if not keys then
        return false
      end
      func = get_function_by_keys (keys, eval.command)
      binding = tostring (keys)
    else
      minibuf_write ('Describe key:')
      local keys = get_key_sequence ()
      func = get_function_by_keys (keys, eval.command)
      binding = tostring (keys)

      if not func then
        return minibuf_error (binding .. ' is undefined')
      end
    end

    local name = tostring (func)
    minibuf_write (string.format ([[%s runs the command `%s']], binding, name))

    if not func.doc then
      return false
    end
    write_temp_buffer ('*Help*', true, write_key_description, name,
                       func.doc, binding)

    return true
  end
)


local function write_variable_description (name, curval, doc)
  insert_string (string.format (
    '%s is a variable defined in ' .. [[`Lua source code']] .. '.\n\n' ..
    'Its value is %s\n\n%s',
    name, curval, doc))
end


Defun ("describe_variable",
  {"string"},
[[
Display the full documentation of a variable.
]],
  true,
  function (name)
    local ok = true

    if not name then
      name = minibuf_read_variable_name ('Describe variable: ')
    end

    if not name then
      ok = false
    else
      local doc = get_variable_doc (name)

      if not doc then
        ok = false
      else
        write_temp_buffer ('*Help*', true,
                           write_variable_description,
                           name, get_variable (name), doc)
      end
    end
    return ok
  end
)


local function find_or_create_buffer_from_module (name)
  local bp = find_buffer (name)
   if bp then
     switch_to_buffer (bp)
   else
     bp = create_auto_buffer (name)
     switch_to_buffer (bp)
     insert_string (require ('zz.doc.' .. name))
   end
   cur_bp.readonly = true
   cur_bp.modified = false
  goto_offset (1)
end


Defun ("describe_copying",
  {},
[[
Display info on how you may redistribute copies of GNU Zz.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('COPYING')
  end
)


Defun ("describe_no_warranty",
  {},
[[
Display info on all the kinds of warranty Zz does NOT have.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('COPYING')
    zz.search_forward (' Disclaimer of Warranty.')
    beginning_of_line ()
  end
)


Defun ("view_zz_FAQ",
  {},
[[
Display the Zz Frequently Asked Questions (FAQ) file.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('FAQ')
  end
)


Defun ("view_zz_news",
  {},
[[
Display info on recent changes to Zz.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('NEWS')
  end
)
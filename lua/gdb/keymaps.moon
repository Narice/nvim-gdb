V = require "gdb.v"

fmt = string.format

class Keymaps
    defaultKeymaps: {
        {'n', 'key_until',      ':GdbUntil'}
        {'n', 'key_continue',   ':GdbContinue'}
        {'n', 'key_next',       ':GdbNext'}
        {'n', 'key_step',       ':GdbStep'}
        {'n', 'key_finish',     ':GdbFinish'}
        {'n', 'key_breakpoint', ':GdbBreakpointToggle'}
        {'n', 'key_frameup',    ':GdbFrameUp'}
        {'n', 'key_framedown',  ':GdbFrameDown'}
        {'n', 'key_eval',       ':GdbEvalWord'}
        {'v', 'key_eval',       ':GdbEvalRange'}
    }

    set: =>
        for _, keymap in pairs(@defaultKeymaps)
            key = @config[keymap[2]]
            if key != nil
                c = fmt([[%snoremap <buffer> <silent> %s %s<cr>]], keymap[1], key, keymap[3])
                V.exe c

    unset: =>
        for _, keymap in pairs(@defaultKeymaps)
            key = @config[keymap[2]]
            if key != nil
                c = fmt([[%sunmap <buffer> %s]], keymap[1], key)
                V.exe c

    setT: =>
        -- Set term-local key maps
        defaultTkeymaps = {
            {'key_until',    ':GdbUntil'}
            {'key_continue', ':GdbContinue'}
            {'key_next',     ':GdbNext'}
            {'key_step',     ':GdbStep'}
            {'key_finish',   ':GdbFinish'}
        }

        for _, keymap in pairs(defaultTkeymaps)
            key = @config[keymap[1]]
            if key != nil
                V.exe fmt([[tnoremap <buffer> <silent> %s <c-\><c-n>%s<cr>i]], key, keymap[2])
        V.exe [[tnoremap <silent> <buffer> <esc> <c-\><c-n>]]


    dispatch: (key) =>
        cfg = @config[key]
        if cfg != nil
            cfg(@)

    dispatchSet: =>
        @dispatch 'set_keymaps'

    dispatchUnset: =>
        @dispatch 'unset_keymaps'

    dispatchSetT: =>
        @dispatch 'set_tkeymaps'

    -- Turn a string into a funcref either Lua or Vim, preferring Lua.
    filterFuncref = (defConf, k, v) ->
        -- Lookup the key in the default config.
        defVal = defConf[k]
        if defVal == nil
            return nil   -- No need to add it to the configuration.
        -- Check whether the key should be a function.
        if type(defVal) != 'function'
            return v
        -- NOTE: will be deprecated in Lua 5.2, so will have to use load() then.
        func = loadstring(v)
        if type(func) == 'function'
            return func
        -- Finally, turn the value into a Vim function call.
        return -> V.call(v, {})

    new: =>
        -- Default configuration
        defaultConfig =
            'key_until': '<f4>'
            'key_continue': '<f5>'
            'key_next': '<f10>'
            'key_step': '<f11>'
            'key_finish': '<f12>'
            'key_breakpoint': '<f8>'
            'key_frameup': '<c-p>'
            'key_framedown': '<c-n>'
            'key_eval': '<f9>'
            'set_tkeymaps': @setT
            'set_keymaps': @set
            'unset_keymaps': @unset

        -- Make a copy of the supplied configuration if defined
        config = nil
        if V.call("exists", {'g:nvimgdb_config'}) == 1
            config = V.get_var('nvimgdb_config')
            for k,v in pairs(config)
                config[k] = filterFuncref(defaultConfig, k, v)

        if config == nil
            config = {k,v for k,v in pairs defaultConfig}

        -- Check for keymap configuration sanity
        keyToFunc = {}
        checkKeymapConflicts = (key, func, verbose) ->
            if func\match('^key_.*')
                prevFunc = keyToFunc[key]
                if prevFunc != nil and prevFunc != func
                    if verbose
                        print fmt("Overriding conflicting keymap '%s' for %s (was %s)", key, func, prevFunc)
                    keyToFunc[config[func]] = nil
                    config[prevFunc] = nil
                keyToFunc[key] = func

        for func,key in pairs(config)
            checkKeymapConflicts key, func, true


        -- If there is config override defined, add it
        if V.call("exists", {'g:nvimgdb_config_override'}) != 0
            override = V.get_var('nvimgdb_config_override')
            if override != nil
                for k,v in pairs(override)
                    keyVal = filterFuncref(defaultConfig, k, v)
                    checkKeymapConflicts keyVal, k, true
                    config[k] = keyVal

        -- See whether a global override for a specific configuration
        -- key exists. If so, update the config.
        for key,_ in pairs(defaultConfig)
            vname = 'nvimgdb_' .. key
            if V.call("exists", {'g:'..vname}) != 0
                val = V.get_var(vname)
                if val != nil
                    keyVal = filterFuncref(defaultConfig, key, val)
                    checkKeymapConflicts keyVal, key, false
                    config[key] = keyVal

        -- Remember the resulting configuration
        @config = config

    getConfig: => @config

Keymaps

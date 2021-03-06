require "set_paths"
V = require "gdb.v"
s = require "posix.sys.socket"
u = require "posix.unistd"
json = require "JSON"

fmt = string.format


class Breakpoint
    new: (proxyAddr, sockDir) =>
        @proxyAddr = proxyAddr
        @sockAddr = sockDir .. "/client"
        @breaks = {}    -- {file -> {line -> id}}
        @maxSignId = 0
        @sock = -1

    cleanup: =>
        if @sock != -1
            u.close(@sock)
        os.remove @sockAddr

    connect = (sockAddr, proxyAddr) ->
        sock = s.socket(s.AF_UNIX, s.SOCK_DGRAM, 0)
        assert(sock != -1)
        assert(s.bind(sock, {family: s.AF_UNIX, path: sockAddr}))
        assert(s.setsockopt(sock, s.SOL_SOCKET, s.SO_RCVTIMEO, 0, 500000))
        assert(s.connect(sock, {family: s.AF_UNIX, path: proxyAddr}))
        sock

    doQuery: (fname) =>
        -- It takes time for the proxy to open a side channel.
        -- So we're connecting to the socket lazily during
        -- the first query.
        if @sock == -1
            @sock = connect @sockAddr, @proxyAddr
        assert s.send(@sock, fmt("info-breakpoints %s\n", fname))
        data = s.recv(@sock, 65536)
        data

    clearSigns: =>
        for i = 5000, @maxSignId
            V.exe ('sign unplace ' .. i)
        @maxSignId = 0

    setSigns: (buf) =>
        if buf != -1
            signId = 5000 - 1
            bpath = gdb.getFullBufferPath(buf)
            for line, _ in pairs(@breaks[bpath] or {})
                signId += 1
                V.exe fmt('sign place %d name=GdbBreakpoint line=%d buffer=%d', signId, line, buf)
            @maxSignId = signId

    query: (bufNum, fname) =>
        @breaks[fname] = {}
        resp = @doQuery fname
        if resp
            br = json\decode(resp)
            err = br._error
            if err
                V.exe ("echo \"Can't get breakpoints: \"" .. err)
            else
                @breaks[fname] = br
                @clearSigns!
                @setSigns bufNum
        --else
            -- TODO: notify about error

    resetSigns: =>
        @breaks = {}
        @clearSigns!

    getForFile: (fname) =>
        @breaks[fname] or {}

Breakpoint

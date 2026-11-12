-- Start the companion once at loader startup. No archive work runs in Lua.
return function(E)
    local B={}
    function B.install()
        if E.config.automaticBackups==false then return end
        if os.getenv('GG_BACKUP_MANAGED')=='1' then
            E.log('automatic backups managed by the session launcher (1 GiB budget)')
            return
        end
        if os.getenv('STEAM_COMPAT_DATA_PATH') or os.getenv('WINEPREFIX') then
            E.log('automatic backups: Proton launcher setup is needed; see BACKUPS.txt')
            return
        end
        local root=E.root:gsub('[/\\]+$','')
        -- cmd.exe expands these even in quotes. Never interpret a path as shell code.
        assert(not root:find('[%%!"\r\n]'),'Backup path contains unsupported shell characters')
        local function quote(value) return '"'..value..'"' end
        local exe=root..'/backup/python/pythonw.exe'
        local file=assert(io.open(exe,'rb'),'Packaged backup runtime missing; reinstall the full GG archive')
        file:close()
        local command='"'..quote(exe)..' -I '..quote(root..'/tools/backup_windows.py')..' arm '..quote(root)..'"'
        local ok,_,code=os.execute(command)
        assert(ok==true or ok==0,'Backup companion could not start (exit '..tostring(code)..')')
        E.log('automatic backups armed; after clean exit, 120s quiet period, 1 GiB budget')
    end
    return B
end

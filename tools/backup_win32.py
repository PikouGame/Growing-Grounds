"""Small Win32 surface for sleeping, cancellation and process identity (no polling in game)."""
import ctypes as C
from ctypes import wintypes as W
from contextlib import contextmanager
from pathlib import Path
import os
import re

GAME = re.compile(r'^(Palworld-(Win64|WinGDK)-Shipping|PalServer-Win64-Shipping(-Cmd)?)\.exe$', re.I)


class ProcessEntry(C.Structure):
    _fields_ = [('dwSize', W.DWORD), ('cntUsage', W.DWORD), ('th32ProcessID', W.DWORD),
                ('th32DefaultHeapID', C.c_size_t), ('th32ModuleID', W.DWORD),
                ('cntThreads', W.DWORD), ('th32ParentProcessID', W.DWORD),
                ('pcPriClassBase', W.LONG), ('dwFlags', W.DWORD), ('szExeFile', W.WCHAR*260)]


class Win32:
    def __init__(self):
        if os.name != 'nt':
            raise RuntimeError('Windows helper needs Windows; Proton uses the Linux session launcher')
        k = self.k = C.WinDLL('kernel32', use_last_error=True)
        def bind(name, result, *args):
            f = getattr(k, name);f.restype = result;f.argtypes = args
        bind('CreateToolhelp32Snapshot', W.HANDLE, W.DWORD, W.DWORD)
        bind('Process32FirstW', W.BOOL, W.HANDLE, C.POINTER(ProcessEntry))
        bind('Process32NextW', W.BOOL, W.HANDLE, C.POINTER(ProcessEntry))
        bind('CloseHandle', W.BOOL, W.HANDLE)
        bind('OpenProcess', W.HANDLE, W.DWORD, W.BOOL, W.DWORD)
        bind('QueryFullProcessImageNameW', W.BOOL, W.HANDLE, W.DWORD, W.LPWSTR, C.POINTER(W.DWORD))
        bind('GetProcessTimes', W.BOOL, W.HANDLE, *([C.POINTER(W.FILETIME)]*4))
        bind('GetExitCodeProcess', W.BOOL, W.HANDLE, C.POINTER(W.DWORD))
        bind('CreateEventW', W.HANDLE, C.c_void_p, W.BOOL, W.BOOL, W.LPCWSTR)
        bind('SetEvent', W.BOOL, W.HANDLE)
        bind('CreateMutexW', W.HANDLE, C.c_void_p, W.BOOL, W.LPCWSTR)
        bind('ReleaseMutex', W.BOOL, W.HANDLE)
        bind('WaitForSingleObject', W.DWORD, W.HANDLE, W.DWORD)
        bind('WaitForMultipleObjects', W.DWORD, W.DWORD, C.POINTER(W.HANDLE), W.BOOL, W.DWORD)
        bind('GetCurrentProcess', W.HANDLE)
        bind('SetPriorityClass', W.BOOL, W.HANDLE, W.DWORD)

    def checked(self, value):
        if not value:
            raise C.WinError(C.get_last_error())
        return value

    def close(self, handle):
        if handle:
            self.k.CloseHandle(handle)

    def processes(self):
        snap = self.k.CreateToolhelp32Snapshot(2, 0)
        if snap == C.c_void_p(-1).value:
            raise C.WinError(C.get_last_error())
        try:
            entry = ProcessEntry();entry.dwSize = C.sizeof(entry)
            more = self.k.Process32FirstW(snap, C.byref(entry))
            if not more and C.get_last_error() != 18:
                raise C.WinError(C.get_last_error())
            result = {}
            while more:
                result[entry.th32ProcessID] = (entry.th32ParentProcessID, entry.szExeFile)
                more = self.k.Process32NextW(snap, C.byref(entry))
            if C.get_last_error() != 18:
                raise C.WinError(C.get_last_error())
            return result
        finally:
            self.close(snap)

    def game_parent(self, mod):
        tree = self.processes();pid = os.getpid()
        for _ in range(12):
            pid, _ = tree.get(pid, (0, ''))
            if not pid:
                break
            if GAME.fullmatch(tree.get(pid, (0, ''))[1]):
                h = self.open_process(pid)
                try:
                    path = self.image(h)
                    if path.parent not in Path(mod).resolve().parents:
                        raise ValueError('GG folder does not belong to this game process')
                    return pid, path
                finally:
                    self.close(h)
        raise ValueError('No owning Palworld process; do not start the Windows helper manually')

    def game_running(self):
        # Any Palworld game delays disk work, including another installed copy.
        return any(GAME.fullmatch(name) for _, name in self.processes().values())

    def open_process(self, pid):
        return self.checked(self.k.OpenProcess(0x100000 | 0x1000, False, pid))

    def image(self, h):
        text = C.create_unicode_buffer(32768);size = W.DWORD(len(text))
        self.checked(self.k.QueryFullProcessImageNameW(h, 0, text, C.byref(size)))
        return Path(text.value).resolve()

    def created(self, h):
        fields = [W.FILETIME() for _ in range(4)]
        self.checked(self.k.GetProcessTimes(h, *(C.byref(f) for f in fields)))
        return fields[0].dwLowDateTime | fields[0].dwHighDateTime << 32

    def exit_code(self, h):
        code = W.DWORD();self.checked(self.k.GetExitCodeProcess(h, C.byref(code)))
        return code.value

    def event(self, name):
        return self.checked(self.k.CreateEventW(None, True, False, name))

    def cancel(self, h):
        self.checked(self.k.SetEvent(h))

    def wait(self, handles, milliseconds):
        result = self.k.WaitForMultipleObjects(len(handles), (W.HANDLE*len(handles))(*handles), False, milliseconds)
        if result == 0xFFFFFFFF:
            raise C.WinError(C.get_last_error())
        return result  # zero-based handle index, or258 timeout

    @contextmanager
    def gate(self, name, timeout=10000):
        h = self.checked(self.k.CreateMutexW(None, False, name));owned = False
        try:
            value = self.k.WaitForSingleObject(h, timeout)
            if value not in (0, 0x80):
                raise TimeoutError('Backup worker did not release its file gate')
            owned = True
            yield
        finally:
            if owned:
                self.k.ReleaseMutex(h)
            self.close(h)

    def background(self):
        h = self.k.GetCurrentProcess()
        # Windows background mode lowers CPU and I/O priority; Wine may support only idle CPU.
        if not self.k.SetPriorityClass(h, 0x100000):
            self.checked(self.k.SetPriorityClass(h, 0x40))

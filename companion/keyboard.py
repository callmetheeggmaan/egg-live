"""Narrow F10 bridge. Never focuses another app, types text, or modifies memory."""
import ctypes, json, sys, os, time
from ctypes import wintypes
if sys.platform != 'win32':
    print(json.dumps({'ok':False,'error':'Windows is required'}),flush=True);sys.exit(1)
u=ctypes.WinDLL('user32',use_last_error=True);k=ctypes.WinDLL('kernel32',use_last_error=True)
u.GetForegroundWindow.restype=wintypes.HWND
u.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
k.OpenProcess.argtypes=[wintypes.DWORD,wintypes.BOOL,wintypes.DWORD];k.OpenProcess.restype=wintypes.HANDLE
k.QueryFullProcessImageNameW.argtypes=[wintypes.HANDLE,wintypes.DWORD,wintypes.LPWSTR,ctypes.POINTER(wintypes.DWORD)]
k.CloseHandle.argtypes=[wintypes.HANDLE]
ULONG_PTR=ctypes.c_uint64 if ctypes.sizeof(ctypes.c_void_p)==8 else ctypes.c_ulong
class KEYBDINPUT(ctypes.Structure):_fields_=[('wVk',wintypes.WORD),('wScan',wintypes.WORD),('dwFlags',wintypes.DWORD),('time',wintypes.DWORD),('dwExtraInfo',ULONG_PTR)]
class MOUSEINPUT(ctypes.Structure):_fields_=[('dx',wintypes.LONG),('dy',wintypes.LONG),('mouseData',wintypes.DWORD),('dwFlags',wintypes.DWORD),('time',wintypes.DWORD),('dwExtraInfo',ULONG_PTR)]
class U(ctypes.Union):_fields_=[('ki',KEYBDINPUT),('mi',MOUSEINPUT)]
class INPUT(ctypes.Structure):_fields_=[('type',wintypes.DWORD),('u',U)]
u.SendInput.argtypes=[wintypes.UINT,ctypes.POINTER(INPUT),ctypes.c_int]
def foreground(expected):
    window=u.GetForegroundWindow();pid=wintypes.DWORD();u.GetWindowThreadProcessId(window,ctypes.byref(pid))
    h=k.OpenProcess(0x1000,False,pid.value)
    if not h:return False
    try:
        name=ctypes.create_unicode_buffer(32768);size=wintypes.DWORD(32768)
        return bool(k.QueryFullProcessImageNameW(h,0,name,ctypes.byref(size))) and os.path.normcase(os.path.abspath(name.value))==os.path.normcase(os.path.join(expected,'BlackOps3.exe'))
    finally:k.CloseHandle(h)
for line in sys.stdin:
    try:
        msg=json.loads(line);active=foreground(msg['gamePath'])
        if not active:raise RuntimeError('BO3 must be the active window; action not sent')
        # F10 alone. Check focus again before pressing; always release the key.
        if not foreground(msg['gamePath']):raise RuntimeError('Game focus changed')
        down=INPUT(type=1,u=U(ki=KEYBDINPUT(wVk=0x79)));up=INPUT(type=1,u=U(ki=KEYBDINPUT(wVk=0x79,dwFlags=2)))
        if u.SendInput(1,ctypes.byref(down),ctypes.sizeof(INPUT))!=1:raise RuntimeError('Windows rejected the key')
        time.sleep(.06);u.SendInput(1,ctypes.byref(up),ctypes.sizeof(INPUT))
        print(json.dumps({'ok':True}),flush=True)
    except Exception as e:print(json.dumps({'ok':False,'error':str(e)}),flush=True)

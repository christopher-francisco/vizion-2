"""The window flow of docs/requirements/0.3.0_COLOUR_SCHEME_SYNC.md: tmux running Neovim, with fake
iTerm windows (one per scheme, kept attached together) that attach, take focus and flip light/dark.
Each window answers what iTerm 3.7 answers (light/dark, OSC 10/11 colours, DECRQM, focus reports,
ITERM_PROFILE). After each step, tmux's theme and every Neovim's scheme and 'background' must be
the window in use's. Uses the installed tmux.conf, Neovim config and plugins. Prints `ok`/`not ok`
lines like assert.sh.
Usage: python3 -I attach.py '<colour-schemes.json, rendered>' <first-run theme>"""
import fcntl, json, os, pty, re, select, shutil, struct, subprocess, sys, tempfile, termios, time

data, default = json.loads(sys.argv[1]), sys.argv[2]
tmp = tempfile.mkdtemp(prefix='attach.')
os.chdir(tmp)   # sockets by relative path: a full $TMPDIR path can pass macOS's 104-byte limit
SEQ = re.compile(r'\x1b(\][^\x07\x1b]*(\x07|\x1b\\)|\[[?>]?[\d;$]*[a-zA-Z])')
windows = []

def tmux(*args):
    return subprocess.run(['tmux', '-S', 'tm.sock', *args], capture_output=True, text=True).stdout.strip()

def nvim(server, expr):
    r = subprocess.run(['nvim', '--server', server, '--remote-expr', expr], capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()

def osc_rgb(hex):
    return 'rgb:' + '/'.join(hex[i:i + 2] * 2 for i in (1, 3, 5))

class Window:
    """A fake iTerm window running `tmux attach`."""
    def __init__(self, profile, scheme, appearance):
        self.scheme, self.appearance = scheme, appearance
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ['ITERM_PROFILE'] = profile
            os.execvp('tmux', ['tmux', '-S', 'tm.sock', 'attach'])
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', 40, 120, 0, 0))
        os.set_blocking(self.fd, False)
        self.buf = ''
        windows.append(self)

    def send(self, s):
        try:
            os.write(self.fd, s.encode())
        except OSError:
            pass

    def flip(self, appearance):
        """The macOS appearance changes: new colours, and iTerm's mode 2031 report."""
        self.appearance = appearance
        self.send(f'\x1b[?997;{1 if appearance == "dark" else 2}n')

    def focus(self):
        self.send('\x1b[I')

    def answer(self):
        bg = osc_rgb(data['schemes'][self.scheme][self.appearance])
        try:
            self.buf += os.read(self.fd, 65536).decode('latin-1')
        except OSError:
            return
        done = 0
        for m in SEQ.finditer(self.buf):
            s, done = m[0], m.end()
            if s in ('\x1b]11;?\x1b\\', '\x1b]11;?\x07'): self.send(f'\x1b]11;{bg}\x1b\\')
            elif s in ('\x1b]10;?\x1b\\', '\x1b]10;?\x07'): self.send('\x1b]10;rgb:8080/8080/8080\x1b\\')
            elif s == '\x1b[5n': self.send('\x1b[0n')
            elif s == '\x1b[?996n': self.send(f'\x1b[?997;{1 if self.appearance == "dark" else 2}n')
            elif s == '\x1b[c': self.send('\x1b[?62;4;22;52c')
            elif s == '\x1b[>c': self.send('\x1b[>0;95;0c')
            elif s in ('\x1b[>q', '\x1b[>0q'): self.send('\x1bP>|iTerm2 3.7.5\x1b\\')
            elif q := re.fullmatch(r'\x1b\[\?(\d+)\$p', s): self.send(f'\x1b[?{q[1]};2$y')
        self.buf = self.buf[max(done, len(self.buf) - 64):]

def pump(seconds):
    end = time.time() + seconds
    while time.time() < end:
        ready = select.select([w.fd for w in windows], [], [], 0.05)[0]
        for w in windows:
            if w.fd in ready:
                w.answer()

def expect(step, scheme, appearance, servers):
    got = [f"tmux {tmux('show', '-gv', '@theme')}"]
    good = got[0] == f'tmux {scheme}-{appearance}'
    for server in servers:
        colors, bg = nvim(server, 'g:colors_name'), nvim(server, '&background')
        got.append(f'nvim {colors}/{bg}')
        good = good and colors.startswith(scheme) and bg == appearance
    print(f"{'ok' if good else 'not ok'} - colour scheme: {step}: {scheme}, {appearance}", flush=True)
    if not good:
        print(f"    got {', '.join(got)}", flush=True)

def profile_of(scheme):   # a size profile of the scheme, as picked from the Profiles menu
    return sorted(n for n, s in data['profiles'].items() if s == scheme)[-1]

subprocess.run(['tmux', '-S', 'tm.sock', 'new-session', '-d', '-x', '120', '-y', '40', 'nvim --listen ./nv1.sock'], check=True)
time.sleep(8)   # LazyVim startup
try:
    one, two = sorted(data['schemes'])[:2]
    w1 = Window(profile_of(one), one, 'dark'); pump(4)
    expect(f'attach from a {profile_of(one)} window', one, 'dark', ['./nv1.sock'])
    w2 = Window(profile_of(two), two, 'dark'); pump(4)
    expect(f'attach from a {profile_of(two)} window, the first still attached', two, 'dark', ['./nv1.sock'])
    w1.focus(); pump(3)
    expect('back to the first window', one, 'dark', ['./nv1.sock'])
    w2.focus(); pump(3)
    expect('back to the second window', two, 'dark', ['./nv1.sock'])
    tmux('new-window', 'nvim --listen ./nv2.sock'); pump(8)
    expect('a Neovim started in the second window', two, 'dark', ['./nv1.sock', './nv2.sock'])
    w2.flip('light'); pump(3)
    expect('the second window turns light', two, 'light', ['./nv1.sock', './nv2.sock'])
    w1.flip('light'); pump(3)
    expect('the first window turns light while not in use', two, 'light', ['./nv1.sock', './nv2.sock'])
    w1.focus(); pump(3)
    expect('back to the first window', one, 'light', ['./nv1.sock', './nv2.sock'])
    tmux('detach-client', '-a'); tmux('detach-client'); pump(1)
    for w in windows:
        os.close(w.fd); os.waitpid(w.pid, 0)
    windows.clear()
    Window('This Mac', default, 'dark'); pump(4)
    expect('attach from a This Mac window', default, 'dark', ['./nv1.sock', './nv2.sock'])
finally:
    tmux('kill-server')
    shutil.rmtree(tmp, ignore_errors=True)

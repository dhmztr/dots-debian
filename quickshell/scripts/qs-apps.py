#!/usr/bin/env python3
import os, json, glob, re, shlex

FIELD_CODE = re.compile(r'%[uUfFdDnNickvm]')

CATEGORY_MAP = {
    'Network': 'Internet', 'WebBrowser': 'Internet', 'Email': 'Internet',
    'InstantMessaging': 'Internet', 'Chat': 'Internet', 'Feed': 'Internet',
    'Development': 'Dev', 'IDE': 'Dev', 'Debugger': 'Dev', 'Building': 'Dev',
    'TextEditor': 'Dev', 'WebDevelopment': 'Dev', 'Profiling': 'Dev',
    'Audio': 'Media', 'Video': 'Media', 'Music': 'Media', 'Player': 'Media',
    'Recorder': 'Media', 'TV': 'Media', 'AudioVideo': 'Media',
    'Game': 'Games', 'Games': 'Games', 'ArcadeGame': 'Games',
    'BoardGame': 'Games', 'CardGame': 'Games', 'LogicGame': 'Games',
    'System': 'System', 'Settings': 'System', 'Monitor': 'System',
    'Utility': 'System', 'FileManager': 'System', 'TerminalEmulator': 'System',
    'PackageManager': 'System',
    'Office': 'Office', 'WordProcessor': 'Office', 'Spreadsheet': 'Office',
    'Presentation': 'Office', 'Calendar': 'Office', 'ProjectManagement': 'Office',
}

# native dirs first, flatpak last, so a native app wins name collisions
DIRS = [
    '/usr/share/applications',
    '/usr/local/share/applications',
    os.path.expanduser('~/.local/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
]

# Icon resolution
ICON_DIRS = [
    os.path.expanduser('~/.local/share/icons/hicolor'),
    '/usr/share/icons/hicolor',
    '/var/lib/flatpak/exports/share/icons/hicolor',
    os.path.expanduser('~/.local/share/flatpak/exports/share/icons/hicolor'),
]
PIXMAP_DIRS = [
    '/usr/share/pixmaps',
]
PREFERRED_SIZES = ['48x48', '64x64', '128x128', '32x32', '256x256', '24x24', 'scalable']
ICON_EXTS = ['.png', '.svg', '.xpm']

_icon_cache = {}

def resolve_icon(name):
    if not name:
        return ''
    if '/' in name and os.path.isfile(name):
        return name
    if name in _icon_cache:
        return _icon_cache[name]

    # Search hicolor theme directories
    for icon_dir in ICON_DIRS:
        for size in PREFERRED_SIZES:
            for category in ['apps', 'mimetypes', 'status', 'devices', 'actions']:
                for ext in ICON_EXTS:
                    path = os.path.join(icon_dir, size, category, name + ext)
                    if os.path.isfile(path):
                        _icon_cache[name] = path
                        return path

    # Search pixmaps
    for pdir in PIXMAP_DIRS:
        for ext in ICON_EXTS:
            path = os.path.join(pdir, name + ext)
            if os.path.isfile(path):
                _icon_cache[name] = path
                return path

    _icon_cache[name] = ''
    return ''


def flatpak_exec(exec_line, app_id):
    """Normalise an exported flatpak Exec for direct argv launching.

    Exports look like `/nix/store/...-flatpak/bin/flatpak run --branch=master
    --arch=x86_64 --command=sober --file-forwarding org.vinegarhq.Sober @@u %u @@`.
    Keep every `flatpak run` option (--command/--branch matter for apps whose
    default command or branch is not the one exported), but call `flatpak` via
    PATH (the absolute store path dies on the next flatpak update + GC) and drop
    the @@/@@u file-forwarding markers, which only `flatpak run
    --file-forwarding` understands and would otherwise reach the app as args.
    """
    try:
        argv = shlex.split(exec_line)
    except ValueError:
        argv = []
    if len(argv) >= 2 and os.path.basename(argv[0]) == 'flatpak' and argv[1] == 'run':
        argv = ['flatpak'] + [a for a in argv[1:]
                              if a not in ('--file-forwarding', '@@', '@@u')]
        # `APP -- %u`: the launcher drops field codes, which would leave a bare
        # `--` as the app's only argument (Sober exits on it). Drop the `--` when
        # nothing but field codes follows it.
        if '--' in argv:
            i = argv.index('--')
            if all(FIELD_CODE.fullmatch(a) for a in argv[i + 1:]):
                argv = argv[:i]
        return shlex.join(argv)
    return f'flatpak run {shlex.quote(app_id)}'


# classify by dir - native always wins over flatpak when names collide
FLATPAK_DIRS = {
    '/var/lib/flatpak/exports/share/applications',
    os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
}

apps = []
seen_ids = set()
seen_names = {}  # name.lower() -> index into apps

for d in DIRS:
    if not os.path.isdir(d):
        continue
    source = 'flatpak' if d in FLATPAK_DIRS else 'native'
    for path in glob.glob(os.path.join(d, '*.desktop')):
        try:
            data = {}
            with open(path, encoding='utf-8', errors='replace') as f:
                in_section = False
                for line in f:
                    line = line.strip()
                    if line == '[Desktop Entry]':
                        in_section = True
                    elif line.startswith('['):
                        in_section = False
                    elif in_section and '=' in line:
                        k, _, v = line.partition('=')
                        data[k.strip()] = v.strip()

            if data.get('Type') != 'Application':
                continue
            if data.get('NoDisplay', '').lower() == 'true':
                continue
            if data.get('Hidden', '').lower() == 'true':
                continue

            name = data.get('Name', '')
            if not name:
                continue
            desktop_id = os.path.basename(path)
            if desktop_id in seen_ids:
                continue
            seen_ids.add(desktop_id)

            exec_line = data.get('Exec', '')
            flatpak_id = data.get('X-Flatpak', '')
            if source == 'flatpak' and flatpak_id:
                exec_line = flatpak_exec(exec_line, flatpak_id)

            raw_cats = [c.strip() for c in data.get('Categories', '').split(';') if c.strip()]
            mapped = list({CATEGORY_MAP[c] for c in raw_cats if c in CATEGORY_MAP})

            icon_name = data.get('Icon', '')
            icon_path = resolve_icon(icon_name)

            entry = {
                'n': name,
                'g': data.get('GenericName', ''),
                'i': icon_path,
                'e': exec_line,
                'd': desktop_id,
                'c': mapped,
                's': source,
            }

            # Dedupe by name - DIRS order lists native before flatpak, so first wins
            key = name.lower()
            if key in seen_names:
                continue
            seen_names[key] = len(apps)
            apps.append(entry)
        except Exception:
            pass

apps.sort(key=lambda a: a['n'].lower())
print(json.dumps(apps))

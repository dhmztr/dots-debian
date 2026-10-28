//! qs-apps: index of installed desktop applications for the quickshell
//! launcher, printed as one JSON array on stdout.
//!
//! Rust port of the old qs-apps.py (same output): the launcher runs this on
//! every open, and a native binary starts in ~1 ms instead of a Python
//! interpreter's ~50 ms.
//!
//! Entry: {"n": name, "g": generic name, "i": icon path, "e": Exec,
//!         "d": desktop id, "c": [launcher categories], "s": "native"|"flatpak"}

use std::collections::{BTreeSet, HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};

const CATEGORY_MAP: &[(&str, &str)] = &[
    ("Network", "Internet"), ("WebBrowser", "Internet"), ("Email", "Internet"),
    ("InstantMessaging", "Internet"), ("Chat", "Internet"), ("Feed", "Internet"),
    ("Development", "Dev"), ("IDE", "Dev"), ("Debugger", "Dev"), ("Building", "Dev"),
    ("TextEditor", "Dev"), ("WebDevelopment", "Dev"), ("Profiling", "Dev"),
    ("Audio", "Media"), ("Video", "Media"), ("Music", "Media"), ("Player", "Media"),
    ("Recorder", "Media"), ("TV", "Media"), ("AudioVideo", "Media"),
    ("Game", "Games"), ("Games", "Games"), ("ArcadeGame", "Games"),
    ("BoardGame", "Games"), ("CardGame", "Games"), ("LogicGame", "Games"),
    ("System", "System"), ("Settings", "System"), ("Monitor", "System"),
    ("Utility", "System"), ("FileManager", "System"), ("TerminalEmulator", "System"),
    ("PackageManager", "System"),
    ("Office", "Office"), ("WordProcessor", "Office"), ("Spreadsheet", "Office"),
    ("Presentation", "Office"), ("Calendar", "Office"), ("ProjectManagement", "Office"),
];

const PREFERRED_SIZES: &[&str] = &["48x48", "64x64", "128x128", "32x32", "256x256", "24x24", "scalable"];
const ICON_CATEGORIES: &[&str] = &["apps", "mimetypes", "status", "devices", "actions"];
const ICON_EXTS: &[&str] = &[".png", ".svg", ".xpm"];

fn home() -> PathBuf {
    PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/".into()))
}

/// Native dirs first (incl. home-manager's per-user profile), flatpak last,
/// so a native app wins name collisions.
fn app_dirs(home: &Path) -> Vec<(PathBuf, bool)> {
    let mut dirs: Vec<(PathBuf, bool)> = vec![
        ("/run/current-system/sw/share/applications".into(), false),
        ("/usr/share/applications".into(), false),
        ("/usr/local/share/applications".into(), false),
        (home.join(".local/share/applications"), false),
        (home.join(".nix-profile/share/applications"), false),
    ];
    let mut per_user: Vec<PathBuf> = fs::read_dir("/etc/profiles/per-user")
        .map(|rd| rd.flatten().map(|e| e.path().join("share/applications")).filter(|p| p.is_dir()).collect())
        .unwrap_or_default();
    per_user.sort();
    dirs.extend(per_user.into_iter().map(|p| (p, false)));
    dirs.push(("/var/lib/flatpak/exports/share/applications".into(), true));
    dirs.push((home.join(".local/share/flatpak/exports/share/applications"), true));
    dirs
}

struct IconResolver {
    icon_dirs: Vec<PathBuf>,
    pixmap_dirs: Vec<PathBuf>,
    cache: HashMap<String, String>,
}

impl IconResolver {
    fn new(home: &Path) -> Self {
        IconResolver {
            icon_dirs: vec![
                "/run/current-system/sw/share/icons/hicolor".into(),
                home.join(".local/share/icons/hicolor"),
                "/usr/share/icons/hicolor".into(),
                "/var/lib/flatpak/exports/share/icons/hicolor".into(),
                home.join(".local/share/flatpak/exports/share/icons/hicolor"),
            ],
            pixmap_dirs: vec!["/run/current-system/sw/share/pixmaps".into(), "/usr/share/pixmaps".into()],
            cache: HashMap::new(),
        }
    }

    fn resolve(&mut self, name: &str) -> String {
        if name.is_empty() {
            return String::new();
        }
        if name.contains('/') && Path::new(name).is_file() {
            return name.to_string();
        }
        if let Some(p) = self.cache.get(name) {
            return p.clone();
        }
        let found = self.search(name).unwrap_or_default();
        self.cache.insert(name.to_string(), found.clone());
        found
    }

    fn search(&self, name: &str) -> Option<String> {
        for dir in &self.icon_dirs {
            for size in PREFERRED_SIZES {
                for cat in ICON_CATEGORIES {
                    for ext in ICON_EXTS {
                        let p = dir.join(size).join(cat).join(format!("{name}{ext}"));
                        if p.is_file() {
                            return Some(p.to_string_lossy().into_owned());
                        }
                    }
                }
            }
        }
        for dir in &self.pixmap_dirs {
            for ext in ICON_EXTS {
                let p = dir.join(format!("{name}{ext}"));
                if p.is_file() {
                    return Some(p.to_string_lossy().into_owned());
                }
            }
        }
        None
    }
}

/// Keys of the [Desktop Entry] group (later duplicates win, like the Python dict).
fn parse_desktop(text: &str) -> HashMap<String, String> {
    let mut data = HashMap::new();
    let mut in_section = false;
    for line in text.lines() {
        let line = line.trim();
        if line == "[Desktop Entry]" {
            in_section = true;
        } else if line.starts_with('[') {
            in_section = false;
        } else if in_section {
            if let Some((k, v)) = line.split_once('=') {
                data.insert(k.trim().to_string(), v.trim().to_string());
            }
        }
    }
    data
}

fn is_field_code(a: &str) -> bool {
    let b = a.as_bytes();
    b.len() == 2 && b[0] == b'%' && b"uUfFdDnNickvm".contains(&b[1])
}

/// POSIX shell word splitting (Python shlex.split): quotes, backslashes.
fn shell_split(s: &str) -> Option<Vec<String>> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut has = false;
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '\'' => {
                has = true;
                loop {
                    match chars.next()? {
                        '\'' => break,
                        ch => cur.push(ch),
                    }
                }
            }
            '"' => {
                has = true;
                loop {
                    match chars.next()? {
                        '"' => break,
                        '\\' => match chars.peek() {
                            Some('"') | Some('\\') | Some('$') | Some('`') => cur.push(chars.next().unwrap()),
                            _ => cur.push('\\'),
                        },
                        ch => cur.push(ch),
                    }
                }
            }
            '\\' => {
                has = true;
                if let Some(ch) = chars.next() {
                    cur.push(ch);
                }
            }
            c if c.is_whitespace() => {
                if has {
                    out.push(std::mem::take(&mut cur));
                    has = false;
                }
            }
            c => {
                has = true;
                cur.push(c);
            }
        }
    }
    if has {
        out.push(cur);
    }
    Some(out)
}

/// Python shlex.quote
fn shell_quote(s: &str) -> String {
    if s.is_empty() {
        return "''".into();
    }
    let safe = s.chars().all(|c| c.is_ascii_alphanumeric() || "_@%+=:,./-".contains(c));
    if safe {
        s.to_string()
    } else {
        format!("'{}'", s.replace('\'', "'\"'\"'"))
    }
}

/// Normalise an exported flatpak Exec for direct argv launching.
///
/// Exports look like `/nix/store/...-flatpak/bin/flatpak run --branch=master
/// --arch=x86_64 --command=sober --file-forwarding org.vinegarhq.Sober @@u %u @@`.
/// Keep every `flatpak run` option, call `flatpak` via PATH (the store path
/// dies on the next flatpak update + GC) and drop the @@/@@u file-forwarding
/// markers, which only `flatpak run --file-forwarding` understands.
fn flatpak_exec(exec_line: &str, app_id: &str) -> String {
    let argv = shell_split(exec_line).unwrap_or_default();
    let is_flatpak = argv.len() >= 2
        && Path::new(&argv[0]).file_name().map(|n| n == "flatpak").unwrap_or(false)
        && argv[1] == "run";
    if is_flatpak {
        let mut out: Vec<String> = std::iter::once("flatpak".to_string())
            .chain(argv[1..].iter().filter(|a| !matches!(a.as_str(), "--file-forwarding" | "@@" | "@@u")).cloned())
            .collect();
        // `APP -- %u`: the launcher drops field codes, which would leave a bare
        // `--` as the app's only argument (Sober exits on it)
        if let Some(i) = out.iter().position(|a| a == "--") {
            if out[i + 1..].iter().all(|a| is_field_code(a)) {
                out.truncate(i);
            }
        }
        return out.iter().map(|a| shell_quote(a)).collect::<Vec<_>>().join(" ");
    }
    format!("flatpak run {}", shell_quote(app_id))
}

fn json_str(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

struct App {
    name: String,
    generic: String,
    icon: String,
    exec: String,
    id: String,
    cats: Vec<&'static str>,
    flatpak: bool,
}

fn main() {
    let home = home();
    let mut icons = IconResolver::new(&home);
    let mut apps: Vec<App> = Vec::new();
    let mut seen_ids: HashSet<String> = HashSet::new();
    let mut seen_names: HashSet<String> = HashSet::new();

    for (dir, flatpak) in app_dirs(&home) {
        let Ok(rd) = fs::read_dir(&dir) else { continue };
        let mut files: Vec<PathBuf> = rd
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.extension().map(|e| e == "desktop").unwrap_or(false))
            .collect();
        files.sort();
        for path in files {
            let Ok(bytes) = fs::read(&path) else { continue };
            let data = parse_desktop(&String::from_utf8_lossy(&bytes));
            let get = |k: &str| data.get(k).map(String::as_str).unwrap_or("");

            if get("Type") != "Application"
                || get("NoDisplay").eq_ignore_ascii_case("true")
                || get("Hidden").eq_ignore_ascii_case("true")
            {
                continue;
            }
            let name = get("Name");
            if name.is_empty() {
                continue;
            }
            let id = path.file_name().unwrap().to_string_lossy().into_owned();
            if !seen_ids.insert(id.clone()) {
                continue;
            }

            let mut exec = get("Exec").to_string();
            let flatpak_id = get("X-Flatpak");
            if flatpak && !flatpak_id.is_empty() {
                exec = flatpak_exec(&exec, flatpak_id);
            }

            let cats: BTreeSet<&'static str> = get("Categories")
                .split(';')
                .map(str::trim)
                .filter_map(|c| CATEGORY_MAP.iter().find(|(k, _)| *k == c).map(|(_, v)| *v))
                .collect();

            // dedupe by name: dirs list native before flatpak, so first wins
            if !seen_names.insert(name.to_lowercase()) {
                continue;
            }
            apps.push(App {
                name: name.to_string(),
                generic: get("GenericName").to_string(),
                icon: icons.resolve(get("Icon")),
                exec,
                id,
                cats: cats.into_iter().collect(),
                flatpak,
            });
        }
    }

    apps.sort_by_key(|a| a.name.to_lowercase());

    let mut out = String::with_capacity(apps.len() * 200);
    out.push('[');
    for (i, a) in apps.iter().enumerate() {
        if i > 0 {
            out.push_str(", ");
        }
        out.push_str("{\"n\": ");
        json_str(&a.name, &mut out);
        out.push_str(", \"g\": ");
        json_str(&a.generic, &mut out);
        out.push_str(", \"i\": ");
        json_str(&a.icon, &mut out);
        out.push_str(", \"e\": ");
        json_str(&a.exec, &mut out);
        out.push_str(", \"d\": ");
        json_str(&a.id, &mut out);
        out.push_str(", \"c\": [");
        for (j, c) in a.cats.iter().enumerate() {
            if j > 0 {
                out.push_str(", ");
            }
            json_str(c, &mut out);
        }
        out.push_str("], \"s\": ");
        json_str(if a.flatpak { "flatpak" } else { "native" }, &mut out);
        out.push('}');
    }
    out.push(']');
    println!("{out}");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flatpak_exec_drops_forwarding_and_bare_double_dash() {
        let e = "/nix/store/x-flatpak/bin/flatpak run --branch=master --arch=x86_64 --command=sober \
                 --file-forwarding org.vinegarhq.Sober @@u %u @@";
        assert_eq!(
            flatpak_exec(e, "org.vinegarhq.Sober"),
            "flatpak run --branch=master --arch=x86_64 --command=sober org.vinegarhq.Sober %u"
        );
        assert_eq!(
            flatpak_exec("/usr/bin/flatpak run org.app.X -- %u", "org.app.X"),
            "flatpak run org.app.X"
        );
        assert_eq!(flatpak_exec("weird", "org.app.Y"), "flatpak run org.app.Y");
    }

    #[test]
    fn shell_split_and_quote_roundtrip() {
        assert_eq!(
            shell_split(r#"a "b c" 'd e' f\ g "h\"i""#).unwrap(),
            vec!["a", "b c", "d e", "f g", "h\"i"]
        );
        assert_eq!(shell_quote("it's"), "'it'\"'\"'s'");
        assert_eq!(shell_quote("--x=1"), "--x=1");
        assert_eq!(shell_quote(""), "''");
        assert!(shell_split("unterminated 'quote").is_none());
    }

    #[test]
    fn desktop_entry_group_only() {
        let d = parse_desktop("[Desktop Entry]\nName=A\nExec=a %U\n[Desktop Action new]\nName=B\n");
        assert_eq!(d.get("Name").unwrap(), "A");
        assert_eq!(d.get("Exec").unwrap(), "a %U");
    }

    #[test]
    fn json_escaping() {
        let mut s = String::new();
        json_str("a\"b\\c\nd\u{1}", &mut s);
        assert_eq!(s, "\"a\\\"b\\\\c\\nd\\u0001\"");
    }
}

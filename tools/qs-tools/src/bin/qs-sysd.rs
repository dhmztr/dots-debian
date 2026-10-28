//! qs-sysd: system stats for the quickshell bar and dashboard, one JSON
//! object per line on stdout every interval (default 2 s).
//!
//! One long-lived process replaces the per-widget timers that re-read /proc
//! and spawned `df` / `cat` / `sh` (bar CPU ring, dashboard Performance tab).
//! Everything is read from /proc and /sys; nothing here wakes the NVIDIA GPU
//! (its runtime PM status is read, nvidia-smi is never called).
//!
//!   qs-sysd [interval-seconds]
//!
//! {"cpu": %, "ramUsed": KiB, "ramTotal": KiB, "diskUsed": B, "diskSize": B,
//!  "gpu": % (AMD iGPU busy, -1 if unknown), "temp": °C (-1 if unknown),
//!  "dgpu": "active"|"suspended"|"" (NVIDIA runtime PM), "load": [1, 5, 15],
//!  "uptime": s}
//!
//! Exits when stdout is closed (quickshell gone).

use std::ffi::CString;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::Duration;

/// disk usage changes slowly: statvfs every this many ticks
const DISK_EVERY: u32 = 15;

fn read(p: &Path) -> Option<String> {
    fs::read_to_string(p).ok()
}

/// (total, idle) jiffies from the aggregate `cpu` line of /proc/stat
fn cpu_times() -> Option<(u64, u64)> {
    let s = read(Path::new("/proc/stat"))?;
    let line = s.lines().next()?;
    let v: Vec<u64> = line.split_whitespace().skip(1).filter_map(|x| x.parse().ok()).collect();
    if v.len() < 5 {
        return None;
    }
    // idle + iowait
    Some((v.iter().sum(), v[3] + v[4]))
}

fn meminfo() -> (u64, u64) {
    let s = read(Path::new("/proc/meminfo")).unwrap_or_default();
    let field = |k: &str| {
        s.lines()
            .find(|l| l.starts_with(k))
            .and_then(|l| l.split_whitespace().nth(1))
            .and_then(|v| v.parse::<u64>().ok())
            .unwrap_or(0)
    };
    let total = field("MemTotal:");
    let avail = field("MemAvailable:");
    (total.saturating_sub(avail), total)
}

/// (used, size) bytes of the filesystem holding `path`, like `df`
fn disk(path: &str) -> Option<(u64, u64)> {
    let c = CString::new(path).ok()?;
    let mut st: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c.as_ptr(), &mut st) } != 0 {
        return None;
    }
    let bs = st.f_frsize as u64;
    let size = st.f_blocks as u64 * bs;
    let free = st.f_bfree as u64 * bs;
    Some((size.saturating_sub(free), size))
}

fn glob_dir(dir: &str) -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = fs::read_dir(dir).map(|rd| rd.flatten().map(|e| e.path()).collect()).unwrap_or_default();
    v.sort();
    v
}

/// gpu_busy_percent of the amdgpu card (the iGPU)
fn find_amd_busy() -> Option<PathBuf> {
    glob_dir("/sys/class/drm").into_iter().find_map(|card| {
        let p = card.join("device/gpu_busy_percent");
        let drv = fs::read_link(card.join("device/driver")).ok()?;
        (drv.file_name()? == "amdgpu" && p.is_file()).then_some(p)
    })
}

/// CPU package temperature: k10temp (AMD Tctl) or coretemp, else a thermal zone
fn find_temp() -> Option<PathBuf> {
    for hw in glob_dir("/sys/class/hwmon") {
        let name = read(&hw.join("name")).unwrap_or_default();
        if matches!(name.trim(), "k10temp" | "coretemp" | "zenpower") {
            let p = hw.join("temp1_input");
            if p.is_file() {
                return Some(p);
            }
        }
    }
    for tz in glob_dir("/sys/class/thermal") {
        let ty = read(&tz.join("type")).unwrap_or_default();
        if matches!(ty.trim(), "x86_pkg_temp" | "acpitz" | "cpu-thermal") {
            return Some(tz.join("temp"));
        }
    }
    None
}

/// runtime PM status file of the NVIDIA display controller, if any
fn find_dgpu() -> Option<PathBuf> {
    glob_dir("/sys/bus/pci/devices").into_iter().find_map(|d| {
        let vendor = read(&d.join("vendor"))?;
        let class = read(&d.join("class"))?;
        (vendor.trim() == "0x10de" && class.trim().starts_with("0x03")).then(|| d.join("power/runtime_status"))
    })
}

fn read_num(p: &Option<PathBuf>) -> Option<i64> {
    read(p.as_ref()?)?.trim().parse().ok()
}

fn main() {
    let interval = std::env::args().nth(1).and_then(|a| a.parse::<f64>().ok()).unwrap_or(2.0).max(0.2);
    let gpu_path = find_amd_busy();
    let temp_path = find_temp();
    let dgpu_path = find_dgpu();

    let mut prev = cpu_times();
    let mut disk_val = disk("/home").unwrap_or((0, 0));
    let mut tick: u32 = 0;
    let stdout = std::io::stdout();

    loop {
        std::thread::sleep(Duration::from_secs_f64(interval));
        tick += 1;

        let cur = cpu_times();
        let cpu = match (prev, cur) {
            (Some((t0, i0)), Some((t1, i1))) if t1 > t0 => 100.0 * (1.0 - (i1 - i0) as f64 / (t1 - t0) as f64),
            _ => 0.0,
        };
        prev = cur;

        let (ram_used, ram_total) = meminfo();
        if tick % DISK_EVERY == 0 {
            if let Some(d) = disk("/home") {
                disk_val = d;
            }
        }
        let gpu = read_num(&gpu_path).unwrap_or(-1);
        let temp = read_num(&temp_path).map(|m| m / 1000).unwrap_or(-1);
        let dgpu = dgpu_path.as_ref().and_then(|p| read(p)).map(|s| s.trim().to_string()).unwrap_or_default();
        let load: Vec<String> = read(Path::new("/proc/loadavg"))
            .unwrap_or_default()
            .split_whitespace()
            .take(3)
            .map(String::from)
            .collect();
        let uptime = read(Path::new("/proc/uptime"))
            .and_then(|s| s.split_whitespace().next().and_then(|v| v.parse::<f64>().ok()))
            .unwrap_or(0.0) as u64;

        let line = format!(
            "{{\"cpu\": {:.1}, \"ramUsed\": {}, \"ramTotal\": {}, \"diskUsed\": {}, \"diskSize\": {}, \
             \"gpu\": {}, \"temp\": {}, \"dgpu\": \"{}\", \"load\": [{}], \"uptime\": {}}}\n",
            cpu.clamp(0.0, 100.0),
            ram_used,
            ram_total,
            disk_val.0,
            disk_val.1,
            gpu,
            temp,
            dgpu.replace('"', ""),
            load.join(", "),
            uptime
        );
        let mut out = stdout.lock();
        if out.write_all(line.as_bytes()).and_then(|_| out.flush()).is_err() {
            break; // reader gone
        }
    }
}

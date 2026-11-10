//! R-TECH DESK: a small picture of the remote screen for the "my computers" tiles.
//!
//! While a session shows the remote screen as plain pixels, a frame of the first display is
//! scaled down to 360 pixels wide and saved as `<config dir>/rtech-thumbs/<peer id>.png`:
//! once a few seconds after the start, then every 20 seconds. The main window shows the newest
//! file on the computer's tile, and its time as "last connection".
//! Frames decoded straight into the graphics card (no pixels on the processor side) give no
//! picture; the tile then keeps the previous one.

use hbb_common::{config::Config, log};
use std::{
    collections::HashMap,
    io::Write,
    path::PathBuf,
    sync::Mutex,
    time::{Duration, Instant},
};

const WIDTH: usize = 360;
const FIRST_AFTER: Duration = Duration::from_secs(4);
const EVERY: Duration = Duration::from_secs(20);

struct State {
    started: Instant,
    saved: Option<Instant>,
    busy: bool,
}

lazy_static::lazy_static! {
    static ref STATES: Mutex<HashMap<String, State>> = Default::default();
}

/// The folder of the pictures.
pub fn folder() -> PathBuf {
    Config::path("rtech-thumbs")
}

/// The file name for a computer: only letters, digits, "-" and "_" (the main window uses the
/// same rule).
fn file_name(peer_id: &str) -> String {
    let clean: String = peer_id
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                c
            } else {
                '_'
            }
        })
        .collect();
    format!("{}.png", clean)
}

/// A session with this computer starts showing its screen.
pub fn start(peer_id: &str) {
    if peer_id.is_empty() {
        return;
    }
    if let Ok(mut states) = STATES.lock() {
        states.insert(
            peer_id.to_owned(),
            State {
                started: Instant::now(),
                saved: None,
                busy: false,
            },
        );
    }
}

/// Called with every decoded frame, before it goes to the screen. Cheap when it is not time.
pub fn offer(peer_id: &str, display: usize, rgba: &scrap::ImageRgb) {
    if display != 0 || peer_id.is_empty() || rgba.w < 16 || rgba.h < 16 {
        return;
    }
    let now = Instant::now();
    {
        let mut states = match STATES.lock() {
            Ok(states) => states,
            Err(_) => return,
        };
        let state = states.entry(peer_id.to_owned()).or_insert(State {
            started: now,
            saved: None,
            busy: false,
        });
        let due = match state.saved {
            None => now.duration_since(state.started) >= FIRST_AFTER,
            Some(saved) => now.duration_since(saved) >= EVERY,
        };
        if !due || state.busy {
            return;
        }
        state.saved = Some(now);
        state.busy = true;
    }
    let small = shrink(rgba);
    let id = peer_id.to_owned();
    std::thread::spawn(move || {
        if let Some((w, h, data)) = small {
            if let Err(e) = write(&id, w, h, &data) {
                log::debug!("rtech thumb {}: {}", id, e);
            }
        }
        if let Ok(mut states) = STATES.lock() {
            if let Some(state) = states.get_mut(&id) {
                state.busy = false;
            }
        }
    });
}

/// Scales the frame down to WIDTH pixels wide (RGBA), averaging 3x3 samples per pixel.
fn shrink(rgba: &scrap::ImageRgb) -> Option<(usize, usize, Vec<u8>)> {
    let (w, h) = (rgba.w, rgba.h);
    if matches!(rgba.fmt, scrap::ImageFormat::Raw) || rgba.raw.len() < w * h * 4 {
        return None;
    }
    // Rows may be padded: the buffer is exactly `h` rows long.
    let stride = rgba.raw.len() / h;
    if stride < w * 4 {
        return None;
    }
    // ARGB in libyuv's naming is B, G, R, A in memory; ABGR is R, G, B, A.
    let bgra = matches!(rgba.fmt, scrap::ImageFormat::ARGB);
    let tw = WIDTH.min(w);
    let th = (h * tw / w).max(1);
    let mut out = Vec::with_capacity(tw * th * 4);
    for ty in 0..th {
        let y0 = ty * h / th;
        let y1 = ((ty + 1) * h / th).max(y0 + 1).min(h);
        let ys = [y0, (y0 + y1) / 2, y1 - 1];
        for tx in 0..tw {
            let x0 = tx * w / tw;
            let x1 = ((tx + 1) * w / tw).max(x0 + 1).min(w);
            let xs = [x0, (x0 + x1) / 2, x1 - 1];
            let (mut r, mut g, mut b) = (0u32, 0u32, 0u32);
            for y in ys.iter() {
                let row = y * stride;
                for x in xs.iter() {
                    let i = row + x * 4;
                    let (c0, c1, c2) = (
                        rgba.raw[i] as u32,
                        rgba.raw[i + 1] as u32,
                        rgba.raw[i + 2] as u32,
                    );
                    if bgra {
                        r += c2;
                        g += c1;
                        b += c0;
                    } else {
                        r += c0;
                        g += c1;
                        b += c2;
                    }
                }
            }
            out.extend_from_slice(&[(r / 9) as u8, (g / 9) as u8, (b / 9) as u8, 255]);
        }
    }
    Some((tw, th, out))
}

/// Writes the picture next to the old one and then replaces it, so the main window never
/// reads half a file.
fn write(peer_id: &str, w: usize, h: usize, data: &[u8]) -> std::io::Result<()> {
    let dir = folder();
    std::fs::create_dir_all(&dir)?;
    let name = file_name(peer_id);
    let target = dir.join(&name);
    let temp = dir.join(format!("{}.tmp", name));
    {
        let file = std::fs::File::create(&temp)?;
        let mut writer = std::io::BufWriter::new(file);
        repng::encode(&mut writer, w as u32, h as u32, data)?;
        writer.flush()?;
    }
    std::fs::rename(&temp, &target)?;
    Ok(())
}

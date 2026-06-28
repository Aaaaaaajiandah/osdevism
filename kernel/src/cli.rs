use crate::{vga, keyboard::{self, Key}, fs::Fs};

const HIST_CAP: usize = 16;
const CMD_CAP: usize = 128;

pub fn run() -> ! {
    let mut fs = Fs::new();

    let mut hist: [[u8; CMD_CAP]; HIST_CAP] = [[0; CMD_CAP]; HIST_CAP];
    let mut hist_lens = [0usize; HIST_CAP];
    let mut hist_count = 0usize;
    let mut hist_tail = 0usize;

    let mut buf = [0u8; CMD_CAP];
    let mut len = 0usize;
    let mut browse = 0usize; // 0 = live, 1 = newest history, 2 = one before, …
    let mut saved_buf = [0u8; CMD_CAP];
    let mut saved_len = 0usize;

    prompt(&fs);

    loop {
        match keyboard::read() {
            Key::Char(c) => {
                browse = 0;
                if len < CMD_CAP - 1 {
                    buf[len] = c;
                    len += 1;
                    vga::putchar(c);
                }
            }

            Key::Backspace => {
                browse = 0;
                if len > 0 {
                    len -= 1;
                    vga::putchar(8);
                }
            }

            Key::Enter => {
                browse = 0;
                vga::putchar(b'\n');
                let cmd = trim(&buf[..len]);
                if !cmd.is_empty() {
                    let hlen = cmd.len();
                    hist[hist_tail][..hlen].copy_from_slice(cmd);
                    hist_lens[hist_tail] = hlen;
                    hist_tail = (hist_tail + 1) % HIST_CAP;
                    if hist_count < HIST_CAP { hist_count += 1; }
                    execute(cmd, &mut fs);
                }
                len = 0;
                prompt(&fs);
            }

            Key::Up => {
                if hist_count == 0 { continue; }
                if browse == 0 {
                    saved_len = len;
                    saved_buf[..len].copy_from_slice(&buf[..len]);
                }
                if browse < hist_count {
                    browse += 1;
                    let idx = (hist_tail + HIST_CAP - browse) % HIST_CAP;
                    for _ in 0..len { vga::putchar(8); }
                    len = hist_lens[idx];
                    buf[..len].copy_from_slice(&hist[idx][..len]);
                    vga::print_bytes(&buf[..len]);
                }
            }

            Key::Down => {
                if browse == 0 { continue; }
                browse -= 1;
                for _ in 0..len { vga::putchar(8); }
                if browse == 0 {
                    len = saved_len;
                    buf[..len].copy_from_slice(&saved_buf[..len]);
                } else {
                    let idx = (hist_tail + HIST_CAP - browse) % HIST_CAP;
                    len = hist_lens[idx];
                    buf[..len].copy_from_slice(&hist[idx][..len]);
                }
                vga::print_bytes(&buf[..len]);
            }

            Key::Left | Key::Right => {}
        }
    }
}

fn prompt(fs: &Fs) {
    vga::print_str("[");
    fs.print_path();
    vga::print_str("] > ");
}

fn execute(cmd: &[u8], fs: &mut Fs) {
    if cmd == b"help" {
        vga::print_str("  help          show this\n");
        vga::print_str("  clear         clear screen\n");
        vga::print_str("  echo <text>   print text\n");
        vga::print_str("  pwd           print working directory\n");
        vga::print_str("  ls            list directory\n");
        vga::print_str("  cd <dir>      change directory (.. goes up)\n");
        vga::print_str("  mkdir <dir>   create directory\n");
        vga::print_str("  mkdir -p <path>  create with parents\n");
        vga::print_str("  tree          show directory count\n");
        vga::print_str("  uname         system info\n");
        vga::print_str("  halt          halt the CPU\n");

    } else if cmd == b"clear" {
        vga::clear();
        vga::print_str("HepOS v0.1 -- type 'help' for commands\n\n");

    } else if sw(cmd, b"echo ") {
        vga::print_bytes(trim(&cmd[5..]));
        vga::putchar(b'\n');

    } else if cmd == b"pwd" {
        fs.pwd();

    } else if cmd == b"ls" {
        fs.ls();

    } else if cmd == b"cd" {
        fs.cwd = 0;

    } else if sw(cmd, b"cd ") {
        if !fs.cd(trim(&cmd[3..])) {
            vga::print_str("cd: no such directory\n");
        }

    } else if sw(cmd, b"mkdir -p ") {
        fs.mkdir_p(trim(&cmd[9..]));

    } else if sw(cmd, b"mkdir ") {
        if !fs.mkdir(trim(&cmd[6..])) {
            vga::print_str("mkdir: failed (exists or full)\n");
        }

    } else if cmd == b"tree" {
        vga::print_str("nodes: ");
        vga::print_usize(fs.node_count());
        vga::print_str(" / 64\n");

    } else if cmd == b"uname" {
        vga::print_str("HepOS 0.1 i686 x86\n");

    } else if cmd == b"halt" {
        vga::print_str("halting.\n");
        loop { unsafe { core::arch::asm!("hlt", options(nomem, nostack)); } }

    } else {
        vga::print_str("unknown: ");
        vga::print_bytes(cmd);
        vga::putchar(b'\n');
    }
}

fn sw(s: &[u8], prefix: &[u8]) -> bool {
    s.len() >= prefix.len() && &s[..prefix.len()] == prefix
}

fn trim(s: &[u8]) -> &[u8] {
    let s = match s.iter().position(|&b| b != b' ') {
        Some(i) => &s[i..],
        None => return &[],
    };
    let end = s.iter().rposition(|&b| b != b' ').map(|i| i + 1).unwrap_or(0);
    &s[..end]
}

const VGA: *mut u16 = 0xB8000 as *mut u16;
const W: usize = 80;
const H: usize = 25;
const ATTR: u16 = 0x0700; // light grey on black

static mut CX: usize = 0;
static mut CY: usize = 0;

pub fn init() {
    clear();
    print_str("HepOS v0.1\n");
    print_str("type 'help' for a list of commands\n\n");
}

pub fn clear() {
    unsafe {
        for i in 0..(W * H) {
            VGA.add(i).write_volatile(ATTR | b' ' as u16);
        }
        CX = 0;
        CY = 0;
    }
}

pub fn putchar(c: u8) {
    unsafe {
        match c {
            b'\n' => nl(),
            8 => bs(),
            _ => {
                VGA.add(CY * W + CX).write_volatile(ATTR | c as u16);
                CX += 1;
                if CX >= W { nl(); }
            }
        }
    }
}

unsafe fn nl() {
    CX = 0;
    CY += 1;
    if CY >= H {
        scroll();
        CY = H - 1;
    }
}

unsafe fn bs() {
    if CX > 0 {
        CX -= 1;
    } else if CY > 0 {
        CY -= 1;
        CX = W - 1;
    } else {
        return;
    }
    VGA.add(CY * W + CX).write_volatile(ATTR | b' ' as u16);
}

unsafe fn scroll() {
    for row in 0..(H - 1) {
        for col in 0..W {
            let v = VGA.add((row + 1) * W + col).read_volatile();
            VGA.add(row * W + col).write_volatile(v);
        }
    }
    for col in 0..W {
        VGA.add((H - 1) * W + col).write_volatile(ATTR | b' ' as u16);
    }
}

pub fn print_str(s: &str) {
    for b in s.bytes() { putchar(b); }
}

pub fn print_bytes(b: &[u8]) {
    for &c in b { putchar(c); }
}

pub fn print_usize(mut n: usize) {
    if n == 0 { putchar(b'0'); return; }
    let mut buf = [0u8; 20];
    let mut i = 0;
    while n > 0 { buf[i] = b'0' + (n % 10) as u8; i += 1; n /= 10; }
    while i > 0 { i -= 1; putchar(buf[i]); }
}

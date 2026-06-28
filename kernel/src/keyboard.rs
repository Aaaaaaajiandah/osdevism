#[derive(Clone, Copy, PartialEq)]
pub enum Key {
    Char(u8),
    Enter,
    Backspace,
    Up,
    Down,
    Left,
    Right,
}

pub fn read() -> Key {
    loop {
        let sc = next_scan();
        if sc == 0xE0 {
            let sc2 = next_scan();
            if sc2 & 0x80 != 0 { continue; }
            return match sc2 {
                0x48 => Key::Up,
                0x50 => Key::Down,
                0x4B => Key::Left,
                0x4D => Key::Right,
                _ => continue,
            };
        }
        if sc & 0x80 != 0 { continue; }
        let c = *MAP.get(sc as usize).unwrap_or(&0);
        match c {
            0       => continue,
            b'\n'   => return Key::Enter,
            8       => return Key::Backspace,
            _       => return Key::Char(c),
        }
    }
}

fn next_scan() -> u8 {
    loop {
        if unsafe { inb(0x64) } & 1 != 0 {
            return unsafe { inb(0x60) };
        }
    }
}

unsafe fn inb(port: u16) -> u8 {
    let v: u8;
    core::arch::asm!(
        "in al, dx",
        out("al") v,
        in("dx") port,
        options(nomem, nostack, preserves_flags)
    );
    v
}

#[rustfmt::skip]
static MAP: [u8; 58] = [
//  0     1     2      3      4      5      6      7      8      9      A      B      C      D     E   F
    0,    0,    b'1',  b'2',  b'3',  b'4',  b'5',  b'6',  b'7',  b'8',  b'9',  b'0',  b'-',  b'=', 8,  0,
//  10    11    12     13     14     15     16     17     18     19     1A     1B     1C    1D
    b'q', b'w', b'e',  b'r',  b't',  b'y',  b'u',  b'i',  b'o',  b'p',  b'[',  b']',  b'\n', 0,
//  1E    1F    20     21     22     23     24     25     26     27     28     29    2A
    b'a', b's', b'd',  b'f',  b'g',  b'h',  b'j',  b'k',  b'l',  b';',  b'\'', b'`',  0,
//  2B    2C    2D     2E     2F     30     31     32     33     34     35    36     37     38    39
    b'\\',b'z', b'x',  b'c',  b'v',  b'b',  b'n',  b'm',  b',',  b'.',  b'/', 0,     b'*',  0,    b' ',
];

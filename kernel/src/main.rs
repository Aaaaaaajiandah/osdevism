#![no_std]
#![no_main]

pub mod vga;
pub mod keyboard;
pub mod fs;
pub mod cli;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn kernel_main() -> ! {
    vga::init();
    cli::run();
}

#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    vga::print_str("\n\n!!! KERNEL PANIC !!!\n");
    if let Some(loc) = info.location() {
        vga::print_str(loc.file());
    }
    loop {
        unsafe { core::arch::asm!("hlt", options(nomem, nostack)); }
    }
}

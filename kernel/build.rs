use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=entry.asm");

    let nasm = r"C:\Users\adiya\AppData\Local\bin\NASM\nasm.exe".to_string();

    let status = Command::new(&nasm)
        .args(["-f", "elf32", "entry.asm", "-o", "entry.o"])
        .status()
        .expect("failed to run nasm");

    assert!(status.success(), "nasm failed to assemble entry.asm");
}

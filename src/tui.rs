use std::io::{self, Write};

// Terminal helpers are deliberately isolated here.
// That keeps the application logic free of low-level I/O noise.

pub fn clear_screen() -> Result<(), String> {
    print!("\x1B[2J\x1B[H");
    io::stdout().flush().map_err(|error| error.to_string())
}

pub fn prompt(message: &str) -> Result<String, String> {
    print!("{message}");
    io::stdout().flush().map_err(|error| error.to_string())?;

    let mut input = String::new();
    io::stdin()
        .read_line(&mut input)
        .map_err(|error| error.to_string())?;
    Ok(input)
}

pub fn prompt_required(message: &str, empty_error: &str) -> Result<String, String> {
    loop {
        let input = prompt(message)?;
        let trimmed = input.trim();
        if trimmed.is_empty() {
            println!("{empty_error}");
            continue;
        }
        return Ok(trimmed.to_string());
    }
}

pub fn pause() -> Result<(), String> {
    let _ = prompt("Press Enter to continue...")?;
    Ok(())
}

// The standard library does not provide a portable raw-terminal mode,
// so commands are line-based. The UI still uses single-letter commands
// to keep the interaction compact.
pub fn prompt_command() -> Result<String, String> {
    prompt("[A]dd  [E]dit  [D]elete  [L]ist  [R]eport  [I]mport  [Y]Sync  [Q]uit > ")
}

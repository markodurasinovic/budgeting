use std::process::Command;

// `Entry` is the application's central domain object.
//
// Every budgeting row has:
// - a database-generated primary key (`id`)
// - a logical date (`date`)
// - a free-form item description (`item`)
// - a free-form category (`category`)
// - an amount stored in minor currency units (`amount_cents`)
//
// Using cents instead of floating point avoids precision issues.
#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct Entry {
    pub id: i64,
    pub date: SimpleDate,
    pub item: String,
    pub category: String,
    pub amount_cents: i64,
}

// We keep date handling in a tiny custom type so the project stays within the
// "std only" constraint.
#[derive(Copy, Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct SimpleDate {
    pub day: u32,
    pub month: u32,
    pub year: i32,
}

impl SimpleDate {
    // Parse flexible user input.
    //
    // Supported forms:
    // - ""              -> today
    // - "DD"            -> DD/current_month/current_year
    // - "DD/MM"         -> DD/MM/current_year
    // - "DD/MM/YYYY"    -> exact date
    //
    // Empty components fall back to today's values. For example:
    // - "15//2026" -> 15/current_month/2026
    pub fn parse_partial(input: &str, today: SimpleDate) -> Result<Self, String> {
        let trimmed = input.trim();
        if trimmed.is_empty() {
            return Ok(today);
        }

        let parts: Vec<&str> = trimmed.split('/').collect();
        if parts.len() > 3 {
            return Err(String::from(
                "Date must be DD/MM/YYYY, DD/MM, DD, or blank.",
            ));
        }

        let day = if parts.first().is_some_and(|value| !value.trim().is_empty()) {
            parse_u32(parts[0], "day")?
        } else {
            today.day
        };

        let month = if parts.len() >= 2 && !parts[1].trim().is_empty() {
            parse_u32(parts[1], "month")?
        } else {
            today.month
        };

        let year = if parts.len() == 3 && !parts[2].trim().is_empty() {
            parse_i32(parts[2], "year")?
        } else {
            today.year
        };

        let date = Self { day, month, year };
        date.validate()?;
        Ok(date)
    }

    pub fn parse_ddmmyyyy(input: &str) -> Result<Self, String> {
        let parts: Vec<&str> = input.trim().split('/').collect();
        if parts.len() != 3 {
            return Err(format!("invalid date: {input}"));
        }

        let date = Self {
            day: parse_u32(parts[0], "day")?,
            month: parse_u32(parts[1], "month")?,
            year: parse_i32(parts[2], "year")?,
        };
        date.validate()?;
        Ok(date)
    }

    // Parse the legacy sample CSV format where dates are stored as MM/DD/YYYY.
    pub fn parse_mmddyyyy(input: &str) -> Result<Self, String> {
        let parts: Vec<&str> = input.trim().split('/').collect();
        if parts.len() != 3 {
            return Err(format!("invalid legacy date: {input}"));
        }

        let date = Self {
            month: parse_u32(parts[0], "month")?,
            day: parse_u32(parts[1], "day")?,
            year: parse_i32(parts[2], "year")?,
        };
        date.validate()?;
        Ok(date)
    }

    pub fn display_ddmmyyyy(&self) -> String {
        format!("{:02}/{:02}/{:04}", self.day, self.month, self.year)
    }

    pub fn display_mmyyyy(&self) -> String {
        format!("{:02}/{:04}", self.month, self.year)
    }

    // Postgres DATE literals are easiest to generate in ISO order.
    pub fn display_yyyymmdd(&self) -> String {
        format!("{:04}-{:02}-{:02}", self.year, self.month, self.day)
    }

    pub fn validate(&self) -> Result<(), String> {
        if !(1..=12).contains(&self.month) {
            return Err(String::from("Month must be between 1 and 12."));
        }

        let max_day = days_in_month(self.month, self.year);
        if self.day == 0 || self.day > max_day {
            return Err(format!(
                "Day must be between 1 and {max_day} for that month."
            ));
        }

        Ok(())
    }

    // We try to ask the OS for today's date first.
    // If that fails, we fall back to a UNIX-timestamp-based conversion.
    pub fn today() -> Self {
        if let Ok(output) = Command::new("date").arg("+%d/%m/%Y").output() {
            if output.status.success() {
                if let Ok(text) = String::from_utf8(output.stdout) {
                    if let Ok(date) = Self::parse_ddmmyyyy(text.trim()) {
                        return date;
                    }
                }
            }
        }

        unix_days_to_date(unix_days_now())
    }
}

pub fn parse_money(input: &str) -> Result<i64, String> {
    // Money is stored in cents, not floating point.
    let trimmed = input.trim().replace(',', "");
    if trimmed.is_empty() {
        return Err(String::from("Amount is required."));
    }

    let negative = trimmed.starts_with('-');
    let unsigned = if negative { &trimmed[1..] } else { &trimmed };
    let parts: Vec<&str> = unsigned.split('.').collect();
    if parts.len() > 2 {
        return Err(String::from("Amount must look like 12 or 12.34."));
    }

    let whole = if parts[0].is_empty() {
        0
    } else {
        parts[0]
            .parse::<i64>()
            .map_err(|_| String::from("Amount has an invalid whole number."))?
    };

    let cents = if parts.len() == 2 {
        let fraction = parts[1];
        if fraction.len() > 2 || !fraction.chars().all(|ch| ch.is_ascii_digit()) {
            return Err(String::from("Amount can have at most 2 decimal places."));
        }

        match fraction.len() {
            0 => 0,
            1 => {
                fraction
                    .parse::<i64>()
                    .map_err(|_| String::from("Invalid cents."))?
                    * 10
            }
            _ => fraction
                .parse::<i64>()
                .map_err(|_| String::from("Invalid cents."))?,
        }
    } else {
        0
    };

    let total = whole * 100 + cents;
    Ok(if negative { -total } else { total })
}

pub fn format_money(cents: i64) -> String {
    let sign = if cents < 0 { "-" } else { "" };
    let absolute = cents.abs();
    format!(
        "{}{whole}.{fraction:02}",
        sign,
        whole = absolute / 100,
        fraction = absolute % 100
    )
}

pub fn truncate(input: &str, max_len: usize) -> String {
    input.chars().take(max_len).collect()
}

fn parse_u32(input: &str, label: &str) -> Result<u32, String> {
    input
        .trim()
        .parse::<u32>()
        .map_err(|_| format!("Invalid {label}."))
}

fn parse_i32(input: &str, label: &str) -> Result<i32, String> {
    input
        .trim()
        .parse::<i32>()
        .map_err(|_| format!("Invalid {label}."))
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

fn days_in_month(month: u32, year: i32) -> u32 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if is_leap_year(year) => 29,
        2 => 28,
        _ => 0,
    }
}

fn unix_days_now() -> i64 {
    let now = std::time::SystemTime::now();
    match now.duration_since(std::time::UNIX_EPOCH) {
        Ok(duration) => (duration.as_secs() / 86_400) as i64,
        Err(_) => 0,
    }
}

fn unix_days_to_date(days: i64) -> SimpleDate {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let year = y + if m <= 2 { 1 } else { 0 };

    SimpleDate {
        day: d as u32,
        month: m as u32,
        year: year as i32,
    }
}

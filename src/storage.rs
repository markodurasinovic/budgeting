use std::fs;
use std::path::Path;

use crate::models::{Entry, SimpleDate};

// This module is now responsible only for importing CSV data into the database-backed app.
//
// The runtime source of truth is Postgres. CSV is supported purely as a migration/import path.
pub fn load_entries_from_csv(path: &Path) -> Result<Vec<Entry>, String> {
    let content = fs::read_to_string(path)
        .map_err(|error| format!("could not read {}: {error}", path.display()))?;

    parse_entries(&content)
}

fn parse_entries(content: &str) -> Result<Vec<Entry>, String> {
    let rows = parse_csv(content);
    if rows.is_empty() {
        return Ok(Vec::new());
    }

    let header = rows[0]
        .iter()
        .map(|column| column.trim().to_ascii_lowercase())
        .collect::<Vec<_>>();

    // App CSV format.
    if header.len() >= 4
        && header[0] == "date"
        && header[1] == "item"
        && header[2] == "category"
        && header[3] == "amount"
    {
        let mut entries = Vec::new();
        for row in rows.iter().skip(1) {
            if row.len() < 4 || row.iter().all(|cell| cell.trim().is_empty()) {
                continue;
            }

            entries.push(Entry {
                id: 0,
                date: SimpleDate::parse_ddmmyyyy(row[0].trim())?,
                item: row[1].trim().to_string(),
                category: normalize_category(row[2].trim()),
                amount_cents: crate::models::parse_money(row[3].trim())?,
            });
        }
        return Ok(entries);
    }

    // Legacy export format.
    if header.len() >= 3 && header[0] == "date" && header[1] == "item" && header[2] == "price" {
        let mut entries = Vec::new();
        for row in rows.iter().skip(1) {
            if row.len() < 3 {
                continue;
            }

            let date_cell = row[0].trim();
            let item_cell = row[1].trim();
            let price_cell = row[2].trim();
            if date_cell.is_empty() || item_cell.is_empty() || price_cell.is_empty() {
                continue;
            }

            entries.push(Entry {
                id: 0,
                date: SimpleDate::parse_mmddyyyy(date_cell)?,
                item: item_cell.to_string(),
                category: String::from("Uncategorized"),
                amount_cents: crate::models::parse_money(price_cell)?,
            });
        }
        return Ok(entries);
    }

    Err(String::from("Unsupported CSV format."))
}

fn normalize_category(input: &str) -> String {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        String::from("Uncategorized")
    } else {
        trimmed.to_string()
    }
}

// A small CSV parser that supports quoted fields and escaped quotes.
pub fn parse_csv(content: &str) -> Vec<Vec<String>> {
    let mut rows = Vec::new();
    let mut row = Vec::new();
    let mut field = String::new();
    let mut chars = content.chars().peekable();
    let mut in_quotes = false;

    while let Some(ch) = chars.next() {
        match ch {
            '"' => {
                if in_quotes && chars.peek() == Some(&'"') {
                    field.push('"');
                    chars.next();
                } else {
                    in_quotes = !in_quotes;
                }
            }
            ',' if !in_quotes => row.push(std::mem::take(&mut field)),
            '\n' if !in_quotes => {
                row.push(std::mem::take(&mut field));
                rows.push(std::mem::take(&mut row));
            }
            '\r' if !in_quotes => {}
            other => field.push(other),
        }
    }

    if !field.is_empty() || !row.is_empty() {
        row.push(field);
        rows.push(row);
    }

    rows
}

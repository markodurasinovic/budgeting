use std::cmp::Reverse;
use std::path::PathBuf;

use crate::db::Database;
use crate::models::{Entry, SimpleDate, format_money, parse_money, truncate};
use crate::tui;

pub struct App {
    db: Database,
    entries: Vec<Entry>,
    today: SimpleDate,
    status: String,
}

impl App {
    pub fn load(mut db: Database, today: SimpleDate) -> Result<Self, String> {
        let entries = db.load_entries()?;

        Ok(Self {
            db,
            entries,
            today,
            status: String::from("Ready."),
        })
    }

    pub fn run(&mut self) -> Result<(), String> {
        loop {
            self.render_home()?;
            let command = tui::prompt_command()?;

            match command.trim().to_ascii_lowercase().as_str() {
                "a" | "add" => self.add_entry_flow()?,
                "e" | "edit" => self.edit_entry_flow()?,
                "d" | "delete" => self.delete_entry_flow()?,
                "l" | "list" => self.list_entries_flow()?,
                "r" | "report" => self.report_flow()?,
                "i" | "import" => self.import_csv_flow()?,
                "y" | "sync" | "reload" => self.reload_from_database()?,
                "q" | "quit" => {
                    println!("Goodbye.");
                    break;
                }
                "" => {}
                other => self.status = format!("Unknown command: {other}"),
            }
        }

        Ok(())
    }

    fn render_home(&self) -> Result<(), String> {
        tui::clear_screen()?;

        println!("Budgeting");
        println!("=========");
        println!("Backend: Postgres via psql");
        println!("Target : {}", self.db.target_description());
        println!("Today  : {}", self.today.display_ddmmyyyy());
        println!("Status : {}", self.status);
        println!();

        let month_entries = self.entries_for_month(self.today.month, self.today.year);
        let month_total: i64 = month_entries.iter().map(|entry| entry.amount_cents).sum();

        println!("Current month overview");
        println!("----------------------");
        println!("Month  : {}", self.today.display_mmyyyy());
        println!("Entries: {}", month_entries.len());
        println!("Total  : {}", format_money(month_total));
        println!();

        println!("Recent entries");
        println!("--------------");
        let mut recent: Vec<&Entry> = self.entries.iter().collect();
        recent.sort_by_key(|entry| {
            Reverse((
                entry.date,
                entry.item.as_str(),
                entry.category.as_str(),
                entry.id,
            ))
        });

        if recent.is_empty() {
            println!("(no entries yet)");
        } else {
            for (i, entry) in recent.into_iter().take(8).enumerate() {
                println!(
                    "{:>2}. #{} {} | {:<22} | {:<16} | {}",
                    i + 1,
                    entry.id,
                    entry.date.display_ddmmyyyy(),
                    truncate(&entry.item, 22),
                    truncate(&entry.category, 16),
                    format_money(entry.amount_cents)
                );
            }
        }
        println!();

        Ok(())
    }

    fn add_entry_flow(&mut self) -> Result<(), String> {
        tui::clear_screen()?;
        println!("Add entry");
        println!("---------");

        let item = tui::prompt_required("Item: ", "Item is required.")?;
        let category = tui::prompt_required("Category: ", "Category is required.")?;
        let amount_cents = prompt_for_amount("Amount (e.g. 12.50): ")?;
        let date = prompt_for_date(self.today, "Date [DD/MM/YYYY, DD/MM, DD, blank=today]: ")?;

        let mut entry = Entry {
            id: 0,
            date,
            item: item.clone(),
            category: category.clone(),
            amount_cents,
        };

        let new_id = self.db.insert_entry(&entry)?;
        entry.id = new_id;
        self.entries.push(entry);
        self.sort_entries();

        self.status = format!(
            "Added #{} {} / {} / {} / {}",
            new_id,
            date.display_ddmmyyyy(),
            item,
            category,
            format_money(amount_cents)
        );

        tui::pause()
    }

    fn list_entries_flow(&mut self) -> Result<(), String> {
        tui::clear_screen()?;
        println!("All entries");
        println!("===========");

        let sorted = self.sorted_entries();
        if sorted.is_empty() {
            println!("(no entries)");
        } else {
            for (display_number, entry) in sorted.iter().enumerate() {
                println!(
                    "{:>3}. #{} {} | {:<24} | {:<16} | {}",
                    display_number + 1,
                    entry.id,
                    entry.date.display_ddmmyyyy(),
                    truncate(&entry.item, 24),
                    truncate(&entry.category, 16),
                    format_money(entry.amount_cents)
                );
            }
        }

        self.status = format!("Listed {} entries.", self.entries.len());
        tui::pause()
    }

    fn edit_entry_flow(&mut self) -> Result<(), String> {
        if self.entries.is_empty() {
            self.status = String::from("Nothing to edit.");
            return Ok(());
        }

        self.show_entries_for_selection("Edit entry")?;
        let Some(index) = self.prompt_for_existing_entry_index(
            "Edit entry id [database id after #], blank=cancel: ",
        )?
        else {
            self.status = String::from("Edit cancelled.");
            return Ok(());
        };

        let original = self.entries[index].clone();

        println!();
        println!("Leave a field blank to keep its current value.");

        let item_input = tui::prompt(&format!("Item [{}]: ", original.item))?;
        let category_input = tui::prompt(&format!("Category [{}]: ", original.category))?;
        let amount_input = tui::prompt(&format!(
            "Amount [{}]: ",
            format_money(original.amount_cents)
        ))?;
        let date_input = tui::prompt(&format!("Date [{}]: ", original.date.display_ddmmyyyy()))?;

        let new_item = if item_input.trim().is_empty() {
            original.item.clone()
        } else {
            item_input.trim().to_string()
        };

        let new_category = if category_input.trim().is_empty() {
            original.category.clone()
        } else {
            category_input.trim().to_string()
        };

        let new_amount = if amount_input.trim().is_empty() {
            original.amount_cents
        } else {
            parse_money(amount_input.trim())?
        };

        let new_date = if date_input.trim().is_empty() {
            original.date
        } else {
            SimpleDate::parse_partial(date_input.trim(), self.today)?
        };

        let updated = Entry {
            id: original.id,
            date: new_date,
            item: new_item.clone(),
            category: new_category.clone(),
            amount_cents: new_amount,
        };

        self.db.update_entry(&updated)?;
        self.entries[index] = updated;
        self.sort_entries();

        self.status = format!(
            "Edited #{} to {} / {} / {} / {}",
            original.id,
            new_date.display_ddmmyyyy(),
            new_item,
            new_category,
            format_money(new_amount)
        );

        tui::pause()
    }

    fn delete_entry_flow(&mut self) -> Result<(), String> {
        if self.entries.is_empty() {
            self.status = String::from("Nothing to delete.");
            return Ok(());
        }

        self.show_entries_for_selection("Delete entry")?;
        let Some(index) = self.prompt_for_existing_entry_index(
            "Delete entry id [database id after #], blank=cancel: ",
        )?
        else {
            self.status = String::from("Delete cancelled.");
            return Ok(());
        };

        let removed = self.entries[index].clone();
        let answer = tui::prompt(&format!("Delete #{}? [y/n]: ", removed.id))?;
        if !matches!(answer.trim().to_ascii_lowercase().as_str(), "y" | "yes") {
            self.status = String::from("Delete cancelled.");
            return Ok(());
        }

        self.db.delete_entry(removed.id)?;
        self.entries.remove(index);
        self.status = format!(
            "Deleted #{} {} / {} / {} / {}",
            removed.id,
            removed.date.display_ddmmyyyy(),
            removed.item,
            removed.category,
            format_money(removed.amount_cents)
        );

        tui::pause()
    }

    fn report_flow(&mut self) -> Result<(), String> {
        tui::clear_screen()?;
        println!("Monthly report");
        println!("==============");
        println!("Blank month/year uses current month.");

        let month_input = tui::prompt("Month [1-12, blank=current]: ")?;
        let year_input = tui::prompt("Year [blank=current]: ")?;

        let month = if month_input.trim().is_empty() {
            self.today.month
        } else {
            month_input
                .trim()
                .parse::<u32>()
                .map_err(|_| String::from("Invalid month."))?
        };

        let year = if year_input.trim().is_empty() {
            self.today.year
        } else {
            year_input
                .trim()
                .parse::<i32>()
                .map_err(|_| String::from("Invalid year."))?
        };

        if !(1..=12).contains(&month) {
            return Err(String::from("Month must be between 1 and 12."));
        }

        tui::clear_screen()?;
        println!("Report for {:02}/{:04}", month, year);
        println!("==================");

        let entries = self.entries_for_month(month, year);
        if entries.is_empty() {
            println!("No entries for that month.");
            self.status = format!("No entries for {:02}/{:04}.", month, year);
            return tui::pause();
        }

        let total: i64 = entries.iter().map(|entry| entry.amount_cents).sum();
        println!("Entries: {}", entries.len());
        println!("Total  : {}", format_money(total));
        println!();

        println!("By category");
        println!("-----------");
        let mut category_totals = self.category_totals_for_month(month, year);
        category_totals.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        for (category, amount) in category_totals {
            println!("{: <20} {}", truncate(&category, 20), format_money(amount));
        }
        println!();

        println!("Entries in month");
        println!("----------------");
        for entry in entries {
            println!(
                "#{} {} | {:<24} | {:<16} | {}",
                entry.id,
                entry.date.display_ddmmyyyy(),
                truncate(&entry.item, 24),
                truncate(&entry.category, 16),
                format_money(entry.amount_cents)
            );
        }

        self.status = format!("Displayed report for {:02}/{:04}.", month, year);
        tui::pause()
    }

    fn import_csv_flow(&mut self) -> Result<(), String> {
        tui::clear_screen()?;
        println!("Import CSV into Postgres");
        println!("========================");
        println!("Supported formats:");
        println!("- Date,Item,Category,Amount");
        println!("- legacy Date,Item,Price,...");
        println!();

        let path_input = tui::prompt_required("CSV path: ", "CSV path is required.")?;
        let path = PathBuf::from(path_input.trim());

        let inserted = self.db.import_csv_file(&path)?;
        self.entries = self.db.load_entries()?;
        self.sort_entries();
        self.status = format!("Imported {} rows from {}.", inserted, path.display());
        tui::pause()
    }

    fn reload_from_database(&mut self) -> Result<(), String> {
        self.entries = self.db.load_entries()?;
        self.sort_entries();
        self.status = format!("Reloaded {} entries from Postgres.", self.entries.len());
        Ok(())
    }

    fn sort_entries(&mut self) {
        self.entries.sort_by_key(|entry| {
            (
                entry.date,
                entry.item.clone(),
                entry.category.clone(),
                entry.id,
            )
        });
    }

    fn entries_for_month(&self, month: u32, year: i32) -> Vec<&Entry> {
        self.entries
            .iter()
            .filter(|entry| entry.date.month == month && entry.date.year == year)
            .collect()
    }

    fn category_totals_for_month(&self, month: u32, year: i32) -> Vec<(String, i64)> {
        let mut totals: Vec<(String, i64)> = Vec::new();

        for entry in self.entries_for_month(month, year) {
            if let Some((_, total)) = totals
                .iter_mut()
                .find(|(category, _)| category == &entry.category)
            {
                *total += entry.amount_cents;
            } else {
                totals.push((entry.category.clone(), entry.amount_cents));
            }
        }

        totals
    }

    fn sorted_entries(&self) -> Vec<&Entry> {
        let mut sorted: Vec<&Entry> = self.entries.iter().collect();
        sorted.sort_by_key(|entry| {
            Reverse((
                entry.date,
                entry.item.as_str(),
                entry.category.as_str(),
                entry.id,
            ))
        });
        sorted
    }

    fn show_entries_for_selection(&self, title: &str) -> Result<(), String> {
        tui::clear_screen()?;
        println!("{title}");
        println!("{}", "=".repeat(title.len()));

        for (display_number, entry) in self.sorted_entries().iter().enumerate() {
            println!(
                "{:>3}. #{} {} | {:<24} | {:<16} | {}",
                display_number + 1,
                entry.id,
                entry.date.display_ddmmyyyy(),
                truncate(&entry.item, 24),
                truncate(&entry.category, 16),
                format_money(entry.amount_cents)
            );
        }

        Ok(())
    }

    // We select entries by database id, not by vector index.
    // That makes the UI more stable: ids do not change when the in-memory list is re-sorted.
    fn prompt_for_existing_entry_index(&self, message: &str) -> Result<Option<usize>, String> {
        let input = tui::prompt(message)?;
        let trimmed = input.trim();
        if trimmed.is_empty() {
            return Ok(None);
        }

        let id = trimmed
            .parse::<i64>()
            .map_err(|_| String::from("Please enter a valid entry id."))?;

        let index = self
            .entries
            .iter()
            .position(|entry| entry.id == id)
            .ok_or_else(|| String::from("Entry id not found."))?;

        Ok(Some(index))
    }
}

fn prompt_for_amount(message: &str) -> Result<i64, String> {
    loop {
        let input = tui::prompt(message)?;
        match parse_money(input.trim()) {
            Ok(value) => return Ok(value),
            Err(error) => println!("{error}"),
        }
    }
}

fn prompt_for_date(today: SimpleDate, message: &str) -> Result<SimpleDate, String> {
    loop {
        let input = tui::prompt(message)?;
        match SimpleDate::parse_partial(input.trim(), today) {
            Ok(value) => return Ok(value),
            Err(error) => println!("{error}"),
        }
    }
}

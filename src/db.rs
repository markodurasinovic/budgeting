use std::env;
use std::path::Path;

use postgres::{Client, NoTls};

use crate::models::{Entry, SimpleDate};
use crate::storage;

// DatabaseConfig captures everything needed to connect to Postgres.
//
// Unlike the earlier `psql`-based approach, this version uses the official-ish
// synchronous Rust `postgres` crate directly. That gives us parameterized queries,
// typed row access, and a much cleaner persistence layer.
#[derive(Clone, Debug)]
pub struct DatabaseConfig {
    pub host: String,
    pub port: u16,
    pub database: String,
    pub user: String,
    pub password: Option<String>,
}

impl DatabaseConfig {
    pub fn from_env() -> Self {
        let host = env::var("BUDGETING_PGHOST")
            .or_else(|_| env::var("PGHOST"))
            .unwrap_or_else(|_| String::from("localhost"));

        let port = env::var("BUDGETING_PGPORT")
            .or_else(|_| env::var("PGPORT"))
            .ok()
            .and_then(|value| value.parse::<u16>().ok())
            .unwrap_or(5432);

        let database = env::var("BUDGETING_PGDATABASE")
            .or_else(|_| env::var("PGDATABASE"))
            .unwrap_or_else(|_| String::from("budgeting"));

        let user = env::var("BUDGETING_PGUSER")
            .or_else(|_| env::var("PGUSER"))
            .or_else(|_| env::var("USER"))
            .unwrap_or_else(|_| String::from("postgres"));

        let password = env::var("BUDGETING_PGPASSWORD")
            .or_else(|_| env::var("PGPASSWORD"))
            .ok();

        Self {
            host,
            port,
            database,
            user,
            password,
        }
    }

    pub fn display_target(&self) -> String {
        format!(
            "{}@{}:{}/{}",
            self.user, self.host, self.port, self.database
        )
    }

    fn connection_string(&self) -> String {
        let mut value = format!(
            "host={} port={} dbname={} user={}",
            self.host,
            self.port,
            escape_conn_value(&self.database),
            escape_conn_value(&self.user)
        );

        if let Some(password) = &self.password {
            value.push(' ');
            value.push_str("password=");
            value.push_str(&escape_conn_value(password));
        }

        value
    }
}

pub struct Database {
    client: Client,
    config: DatabaseConfig,
}

impl Database {
    pub fn connect(config: DatabaseConfig) -> Result<Self, String> {
        let client = Client::connect(&config.connection_string(), NoTls)
            .map_err(|error| format!("could not connect to Postgres: {error}"))?;

        let mut database = Self { client, config };
        database.ensure_schema()?;
        Ok(database)
    }

    pub fn target_description(&self) -> String {
        self.config.display_target()
    }

    // Read the current working set from Postgres into memory.
    //
    // The app still keeps an in-memory snapshot for simple TUI rendering and
    // reporting, but persistence is handled directly through SQL.
    pub fn load_entries(&mut self) -> Result<Vec<Entry>, String> {
        let rows = self
            .client
            .query(
                "
                SELECT id, entry_date::text, item, category, amount_cents
                FROM entries
                ORDER BY entry_date, item, category, id
                ",
                &[],
            )
            .map_err(|error| format!("could not load entries: {error}"))?;

        let mut entries = Vec::new();
        for row in rows {
            let date_text: String = row.get(1);
            entries.push(Entry {
                id: row.get::<_, i64>(0),
                date: parse_postgres_date(&date_text)?,
                item: row.get::<_, String>(2),
                category: normalize_category(&row.get::<_, String>(3)),
                amount_cents: row.get::<_, i64>(4),
            });
        }

        Ok(entries)
    }

    pub fn insert_entry(&mut self, entry: &Entry) -> Result<i64, String> {
        let row = self
            .client
            .query_one(
                "
                INSERT INTO entries (entry_date, item, category, amount_cents)
                VALUES ($1::date, $2, $3, $4)
                RETURNING id
                ",
                &[
                    &entry.date.display_yyyymmdd(),
                    &entry.item,
                    &entry.category,
                    &entry.amount_cents,
                ],
            )
            .map_err(|error| format!("could not insert entry: {error}"))?;

        Ok(row.get::<_, i64>(0))
    }

    pub fn update_entry(&mut self, entry: &Entry) -> Result<(), String> {
        self.client
            .execute(
                "
                UPDATE entries
                SET entry_date = $1::date,
                    item = $2,
                    category = $3,
                    amount_cents = $4,
                    updated_at = NOW()
                WHERE id = $5
                ",
                &[
                    &entry.date.display_yyyymmdd(),
                    &entry.item,
                    &entry.category,
                    &entry.amount_cents,
                    &entry.id,
                ],
            )
            .map_err(|error| format!("could not update entry {}: {error}", entry.id))?;

        Ok(())
    }

    pub fn delete_entry(&mut self, id: i64) -> Result<(), String> {
        self.client
            .execute("DELETE FROM entries WHERE id = $1", &[&id])
            .map_err(|error| format!("could not delete entry {id}: {error}"))?;
        Ok(())
    }

    pub fn import_csv_file(&mut self, path: &Path) -> Result<usize, String> {
        let entries = storage::load_entries_from_csv(path)?;
        let transaction = self
            .client
            .transaction()
            .map_err(|error| format!("could not start import transaction: {error}"))?;

        let mut inserted = 0usize;
        let mut transaction = transaction;
        for entry in entries {
            transaction
                .execute(
                    "
                    INSERT INTO entries (entry_date, item, category, amount_cents)
                    VALUES ($1::date, $2, $3, $4)
                    ",
                    &[
                        &entry.date.display_yyyymmdd(),
                        &entry.item,
                        &entry.category,
                        &entry.amount_cents,
                    ],
                )
                .map_err(|error| format!("could not import row: {error}"))?;
            inserted += 1;
        }

        transaction
            .commit()
            .map_err(|error| format!("could not commit import transaction: {error}"))?;

        Ok(inserted)
    }

    fn ensure_schema(&mut self) -> Result<(), String> {
        self.client
            .batch_execute(
                "
                CREATE TABLE IF NOT EXISTS entries (
                    id BIGSERIAL PRIMARY KEY,
                    entry_date DATE NOT NULL,
                    item TEXT NOT NULL,
                    category TEXT NOT NULL,
                    amount_cents BIGINT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                ",
            )
            .map_err(|error| format!("could not ensure schema: {error}"))?;

        Ok(())
    }
}

fn normalize_category(input: &str) -> String {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        String::from("Uncategorized")
    } else {
        trimmed.to_string()
    }
}

fn parse_postgres_date(input: &str) -> Result<SimpleDate, String> {
    let parts: Vec<&str> = input.trim().split('-').collect();
    if parts.len() != 3 {
        return Err(format!("invalid date from postgres: {input}"));
    }

    let year = parts[0]
        .parse::<i32>()
        .map_err(|_| format!("invalid postgres year: {}", parts[0]))?;
    let month = parts[1]
        .parse::<u32>()
        .map_err(|_| format!("invalid postgres month: {}", parts[1]))?;
    let day = parts[2]
        .parse::<u32>()
        .map_err(|_| format!("invalid postgres day: {}", parts[2]))?;

    let date = SimpleDate { day, month, year };
    date.validate()?;
    Ok(date)
}

fn escape_conn_value(input: &str) -> String {
    if input
        .chars()
        .all(|ch| ch.is_ascii_alphanumeric() || matches!(ch, '_' | '-' | '.'))
    {
        input.to_string()
    } else {
        format!("'{}'", input.replace('\\', "\\\\").replace('\'', "\\'"))
    }
}

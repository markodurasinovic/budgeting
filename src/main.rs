mod app;
mod db;
mod models;
mod storage;
mod tui;

use app::App;
use db::{Database, DatabaseConfig};
use models::SimpleDate;

fn main() {
    // The application is database-backed.
    //
    // Connection settings come from environment variables. See the README for
    // the full list and default values.
    let config = DatabaseConfig::from_env();
    let database = match Database::connect(config) {
        Ok(database) => database,
        Err(error) => {
            eprintln!("Failed to connect to Postgres: {error}");
            return;
        }
    };

    let today = SimpleDate::today();
    let mut app = match App::load(database, today) {
        Ok(app) => app,
        Err(error) => {
            eprintln!("Failed to start budgeting app: {error}");
            return;
        }
    };

    if let Err(error) = app.run() {
        eprintln!("Application error: {error}");
    }
}

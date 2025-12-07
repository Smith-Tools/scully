import Foundation

/// Database schema definitions for Scully
public struct ScullySchema {
    /// SQLite table definitions
    public static let createTables = [
        """
        CREATE TABLE IF NOT EXISTS packages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            url TEXT UNIQUE NOT NULL,
            description TEXT,
            version TEXT,
            license TEXT,
            author TEXT,
            stars INTEGER,
            forks INTEGER,
            last_updated DATETIME,
            repository_type TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS documentations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            version TEXT,
            content TEXT NOT NULL,
            type TEXT NOT NULL,
            url TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS code_examples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            title TEXT NOT NULL,
            code TEXT NOT NULL,
            language TEXT,
            description TEXT,
            source TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE TABLE IF NOT EXISTS usage_patterns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            pattern TEXT NOT NULL,
            frequency INTEGER,
            examples TEXT,
            description TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        """,
        """
        CREATE INDEX IF NOT EXISTS idx_packages_name ON packages(name);
        CREATE INDEX IF NOT EXISTS idx_packages_url ON packages(url);
        CREATE INDEX IF NOT EXISTS idx_documentations_package ON documentations(package_name);
        CREATE INDEX IF NOT EXISTS idx_examples_package ON code_examples(package_name);
        CREATE INDEX IF NOT EXISTS idx_patterns_package ON usage_patterns(package_name);
        """
    ]
}
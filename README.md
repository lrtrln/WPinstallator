# WordPress Install Script

A comprehensive shell script to automate the installation and setup of a new WordPress site for local development using WP-CLI.

## Features

This script streamlines the entire setup process:

-   **Interactive & User-Friendly**:
    -   Guides you through a series of questions to configure your site.
    -   Provides smart defaults based on your project name to speed up the process.
    -   Hides password inputs for better security.
    -   Displays a summary of all settings and asks for confirmation before running, allowing you to correct any mistakes.

-   **WordPress Core**:
    -   Downloads the latest version of WordPress in your chosen language.
    -   Configures `wp-config.php` with your database credentials and adds useful debugging constants.
    -   Runs the WordPress installation.

-   **Database Setup**:
    -   Supports both **MySQL** and **SQLite**.
    -   For MySQL: Creates a new database and user.
    -   For SQLite: Configures the WordPress SQLite Integration plugin, sets up the database directory with appropriate permissions, and creates a minimal `wp-config.php`.

-   **Server Environment (Optional)**:
    -   **Apache VirtualHost**: Automatically creates and enables an Apache vhost configuration for a clean local URL (e.g., `http://myproject.local`).
    -   **Hosts File**: Updates your `/etc/hosts` file to point your local URL to `127.0.0.1`.
    -   *(Note: This step requires `sudo` privileges and is designed for Debian/Ubuntu-based systems with Apache.)*

-   **Post-Installation Cleanup & Configuration**:
    -   Sets pretty permalinks (`/%postname%/`).
    -   Configures basic WordPress options (timezone, search engine visibility off, etc.).
    -   Deletes the default "Hello Dolly" plugin.
    -   Generates the `.htaccess` file.

## Requirements

This script is designed to run on a Linux environment and has the following dependencies:

-   A **Linux-based** operating system (e.g., Debian, Ubuntu).
-   **WP-CLI**: Must be installed and accessible in your system's `PATH`. You can find installation instructions here.
-   **MySQL/MariaDB**: The `mysql` command-line client is needed for database operations.
-   **`curl` or `wget`**: Required to download the SQLite Integration plugin *if you choose SQLite*.
-   **`unzip`**: Required to extract the SQLite Integration plugin *if you choose SQLite*.
-   **Apache2**: Required if you want to use the automatic VirtualHost creation feature.
-   **`sudo` privileges**: Needed to create the database, manage the Apache VHost, and edit the `/etc/hosts` file.

## Run the script

`chmod +x wpinstall.sh`

For easy access, you can create an alias in your `.bashrc` or `.zshrc` file:
`alias wpinstall='bash /path/to/your/script/wpinstall.sh'`

Then simply run the `wpinstall` command from the directory where you want to create your project.
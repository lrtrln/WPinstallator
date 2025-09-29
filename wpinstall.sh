#!/bin/bash -e

# Check wp-cli installed
if ! type wp >/dev/null 2>&1; then
    echo >&2 "This script requires wp-cli but it's not installed. Aborting."
    exit 1
fi

# colors
blue="\033[34m"
red="\033[1;31m"
green="\033[32m"
white="\033[37m"
yellow="\033[33m"

function get_user_inputs() {
    echo "============================================"
    echo "WordPress Install Script"
    echo "============================================"

    read -rp "$(echo -e "${blue}Enter project name:${white} ")" pname
    # Sanitize project name to suggest it as dbname, dbuser, etc.
    local suggested_name
    suggested_name=$(echo "$pname" | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    read -rp "$(echo -e "${blue}Subfolder for installation (leave empty for current directory):${white} ")" folder

    read -rp "$(echo -e "${blue}Database type (mysql/sqlite) [default: mysql]:${white} ")" db_type
    db_type=${db_type:-mysql}

    if [[ "$db_type" == "mysql" ]]; then
        read -rp "$(echo -e "${blue}Database name (default: $suggested_name):${white} ")" dbname
        dbname=${dbname:-$suggested_name}

        read -rp "$(echo -e "${blue}Database user (default: $suggested_name):${white} ")" dbuser
        dbuser=${dbuser:-$suggested_name}

        read -rsp "$(echo -e "${blue}Database password:${white} ")" dbpass
        echo
    fi

    read -rp "$(echo -e "${blue}Language (default: en_US):${white} ")" lang
    lang=${lang:-en_US}

    read -rp "$(echo -e "${blue}Site URL (e.g., localhost/wp, without http://):${white} ")" siteurl

    read -rp "$(echo -e "${blue}Site title (default: $pname):${white} ")" sitetitle
    sitetitle=${sitetitle:-$pname}

    read -rp "$(echo -e "${blue}Admin username (default: admin):${white} ")" adminuser
    adminuser=${adminuser:-admin}

    read -rsp "$(echo -e "${blue}Admin password:${white} ")" adminpassword
    echo

    read -rp "$(echo -e "${blue}Admin email:${white} ")" adminemail

    read -rp "$(echo -e "${blue}Create Apache vhost for local development? (y/n):${white} ")" create_vhost

    # Validation
    if [[ "$db_type" == "mysql" && (-z "$pname" || -z "$dbname" || -z "$dbuser" || -z "$dbpass") ]] || [[ -z "$siteurl" || -z "$sitetitle" || -z "$adminuser" || -z "$adminpassword" || -z "$adminemail" ]]; then
        echo -e "${red}One or more required fields are empty. Please try again.${white}"
        return 1
    fi
}

function setup_apache_vhost() {
    local doc_root
    doc_root=$(pwd)
    local vhost_file="/etc/apache2/sites-available/$siteurl.conf"

    echo -e "${yellow}Sudo privileges will be required to create the vhost, edit /etc/hosts, and reload Apache.${white}"

    local vhost_content="<VirtualHost *:80>
    ServerName $siteurl
    DocumentRoot $doc_root
    <Directory $doc_root>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$siteurl-error.log
    CustomLog \${APACHE_LOG_DIR}/$siteurl-access.log combined
</VirtualHost>"

    echo -e "${green}* Creating Apache vhost configuration...${white}"
    echo "$vhost_content" | sudo tee "$vhost_file" > /dev/null

    echo -e "${green}* Adding '$siteurl' to /etc/hosts...${white}"
    if ! grep -q "127.0.0.1\s*$siteurl" /etc/hosts; then
        echo "127.0.0.1 $siteurl" | sudo tee -a /etc/hosts > /dev/null
    else
        echo -e "${yellow}* '$siteurl' already exists in /etc/hosts. Skipping.${white}"
    fi

    echo -e "${green}* Enabling site and reloading Apache...${white}"
    sudo a2ensite "$siteurl.conf"
    sudo systemctl reload apache2

    echo -e "${green}* Apache vhost setup complete.${white}"
}

function check_mysql_database_exists() {
    local MYSQL
    MYSQL=$(which mysql)
    
    echo -e "${green}* Checking if database exists... (MySQL root password required)${white}"
    
    # Check if database exists
    local db_exists
    db_exists=$($MYSQL -uroot -p -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$dbname';" 2>/dev/null | grep -c "$dbname" || echo "0")
    
    if [[ "$db_exists" -gt 0 ]]; then
        echo -e "\n${red}========================================${white}"
        echo -e "${red}WARNING: Database already exists!${white}"
        echo -e "${red}========================================${white}"
        echo -e "${yellow}* Database name: $dbname${white}"
        
        # Get table count
        local table_count
        table_count=$($MYSQL -uroot -p -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$dbname';" 2>/dev/null | tail -n1)
        echo -e "${yellow}* Number of tables: $table_count${white}"
        
        echo -e "\n${red}Continuing will DROP and RECREATE this database!${white}"
        echo -e "${red}ALL DATA WILL BE LOST!${white}\n"
        
        read -rp "$(echo -e "${red}Are you sure you want to drop and recreate the database? (yes/no):${white} ")" confirm_drop_db
        
        if [[ "$confirm_drop_db" != "yes" ]]; then
            echo -e "${green}Installation cancelled. Database preserved.${white}"
            exit 0
        fi
        
        echo -e "${yellow}* Dropping existing database...${white}"
        $MYSQL -uroot -p -e "DROP DATABASE \`$dbname\`;" 2>/dev/null
        echo -e "${green}* Database dropped successfully.${white}"
    fi
}

function install_with_mysql() {
    # Check if database already exists
    check_mysql_database_exists
    
    echo -e "${green}* Creating database and user...${white}"
    local MYSQL
    MYSQL=$(which mysql)
    Q1="CREATE DATABASE IF NOT EXISTS \`$dbname\`;"
    Q2="CREATE USER IF NOT EXISTS '$dbuser'@'localhost' IDENTIFIED BY '$dbpass';"
    Q3="GRANT ALL PRIVILEGES ON \`$dbname\`.* TO '$dbuser'@'localhost';"
    Q4="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}${Q4}"
    $MYSQL -uroot -p -e "$SQL"
    echo -e "${green}* Database setup complete.${white}"

    echo -e "${green}* Configuring wp-config.php for MySQL...${white}"
    wp core config --dbname="$dbname" --dbuser="$dbuser" --dbpass="$dbpass" --extra-php <<PHP
define( 'WP_DEBUG', true );
// Force display of errors and warnings
define( 'WP_DEBUG_DISPLAY', true );
@ini_set( 'display_errors', 1 );
// Enable Save Queries
define( 'SAVEQUERIES', true );
// Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
define( 'SCRIPT_DEBUG', true );
PHP
}

function check_sqlite_database_exists() {
    local target_dir="wp-content/database"
    
    # Check if SQLite database directory and files exist
    if [[ -d "$target_dir" ]]; then
        local db_files
        db_files=$(find "$target_dir" -type f \( -name "*.sqlite" -o -name "*.db" -o -name ".ht.sqlite" \) 2>/dev/null)
        
        if [[ -n "$db_files" ]]; then
            echo -e "\n${red}========================================${white}"
            echo -e "${red}WARNING: SQLite database already exists!${white}"
            echo -e "${red}========================================${white}"
            echo -e "${yellow}* Database directory: $target_dir${white}"
            echo -e "${yellow}* Database files found:${white}"
            echo "$db_files" | while read -r file; do
                local size=$(du -h "$file" | cut -f1)
                echo -e "${yellow}  - $(basename "$file") ($size)${white}"
            done
            
            echo -e "\n${red}Continuing will DELETE the existing SQLite database!${white}"
            echo -e "${red}ALL DATA WILL BE LOST!${white}\n"
            
            read -rp "$(echo -e "${red}Are you sure you want to delete and recreate the database? (yes/no):${white} ")" confirm_drop_sqlite
            
            if [[ "$confirm_drop_sqlite" != "yes" ]]; then
                echo -e "${green}Installation cancelled. SQLite database preserved.${white}"
                exit 0
            fi
            
            echo -e "${yellow}* Removing existing SQLite database files...${white}"
            rm -rf "$target_dir"
            echo -e "${green}* SQLite database removed successfully.${white}"
        fi
    fi
}

function install_with_sqlite() {
    # Check if SQLite database already exists
    check_sqlite_database_exists
    
    echo -e "${green}* Setting up SQLite database...${white}"
    
    # Download the official WordPress SQLite plugin
    local sqlite_plugin="https://downloads.wordpress.org/plugin/sqlite-database-integration.zip"
    
    echo -e "${green}* Downloading official SQLite plugin...${white}"
    if command -v curl &> /dev/null; then
        curl -sL "$sqlite_plugin" -o sqlite-plugin.zip
    elif command -v wget &> /dev/null; then
        wget -q "$sqlite_plugin" -O sqlite-plugin.zip
    else
        echo -e "${red}Error: curl or wget required. Aborting.${white}"
        exit 1
    fi
    
    unzip -q sqlite-plugin.zip -d wp-content/plugins/
    rm sqlite-plugin.zip
    
    # Install the db.php drop-in
    if [[ -f "wp-content/plugins/sqlite-database-integration/db.php" ]]; then
        cp wp-content/plugins/sqlite-database-integration/db.php wp-content/db.php
    elif [[ -f "wp-content/plugins/sqlite-database-integration/db.copy" ]]; then
        cp wp-content/plugins/sqlite-database-integration/db.copy wp-content/db.php
    else
        echo -e "${red}Error: db.php not found in plugin. Aborting.${white}"
        exit 1
    fi
    
    # Create database directory
    mkdir -p wp-content/database
    chmod 755 wp-content/database
    
    # For SQLite, we create a minimal wp-config that won't try to connect to MySQL
    echo -e "${green}* Creating wp-config.php for SQLite...${white}"
    
    # Use wp-cli but with environment variables to prevent MySQL connection
    WORDPRESS_DB_HOST="" WORDPRESS_DB_USER="" WORDPRESS_DB_PASSWORD="" WORDPRESS_DB_NAME="" \
    wp core config --dbname="not_used" --dbuser="not_used" --dbpass="not_used" --skip-check --extra-php <<PHP
define( 'WP_DEBUG', true );
define( 'WP_DEBUG_DISPLAY', true );
@ini_set( 'display_errors', 1 );
define( 'SAVEQUERIES', true );
define( 'SCRIPT_DEBUG', true );
PHP

    echo -e "${green}* SQLite configuration complete.${white}"
}

function confirm_and_install() {
    while true; do
        get_user_inputs || continue

        echo -e "\n${yellow}--- Installation Summary ---"
        echo -e "Project Name:      $pname"
        echo -e "Install folder:    ${folder:-. (current directory)}"
        echo -e "Site URL:          http://$siteurl"
        echo -e "Site Title:        $sitetitle"
        echo -e "Admin User:        $adminuser"
        echo -e "Admin Email:       $adminemail"
        echo -e "Language:          $lang"
        echo -e "Database Type:     $db_type"
        if [[ "$db_type" == "mysql" ]]; then
            echo -e "DB Name:           $dbname"
            echo -e "DB User:           $dbuser"
        fi
        if [[ "$create_vhost" =~ ^[Yy]$ ]]; then
            echo -e "Create Vhost:      Yes"
        fi
        echo -e "--------------------------${white}\n"

        read -rp "$(echo -e "${blue}Proceed with installation? (y/n):${white} ")" run

        if [[ "$run" =~ ^[Yy]$ ]]; then
            break
        elif [[ "$run" =~ ^[Nn]$ ]]; then
            read -rp "$(echo -e "${blue}Do you want to re-enter the details? (y/n):${white} ")" reenter
            if [[ "$reenter" =~ ^[Nn]$ ]]; then
                echo "Installation aborted."
                exit 0
            fi
        else
            echo -e "${red}Invalid input. Please enter 'y' or 'n'.${white}"
        fi
    done

    # Create and cd into folder if specified
    if [[ -n "$folder" ]]; then
        mkdir -p "$folder" && cd "$folder" || { echo "Failed to create directory $folder"; exit 1; }
    fi

    # Check if WordPress is already installed
    if [[ -f "wp-config.php" ]] || [[ -f "wp-load.php" ]] || [[ -d "wp-content" ]] || [[ -d "wp-admin" ]]; then
        echo -e "\n${red}========================================${white}"
        echo -e "${red}WARNING: WordPress installation detected!${white}"
        echo -e "${red}========================================${white}"
        
        if [[ -f "wp-config.php" ]]; then
            echo -e "${yellow}* wp-config.php exists${white}"
        fi
        if [[ -d "wp-content" ]]; then
            echo -e "${yellow}* wp-content directory exists${white}"
        fi
        if [[ -d "wp-admin" ]]; then
            echo -e "${yellow}* wp-admin directory exists${white}"
        fi
        
        echo -e "\n${red}Installing WordPress here will OVERWRITE existing files!${white}"
        read -rp "$(echo -e "${red}Are you sure you want to continue? (yes/no):${white} ")" confirm_overwrite
        
        if [[ "$confirm_overwrite" != "yes" ]]; then
            echo -e "${green}Installation cancelled. Your existing WordPress is safe.${white}"
            exit 0
        fi
        
        echo -e "${yellow}* Proceeding with installation (existing files will be overwritten)...${white}\n"
    fi

    # Setup vhost if requested
    if [[ "$create_vhost" =~ ^[Yy]$ ]]; then
        setup_apache_vhost
    fi

    echo -e "${green}* Downloading WordPress...${white}"
    wp core download --locale="$lang"

    # Database setup
    if [[ "$db_type" == "sqlite" ]]; then
        install_with_sqlite
    else
        install_with_mysql
    fi

    echo -e "${green}* Installing WordPress...${white}"
    if [[ "$db_type" == "sqlite" ]]; then
        # For SQLite, set env vars to bypass MySQL connection during install
        WORDPRESS_DB_HOST="" WORDPRESS_DB_USER="" WORDPRESS_DB_PASSWORD="" WORDPRESS_DB_NAME="" \
        wp core install --url="http://$siteurl" --title="$sitetitle" --admin_user="$adminuser" --admin_password="$adminpassword" --admin_email="$adminemail" --skip-email
    else
        wp core install --url="http://$siteurl" --title="$sitetitle" --admin_user="$adminuser" --admin_password="$adminpassword" --admin_email="$adminemail"
    fi

    echo -e "${green}* Post-installation setup...${white}"

    wp rewrite structure '/%postname%/' --hard
    wp option update timezone_string "Europe/Paris"
    wp option update blog_public "0"
    wp option update default_ping_status 'closed'
    wp option update default_pingback_flag '0'
    wp option update blogdescription "A new WordPress site"
    
    # Clean up default plugins
    if wp plugin is-installed hello 2>/dev/null; then
        wp plugin delete hello 2>/dev/null || true
    fi
    
    wp rewrite flush --hard

    echo -e "\n${green}========================================${white}"
    echo -e "${green}* WordPress installation finished! *${white}"
    echo -e "${green}========================================${white}"
    echo -e "You can now log in at ${yellow}http://$siteurl/wp-admin/${white}"
    echo -e "Username: ${yellow}$adminuser${white}"
    if [[ "$db_type" == "sqlite" ]]; then
        echo -e "\n${green}SQLite database location: wp-content/database/${white}"
    fi
    echo -e "${green}========================================${white}\n"
}

confirm_and_install
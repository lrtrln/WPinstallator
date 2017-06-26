# Install WordPress from the CLI

Shell script to install the latest version of WordPress with WPCLI.

## Features (wp-cli required)
- Creates MySQL database.
- Automatic installation of WordPress.
- Write wpconfig with ``` define( 'WP_DEBUG', true );
// Force display of errors and warnings
define( "WP_DEBUG_DISPLAY", true );
@ini_set( "display_errors", 1 );
// Enable Save Queries
define( "SAVEQUERIES", true );
// Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
define( "SCRIPT_DEBUG", true ); ```

- Add wp-cli.yml config.
- Add rewrite structure.
- Update Update WordPress options.
- Generate htaccess.
- Delete Hello plugin.


## Run the script

`chmod +x wpinstall.sh`

in .bashrc: `alias wpinstall='bash SCRIPT_PATH'`

Run with `wpinstall`
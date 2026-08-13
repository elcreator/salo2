# Salo runtimes

Each directory here is a container recipe for running Evolution CMS. They are
selected by directory name — `salo install --runtime=8.4-nginx` — and are also
what `.github/workflows/build.yml` in the `evolution` repository builds its
published images from.

## Available runtimes

| Runtime | Base | Web server | PHP SAPI |
| --- | --- | --- | --- |
| `8.2`, `8.3`, `8.4`, `8.5` | `php:X-apache` | Apache | mod_php |
| `8.4-xdebug`, `8.5-xdebug` | `php:X-apache` | Apache | mod_php + Xdebug |
| `8.3-nginx`, `8.4-nginx`, `8.5-nginx` | `php:X-fpm` | nginx | php-fpm (FastCGI) |
| `8.3-frankenphp`, `8.4-frankenphp`, `8.5-frankenphp` | `dunglas/frankenphp:phpX` | Caddy | embedded (libphp) |

These are three genuinely different PHP SAPIs, not three front ends over one
PHP — which is why they cannot share a base image and why each is built
separately. The document root is `/var/www/html` in all of them.

Every runtime carries `gd`, `zip`, `mysqli`, `pdo`, `pdo_mysql`, `pdo_pgsql`,
`pgsql`, plus `sqlite3`/`pdo_sqlite` from the upstream PHP image, and composer.

## Tuning php.ini

The runtime's own settings live in `/usr/local/etc/php/conf.d/40-custom.ini`.
PHP loads that directory in alphabetical order, so mount a file with a higher
prefix and it wins:

```sh
docker run -v ./php-local.ini:/usr/local/etc/php/conf.d/99-local.ini:ro ...
```

```ini
; php-local.ini
memory_limit = 512M
upload_max_filesize = 256M
post_max_size = 256M
display_errors = On
```

The path is the same for all three web servers. PHP reads ini files at startup
in every SAPI here, so restart the container after changing one.

## Tuning the web server

| Runtime | What to mount | Notes |
| --- | --- | --- |
| apache | `/etc/apache2/conf-enabled/zz-local.conf` | `.htaccess` in the document root also applies, and is where the CMS ships its rules |
| nginx | `/etc/nginx/conf.d/evolution.conf` | Replaces the whole `server` block; start from the file in `8.4-nginx/nginx.conf` |
| frankenphp | `/etc/frankenphp/Caddyfile` | Replaces the whole config; start from `8.4-frankenphp/Caddyfile` |

For nginx, adding a *second* file to `conf.d` rather than replacing
`evolution.conf` will fail to start if it declares another `default_server` on
port 80 — nginx rejects two defaults on one address.

```sh
docker run -v ./Caddyfile:/etc/frankenphp/Caddyfile:ro ...
```

## Connecting a database

Evolution's generated `core/config/database/connections/default.php` reads
everything from the environment, so no file has to be edited:

| Variable | Meaning | Default |
| --- | --- | --- |
| `DB_TYPE` | `sqlite`, `mysql` or `pgsql` | `sqlite` |
| `DB_HOST` | server host name | empty |
| `DB_PORT` | server port | empty |
| `DB_DATABASE` | database name, or the file path for sqlite | the bundled sqlite file |
| `DB_USERNAME` / `DB_PASSWORD` | credentials | empty |
| `DB_PREFIX` | table prefix | `evo_` |
| `DB_CHARSET` / `DB_COLLATION` | connection charset | empty |
| `DB_SOCKET` | unix socket instead of host/port | empty |

Note it is `DB_TYPE`, not Laravel's usual `DB_CONNECTION`.

These reach PHP in all three runtimes — `variables_order = EGPCS` in
`40-custom.ini` is what puts them in `$_ENV` as well as `getenv()`, so do not
drop it from a custom ini file.

### A database container

```sh
docker network create evo
docker run -d --name pg --network evo \
    -e POSTGRES_USER=evo -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=evolution postgres:16

docker run -d --network evo -p 8080:80 \
    -e DB_TYPE=pgsql -e DB_HOST=pg -e DB_PORT=5432 \
    -e DB_DATABASE=evolution -e DB_USERNAME=evo -e DB_PASSWORD=secret \
    ghcr.io/evolution-cms/evolution:3.5.x
```

Swap `pgsql`/`5432` for `mysql`/`3306` against a MySQL or MariaDB container.

### A standalone server on the host

Containers cannot reach the host as `localhost`. Use `host.docker.internal`,
which Docker Desktop provides automatically and Linux needs told about:

```sh
docker run -d -p 8080:80 \
    --add-host=host.docker.internal:host-gateway \
    -e DB_TYPE=mysql -e DB_HOST=host.docker.internal -e DB_PORT=3306 \
    -e DB_DATABASE=evolution -e DB_USERNAME=evo -e DB_PASSWORD=secret \
    ghcr.io/evolution-cms/evolution:3.5.x
```

The server also has to listen on more than the loopback interface and grant the
account access from the container's subnet, which is the usual reason this
fails with "host is not allowed to connect".

### Your own sqlite file

Point `DB_DATABASE` at a path you mount. Mount the *directory*, not the bare
file: sqlite writes `-wal` and `-journal` siblings next to the database.

```sh
docker run -d -p 8080:80 \
    -e DB_DATABASE=/dbdata/mysite.sqlite \
    -v ./dbdata:/dbdata \
    ghcr.io/evolution-cms/evolution:3.5.x
```

**The file must be writable by uid 33 (`www-data`), or the CMS comes up
read-only** and any save fails with "attempt to write a readonly database".
On Linux, `chown 33:33 dbdata/mysite.sqlite`. On Docker Desktop for Windows and
macOS, bind-mounted files are owned by root regardless of what you set, so seed
a named volume instead:

```sh
docker volume create evo-db
docker run --rm -v ./dbdata:/seed:ro -v evo-db:/dbdata alpine \
    sh -c 'cp /seed/mysite.sqlite /dbdata/ && chown -R 33:33 /dbdata'

docker run -d -p 8080:80 -e DB_DATABASE=/dbdata/mysite.sqlite -v evo-db:/dbdata \
    ghcr.io/evolution-cms/evolution:3.5.x
```

The prefix of the tables in your file has to match `DB_PREFIX`.

## Xdebug

The `-xdebug` runtimes listen for a debugger on port 9003 and are configured
with `xdebug.start_with_request = trigger`, so PHP only tries to reach an IDE
when the request asks for it (`XDEBUG_TRIGGER` in the query string, a cookie, or
the browser extension). That keeps the image usable as a normal runtime when
nothing is listening. Their `ports` file publishes 9003 alongside 80.

Override `xdebug.client_host` if your IDE is not on `host.docker.internal`.

#!/bin/sh
set -eu

copy_defaults_if_empty() {
    source_dir="$1"
    target_dir="$2"

    mkdir -p "$target_dir"
    if [ -z "$(find "$target_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
        cp -a "$source_dir"/. "$target_dir"/
    fi
}

copy_defaults_if_empty /opt/mcskin-data/storage /var/www/html/storage
copy_defaults_if_empty /opt/mcskin-data/plugins /var/www/html/plugins
copy_defaults_if_empty /opt/mcskin-data/public-plugins /var/www/html/public/plugins
copy_defaults_if_empty /opt/mcskin-data/public-lang /var/www/html/public/lang

mkdir -p \
    /var/www/html/bootstrap/cache \
    /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs

if [ "${APP_INSTALLED:-true}" = "true" ]; then
    touch /var/www/html/storage/install.lock
fi

if [ "$(id -u)" = "0" ]; then
    chown -R www-data:www-data \
        /var/www/html/bootstrap/cache \
        /var/www/html/plugins \
        /var/www/html/public/lang \
        /var/www/html/public/plugins \
        /var/www/html/storage
fi

if [ "${CONTAINER_RUN_MIGRATIONS:-false}" = "true" ]; then
    su -s /bin/sh www-data -c "php artisan migrate --force"
fi

if [ "${1:-}" = "nginx" ]; then
    php-fpm -D
fi

exec "$@"

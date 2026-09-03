FROM node:20-bookworm-slim AS frontend

WORKDIR /src
RUN corepack enable && corepack prepare yarn@1.22.22 --activate

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --non-interactive

COPY . .
RUN yarn build


FROM php:8.1-fpm-bookworm AS app

ARG REDIS_EXTENSION_VERSION=6.0.2
ARG IMAGICK_EXTENSION_VERSION=3.7.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libmagickwand-dev \
        libonig-dev \
        libpng-dev \
        libpq-dev \
        libxml2-dev \
        libzip-dev \
        unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        gd \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_pgsql \
        soap \
        sockets \
        zip \
    && pecl install "redis-${REDIS_EXTENSION_VERSION}" "imagick-${IMAGICK_EXTENSION_VERSION}" \
    && docker-php-ext-enable redis imagick \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2.8 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --no-scripts \
    --optimize-autoloader \
    --prefer-dist

COPY . .
COPY --from=frontend /src/public ./public
COPY --from=frontend /src/resources/views/assets ./resources/views/assets
COPY docker/php.ini /usr/local/etc/php/conf.d/99-mcskin.ini
COPY docker/entrypoint.sh /usr/local/bin/mcskin-entrypoint

RUN mkdir -p \
        bootstrap/cache \
        public/lang \
        public/plugins \
        storage/app/public \
        storage/debugbar \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/views \
        storage/logs \
        storage/packages \
    && cp .env.example .env \
    && php artisan package:discover --ansi \
    && rm .env \
    && mkdir -p /opt/mcskin-data \
    && cp -a storage /opt/mcskin-data/storage \
    && cp -a plugins /opt/mcskin-data/plugins \
    && cp -a public/plugins /opt/mcskin-data/public-plugins \
    && cp -a public/lang /opt/mcskin-data/public-lang \
    && chown -R www-data:www-data \
        /var/www/html/bootstrap/cache \
        /var/www/html/plugins \
        /var/www/html/public \
        /var/www/html/storage \
        /opt/mcskin-data \
    && chmod +x /usr/local/bin/mcskin-entrypoint

ENTRYPOINT ["mcskin-entrypoint"]
CMD ["php-fpm", "-F"]


FROM app AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default \
    && sed -i 's#^pid .*#pid /tmp/nginx.pid;#' /etc/nginx/nginx.conf \
    && mkdir -p /run/nginx /var/lib/nginx /var/log/nginx \
    && chown -R www-data:www-data /run/nginx /var/lib/nginx /var/log/nginx

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]

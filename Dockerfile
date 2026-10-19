# SLiMS 9 Bulian, built from the official v9.8.0 source.
ARG SLIMS_REF=v9.8.0
FROM alpine:3.22 AS slims-source
ARG SLIMS_REF
RUN apk add --no-cache git
RUN git clone --depth 1 --branch "${SLIMS_REF}" \
    https://github.com/slims/slims9_bulian.git /src

FROM php:8.3-fpm-bookworm

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      libicu-dev \
      libxml2-dev \
      libzip-dev \
      libpng-dev \
      libonig-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      default-mysql-client \
      nginx \
      ca-certificates \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
      intl xml xmlwriter gettext mbstring zip mysqli pdo_mysql iconv gd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY --from=slims-source /src/ /var/www/html/

WORKDIR /var/www/html

RUN test -f /var/www/html/install/senayan.sql \
    && mkdir -p /opt/slims-init \
    && cp /var/www/html/install/senayan.sql /opt/slims-init/senayan.sql \
    && composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader \
    && rm -rf /var/www/html/install /var/www/html/.git /var/www/html/.github \
       /var/www/html/Dockerfile /var/www/html/docker-compose.yml \
       /var/www/html/entrypoint.sh /var/www/html/.dockerignore \
       /var/www/html/.env.example /var/www/html/composer.json /var/www/html/composer.lock \
    && mkdir -p /var/www/html/files /var/www/html/images /var/www/html/repository \
    && chown -R www-data:www-data /var/www/html/files /var/www/html/images /var/www/html/repository \
    && chmod 0755 /var/www/html/files /var/www/html/images /var/www/html/repository

COPY nginx/slims.conf /etc/nginx/sites-available/slims.conf
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/entrypoint.sh /usr/local/bin/slims-entrypoint.sh
COPY docker/db-init.sh /usr/local/bin/slims-db-init.sh
COPY docker/render-config.php /usr/local/bin/slims-render-config.php

RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/slims.conf /etc/nginx/sites-enabled/slims.conf \
    && mkdir -p /run/nginx /var/log/nginx \
    && chown -R www-data:www-data /var/www/html/files /var/www/html/images /var/www/html/repository \
    && chmod 0755 /usr/local/bin/slims-entrypoint.sh /usr/local/bin/slims-db-init.sh \
    && chmod 0644 /usr/local/bin/slims-render-config.php

EXPOSE 80
ENTRYPOINT ["/usr/local/bin/slims-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]

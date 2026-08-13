# FrankenPHP: Caddy with PHP embedded as a library, so there is no separate web
# server process and no FastCGI hop. It cannot be layered onto the php: images
# the other runtimes use — it links against its own libphp build — which is why
# this runtime starts from the upstream image instead.
FROM dunglas/frankenphp:php8.4

# The FrankenPHP images ship mlocati's install-php-extensions, which builds the
# same extension set the apache/nginx runtimes get from docker-php-ext-install.
RUN install-php-extensions \
        gd \
        zip \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        mysqli

# The upstream image has no composer, and pulling it from a bin image avoids
# depending on which php CLI entry point FrankenPHP exposes.
COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer

RUN apt-get update && apt-get install -y \
        git \
        tree \
        vim \
        wget \
        subversion \
        unzip \
    && rm -rf /var/lib/apt/lists/*

ADD php.ini /usr/local/etc/php/conf.d/40-custom.ini
ADD Caddyfile /etc/frankenphp/Caddyfile

EXPOSE 80

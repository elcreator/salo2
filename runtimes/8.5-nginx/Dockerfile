# nginx + php-fpm. The apache runtimes next to this one use mod_php, where PHP
# runs inside the web server process; here PHP is a separate FastCGI pool, which
# is the other half of what Evolution CMS is deployed on in the wild.
FROM php:8.5-fpm
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        libpq-dev \
        unzip \
        nginx \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd

#RUN apt-get update && apt-get install -y \
#    imagemagick libmagickwand-dev --no-install-recommends \
#    && pecl install imagick \
#    && docker-php-ext-enable imagick

RUN docker-php-ext-install mysqli pdo pdo_mysql pdo_pgsql pgsql zip

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN apt-get install -y \
        git \
        tree \
        vim \
        wget \
        subversion

ADD php.ini /usr/local/etc/php/conf.d/40-custom.ini

# Debian ships a default site that also claims port 80; two default servers on
# one port is a startup error, so the packaged one goes away.
RUN rm -f /etc/nginx/sites-enabled/default
ADD nginx.conf /etc/nginx/conf.d/evolution.conf
ADD entrypoint.sh /usr/local/bin/salo-entrypoint
RUN chmod +x /usr/local/bin/salo-entrypoint

EXPOSE 80
CMD ["salo-entrypoint"]

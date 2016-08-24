FROM debian:jessie
MAINTAINER Lubert Palacios <trepafi@gmail.com>

# System config
RUN apt-get update && \
    apt-get install -y php5 php5-common php5-cli \
                       php5-fpm php5-mcrypt php5-mysql php5-apcu \
                       php5-gd php5-imagick php5-curl php5-intl

# PHP config
ADD ./symfony-app.ini        /etc/php5/fpm/conf.d/
ADD ./symfony-app.ini        /etc/php5/cli/conf.d/
ADD ./symfony-app.pool.conf  /etc/php5/fpm/pool.d/

# Starting PHP service
RUN usermod -u 1000 www-data
CMD ["php5-fpm", "-F"]

# Symfony app code
ENV wdir /usr/share/nginx/html/devadictos-app
ADD ./devadictos-app $wdir
WORKDIR $wdir

# Symfony tasks
RUN php bin/console assets:install
RUN mkdir -p var/cache && chmod -R 777 var/cache
RUN mkdir -p var/logs && chmod -R 777 var/logs
RUN mkdir -p var/sessions && chmod -R 777 var/sessions
#CMD ["php", "bin/console", "server:run"]

# Defining volume
VOLUME $wdir

# Exposing ports
EXPOSE 9000

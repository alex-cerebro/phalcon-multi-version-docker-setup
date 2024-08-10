#!/bin/bash

set -e

# Function to install Docker Compose
install_docker_compose() {
  if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose no encontrado, instalando..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose instalado correctamente."
  else
    echo "Docker Compose ya está instalado."
  fi
}

# Function to install a specific version of Phalcon
install_phalcon_version() {
  version=$1
  php_version=$2
  devtools_branch=$3

  mkdir -p phalcon/${version}/app/config
  mkdir -p phalcon/${version}/app/controllers
  mkdir -p phalcon/${version}/app/models
  mkdir -p phalcon/${version}/app/views
  mkdir -p phalcon/${version}/public

  # Create Dockerfile
  cat > phalcon/${version}/Dockerfile <<EOF
FROM php:${php_version}-apache

# Install dependencies and Phalcon
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpcre3-dev \
    gcc \
    make \
    re2c \
    libpq-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libzip-dev \
    curl

EOF

  if [ "${php_version}" == "7.2" ]; then
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j\$(nproc) gd mbstring zip \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql
EOF
  else
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j\$(nproc) gd mbstring zip \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql
RUN pecl install psr \
    && docker-php-ext-enable psr
EOF
  fi

  cat >> phalcon/${version}/Dockerfile <<EOF

RUN git clone --branch ${version}.x --depth=1 https://github.com/phalcon/cphalcon.git /tmp/cphalcon \
    && cd /tmp/cphalcon/build \
    && ./install \
    && docker-php-ext-enable phalcon

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Create composer.json for Phalcon DevTools
RUN mkdir -p /root/.composer && \
    echo '{"require": {"phalcon/devtools": "${devtools_branch}"}, "minimum-stability": "dev", "prefer-stable": true}' > /root/.composer/composer.json

# Install Phalcon DevTools
RUN COMPOSER_ALLOW_SUPERUSER=1 composer global install --no-interaction --prefer-dist
RUN ln -s /root/.composer/vendor/bin/phalcon /usr/bin/phalcon && chmod +x /usr/bin/phalcon

RUN a2enmod rewrite
RUN sed -i '/<Directory \\/var\\/www\\/>/,/<\\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Install and configure Xdebug
EOF

  if [ "$php_version" == "7.2" ]; then
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN pecl install xdebug-2.9.8 \
    && docker-php-ext-enable xdebug
EOF
  elif [ "$php_version" == "7.4" ]; then
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN pecl install xdebug-2.9.8 \
    && docker-php-ext-enable xdebug
EOF
  else
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug
EOF
  fi

  cat >> phalcon/${version}/Dockerfile <<EOF

# Xdebug configuration for local debugging
RUN echo "zend_extension=xdebug.so" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_host=172.17.0.1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.log=/var/log/xdebug.log" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install and configure Sockets
RUN docker-php-ext-install sockets

WORKDIR /var/www/html
EOF
}

# Ask the user which Phalcon versions to install
echo "Which Phalcon versions do you want to install?"
echo "1) Phalcon 3.4"
echo "2) Phalcon 4"
echo "3) Phalcon 5"
echo "4) All"
read -p "Please choose an option (1-4): " choice

# Process the user's choice
versions_to_install=()
php_versions=()
devtools_branches=()
ports=()
case $choice in
  1)
    versions_to_install=("3.4")
    php_versions=("7.2")
    devtools_branches=("3.4.x")
    ports=("8081")
    ;;
  2)
    versions_to_install=("4.0")
    php_versions=("7.4")
    devtools_branches=("4.0.x")
    ports=("8082")
    ;;
  3)
    versions_to_install=("5.0")
    php_versions=("8.0")
    devtools_branches=("5.0.x")
    ports=("8083")
    ;;
  4)
    versions_to_install=("3.4" "4.0" "5.0")
    php_versions=("7.2" "7.4" "8.0")
    devtools_branches=("3.4.x" "4.0.x" "5.0.x")
    ports=("8081" "8082" "8083")
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac

# Update the system and install Docker, Apache2, and PHP
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common apache2 php libapache2-mod-php php-curl

# Install Docker Compose if not installed
install_docker_compose

# Add the GPG key for Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add the Docker repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce

# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Create directories for Dockerfiles and applications
for i in "${!versions_to_install[@]}"; do
  install_phalcon_version "${versions_to_install[$i]}" "${php_versions[$i]}" "${devtools_branches[$i]}"
done

# Create a docker-compose.yml file
cat > docker-compose.yml <<EOF
version: '3.7'

services:
EOF

for i in "${!versions_to_install[@]}"; do
  version=${versions_to_install[$i]}
  php_version=${php_versions[$i]}
  port=${ports[$i]}
  container_name="phalcon${version//./}"
  cat >> docker-compose.yml <<EOF
  ${container_name}:
    build:
      context: ./phalcon/${version}
    container_name: ${container_name}
    volumes:
      - ./phalcon/${version}:/var/www/html
    ports:
      - "${port}:80"
    environment:
      - PHALCON_VERSION=${version}
EOF
done

# Remove existing containers
for version in "${versions_to_install[@]}"; do
  container_name="phalcon${version//./}"
  if sudo docker ps -a --format '{{.Names}}' | grep -Eq "^${container_name}$"; then
    sudo docker rm -f ${container_name}
  fi
done

# Free up ports if they are in use
for port in "${ports[@]}"; do
  sudo lsof -t -i :${port} | xargs -r sudo kill
done

# Build and start the containers
sudo docker-compose up -d --build

# Verify the containers are running and print URLs
for i in "${!versions_to_install[@]}"; do
  version=${versions_to_install[$i]}
  container_name="phalcon${version//./}"
  port=${ports[$i]}
  if [ "$(sudo docker inspect -f '{{.State.Running}}' $container_name)" == "true" ]; then
    echo "The container $container_name is running correctly. Access it at http://localhost:${port}"
  else
    echo "There was a problem starting the container $container_name."
  fi
done

# Enable and start Apache2
sudo systemctl enable apache2
sudo systemctl start apache2

echo "Installation and configuration completed. Access the applications on the respective ports:"
for i in "${!versions_to_install[@]}"; do
  port=${ports[$i]}
  echo "Phalcon ${versions_to_install[$i]}: http://localhost:${port}"
done

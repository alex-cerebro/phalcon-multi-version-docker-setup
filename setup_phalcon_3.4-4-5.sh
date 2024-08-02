#!/bin/bash

set -e

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
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j\$(nproc) gd mbstring zip \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql

RUN git clone --branch ${version}.x --depth=1 https://github.com/phalcon/cphalcon.git /tmp/cphalcon \\
    && cd /tmp/cphalcon/build \\
    && ./install \\
    && docker-php-ext-enable phalcon

# Install Phalcon DevTools
RUN git clone https://github.com/phalcon/phalcon-devtools.git /usr/local/phalcon-devtools \\
    && cd /usr/local/phalcon-devtools \\
    && git checkout ${devtools_branch}

RUN ln -s /usr/local/phalcon-devtools/phalcon /usr/bin/phalcon \\
    && chmod +x /usr/bin/phalcon

RUN a2enmod rewrite
RUN sed -i '/<Directory \\/var\\/www\\/>/,/<\\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Install and configure Xdebug for PHP 7.2
EOF

  if [ "$php_version" == "7.2" ]; then
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN pecl install xdebug-2.9.8 \\
    && docker-php-ext-enable xdebug
EOF
  else
    cat >> phalcon/${version}/Dockerfile <<EOF
RUN pecl install xdebug \\
    && docker-php-ext-enable xdebug
EOF
  fi

  cat >> phalcon/${version}/Dockerfile <<EOF

# Xdebug configuration for local debugging
RUN echo "zend_extension=xdebug.so" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_enable=1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_host=172.17.0.1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_autostart=1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_mode=req" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.remote_connect_back=0" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.client_host=172.17.0.1" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \\
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
case $choice in
  1)
    versions_to_install=("3.4")
    php_versions=("7.2")
    devtools_branches=("3.4.x")
    ;;
  2)
    versions_to_install=("4.0")
    php_versions=("7.4")
    devtools_branches=("4.0.x")
    ;;
  3)
    versions_to_install=("5.0")
    php_versions=("8.0")
    devtools_branches=("5.0.x")
    ;;
  4)
    versions_to_install=("3.4" "4.0" "5.0")
    php_versions=("7.2" "7.4" "8.0")
    devtools_branches=("3.4.x" "4.0.x" "5.0.x")
    ;;
  *)
    echo "Invalid option. Exiting."
    exit 1
    ;;
esac

# Update the system and install Docker, Apache2, and PHP
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common apache2 php libapache2-mod-php php-curl

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
  port=$((8081 + $i))
  cat >> docker-compose.yml <<EOF
  phalcon${version//./}:
    build:
      context: ./phalcon/${version}
    container_name: phalcon${version}
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
  sudo docker rm -f phalcon${version} || true
done

# Free up ports if they are in use
for i in "${!versions_to_install[@]}"; do
  port=$((8081 + i))
  sudo lsof -t -i :${port} | xargs -r sudo kill
done

# Build and start the containers
sudo docker-compose up -d --build

# Verify the containers are running
for version in "${versions_to_install[@]}"; do
  container="phalcon${version}"
  if [ "$(sudo docker inspect -f '{{.State.Running}}' $container)" == "true" ]; then
    echo "The container $container is running correctly."
  else
    echo "There was a problem starting the container $container."
  fi
done

# Enable and start Apache2
sudo systemctl enable apache2
sudo systemctl start apache2

# Install Phalcon DevTools globally
composer global require phalcon/devtools

echo "Installation and configuration completed. Access the applications on the respective ports."

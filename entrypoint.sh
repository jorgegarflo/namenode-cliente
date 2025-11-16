#!/bin/bash

# Crear directorios necesarios de mysql
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

# Inicializar data directory si no existe
if [ ! -d /var/lib/mysql/mysql ]; then
   mysql_install_db --user=mysql >/dev/null
fi

# Arrancar MariaDB en segundo plano
mysqld --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
MYSQL_PID=$!

# Esperar a mysql
sleep 10

# Crear usuario hive si no existe
mysql --socket=/run/mysqld/mysqld.sock -u root <<EOF
CREATE USER IF NOT EXISTS 'hive'@'localhost' IDENTIFIED BY 'ubigdata';
GRANT ALL PRIVILEGES ON *.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
EOF

# Inicializar schema si no existe
schematool -dbType mysql -initSchema || true

# Ahora continuar con el proceso final
exec "$@"

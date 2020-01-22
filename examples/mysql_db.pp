$packages = ['mysql-common','mysql-server']
package {$packages:
  ensure => installed
}

$my_cnf_contents = "[mysqld]
!includedir /etc/mysql/mariadb.conf.d/
!includedir /etc/mysql/conf.d/
innodb_buffer_pool_size=7GB
innodb_log_file_size=256M
key_buffer_size=5GB
log_error=/var/log/mysql/error.log"

file {'/etc/mysql/my.cnf':
  ensure  => 'file',
  content => $my_cnf_contents,
  require => [Package['mysql-server'], Package['mysql-common']]
}

exec {'Initialize MySQL DB':
  command => 'sudo mysqld --initialize',
  path    => '/bin:/usr/bin',
  require => [Package['mysql-server'], Package['mysql-common']]
}

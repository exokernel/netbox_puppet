class netbox::postgres {

    $primary_ip = $netbox::hiera['postgres']['primary_ip']
    $pg_version = $netbox::hiera['postgres']['version']
    $backup_path = $netbox::hiera['backup_path']

    service { 'postgresql':
        ensure  => 'running',
        enable  => true,
        require => Package['postgresql'],
    }

    file { '/root/symlink_postgres.sh':
       ensure => present,
       owner => 'root',
       group => 'root',
       mode => '0750',
       source  => 'puppet:///modules/netbox/root/symlink_postgres.sh',
       require => Package['postgresql'], 
    }

    # keep puppet paths independent of the postgres version. since postgres datadir defaults to /var/lib/postgresql/$pg_version/main
    # and the config dir defaults to /etc/postgresql/$pg_version/main. this script makes symlinks /data/postgresql -> $datadir
    # and /etc/postgresql/current -> $configdir
    exec { 'symlink_postgres':
        command => "bash /root/symlink_postgres.sh",
        creates  => '/data/postgresql',
        require => File['/root/symlink_postgres.sh'],
    }

    file { '/etc/postgresql/current/postgresql.conf':
        ensure  => present,
        owner   => 'postgres',
        group   => 'postgres',
        mode    => '0644',
        content => template('netbox/etc/postgresql/current/postgresql.conf.erb'),
        require => Exec['symlink_postgres'],
        notify  => Service['postgresql'],
    }

    file { '/etc/postgresql/current/pg_hba.conf':
        ensure  => present,
        owner   => 'postgres',
        group   => 'postgres',
        mode    => '0644',
        content => template('netbox/etc/postgresql/current/pg_hba.conf.erb'),
        require => Exec['symlink_postgres'],
        notify  => Service['postgresql'],
    }

    file { '/root/.pgpass':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0600',
        source  => 'puppet:///modules/netbox/root/pgpass',
    }

    if $netbox::backup_host {
        file { '/data/postgresql/recovery.conf':
            ensure  => present,
            owner   => 'postgres',
            group   => 'postgres',
            mode    => '0640',
            content => template('netbox/data/postgresql/recovery.conf.erb'),
            require => Exec['symlink_postgres'],
            notify  => Service['postgresql'],
        }

        file { '/var/adm/scripts/netbox-postgres-backup.sh':
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0740',
            content => template('netbox/var/adm/scripts/netbox-postgres-backup.sh.erb'),
            require => [ Package['postgresql'], File['/data/netbox-backups/postgres'] ],
        }

        file { '/etc/cron.d/netbox-postgres-backup':
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/netbox/etc/cron.d/netbox-postgres-backup',
            require => File['/var/adm/scripts/netbox-postgres-backup.sh'],
        }
    }
}

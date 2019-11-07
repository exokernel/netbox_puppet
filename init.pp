class netbox {

    $hiera = lookup('netbox', $::lookup_opts)

    $netbox_port            = $hiera['netbox_port']
    $netbox_workers         = $hiera['netbox_workers']
    $nbcat_port             = $hiera['nbcat_port']
    $nbcat_workers          = $hiera['nbcat_workers']
    $server_name            = $hiera['server_name']
    $realsecure_server_name = $hiera['realsecure_server_name']
    $backup_path            = $hiera['backup_path']
    $test_host              = $hiera['test_host']
    $backup_host            = $hiera['backup_host']

    include netbox::postgres

    if $backup_host {
        file { '/root/.ssh/remotesync':
            ensure => file,
            owner  => 'root',
            group  => 'root',
            mode   => '0600',
            source => 'puppet:///modules/netbox/root/ssh/remotesync',
        }

        file { '/data/netbox-backups':
            ensure  => directory,
            owner   => 'root',
            group   => 'dr',
            mode    => '0750',
            require => File['/data'],
        }

        file { '/data/netbox-backups/media':
            ensure  => directory,
            owner   => 'root',
            group   => 'dr',
            mode    => '0750',
            require => File['/data/netbox-backups'],
        }

        file { '/data/netbox-backups/postgres':
            ensure  => directory,
            owner   => 'root',
            group   => 'dr',
            mode    => '0750',
            require => File['/data/netbox-backups'],
        }

        file { '/var/adm/scripts/netbox-media-backup.sh':
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => template('netbox/var/adm/scripts/netbox-media-backup.sh.erb'),
            require => File['/opt/netbox-media'],
        }

        file { '/etc/cron.d/netbox-media-backup':
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/netbox/etc/cron.d/netbox-media-backup',
            require => File['/var/adm/scripts/netbox-media-backup.sh'],
        }
    }

    file { '/opt/netbox':
        ensure  => link,
        owner   => 'root',
        group   => 'www-data',
        target  => '/opt/netbox-package',
        require => Package['netbox-package'],
    }

    file { '/opt/netbox/gunicorn_netbox_config.py':
        ensure  => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        content => template('netbox/opt/netbox/gunicorn_netbox_config.py.erb'),
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/gunicorn_nbcat_config.py':
        ensure  => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        content => template('netbox/opt/netbox/gunicorn_nbcat_config.py.erb'),
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/nbcat.py':
        ensure  => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        source  => 'puppet:///modules/netbox/opt/netbox/nbcat.py',
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/netbox/netbox/configuration.py':
        ensure => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        content  => template('netbox/opt/netbox/netbox/netbox/configuration.py.erb'),
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/netbox/netbox/settings.py':
        ensure => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        source  => 'puppet:///modules/netbox/opt/netbox/netbox/netbox/settings.py',
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/netbox/utilities/custom_middleware.py':
        ensure => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        source  => 'puppet:///modules/netbox/opt/netbox/netbox/utilities/custom_middleware.py',
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/netbox/utilities/custom_backends.py':
        ensure => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0640',
        source  => 'puppet:///modules/netbox/opt/netbox/netbox/utilities/custom_backends.py',
        require => File['/opt/netbox'],
    }

    file { '/etc/supervisor/conf.d/netbox.conf':
        ensure => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/netbox/etc/supervisor/conf.d/netbox.conf',
        require => [ Package['supervisor'], File['/opt/netbox'] ],
    }

    exec { 'netbox_requirements_install':
        command => 'pip3 install -r /opt/netbox/requirements.txt && touch /opt/netbox/netbox_requirements_installed',
        unless  => 'test -f /opt/netbox/netbox_requirements_installed',
        require => [ Package['python3-pip'], File['/opt/netbox'] ],
    }

    exec { 'netbox_static_files_install':
        command => 'python3 manage.py collectstatic --no-input',
        cwd     => '/opt/netbox/netbox',
        unless  => 'test -d /opt/netbox/netbox/static',
        require => File['/opt/netbox'],
    }

    file { '/opt/netbox/netbox/static/img/netbox_logo.png':
        ensure => present,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0644',
        source  => 'puppet:///modules/netbox/opt/netbox/netbox/static/img/netbox_logo.png',
        require => [ Exec['netbox_static_files_install'], File['/opt/netbox'] ],
    }

    exec { 'gunicorn_install':
        command => 'pip3 install gunicorn',
        unless  => 'test -f /usr/local/bin/gunicorn',
        require => Package['python3-pip'],
    }

    file { '/opt/netbox-reports':
        ensure  => directory,
        recurse => true,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0750',
        source  => 'puppet:///modules/netbox/opt/netbox-reports',
    }

    file { '/opt/netbox-media':
        ensure => directory,
        owner   => 'root',
        group   => 'www-data',
        mode    => '0770',
    }

    file { '/var/adm/scripts/ganeti-netbox-updater.py':
        ensure => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content  => template('netbox/var/adm/scripts/ganeti-netbox-updater.py.erb'),
        require => File['/opt/netbox'],
    }

    file { '/var/adm/scripts/ganeti-netbox-vm-cleaner.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('netbox/var/adm/scripts/ganeti-netbox-vm-cleaner.py.erb'),
        require => File['/opt/netbox'],
    }

    file { '/var/adm/scripts/inv-idle-report.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('netbox/var/adm/scripts/inv-idle-report.py.erb'),
    }

    file { '/var/adm/scripts/owner-reports.py':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('netbox/var/adm/scripts/owner-reports.py.erb'),
    }

    file { '/var/adm/scripts/inv-no-tags-report.sh':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0750',
        content => template('netbox/var/adm/scripts/inv-no-tags-report.sh.erb'),
    }

    # only the production node currently serving netbox gets these crons
    unless $test_host or $backup_host {
        file { '/etc/cron.d/ganeti-updater':
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            source  => 'puppet:///modules/netbox/etc/cron.d/ganeti-updater',
            require => [ File['/var/adm/scripts/ganeti-netbox-updater.py'],
                         File['/var/adm/scripts/ganeti-netbox-vm-cleaner.py'] ],
        }

        file { '/etc/cron.d/inventory-reports':
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            source  => 'puppet:///modules/netbox/etc/cron.d/inventory-reports',
            require => File['/var/adm/scripts/inv-idle-report.py'],
        }
    }
}

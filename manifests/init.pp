# @summary Install cultivator service
#
#
# @param integration_id sets the GitHub app ID
# @param version sets the release tag to use
# @param dir sets the root storage directory
# @param check_repo sets the path for the check repo
# @param bootdelay sets how long to wait before first run
# @param frequency sets how often to run updates
class cultivator (
  String $integration_id,
  String $version = 'v0.0.1',
  String $dir = '/var/lib/cultivator',
  String $check_repo = 'https://github.com/akerl/repo-checks',
  String $bootdelay = '300',
  String $frequency = '3600'
) {
  $cache_dir = "${dir}/cache"
  $check_dir = "${dir}/checks"
  $private_key_file = "${dir}/key.pem"

  $arch = $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'arm64'   => 'arm64',
    'aarch64' => 'arm64',
    'arm'     => 'arm',
    default   => 'error',
  }

  $binfile = '/usr/local/bin/cultivator'
  $filename = "cultivator_${downcase($facts['kernel'])}_${arch}"
  $url = "https://github.com/akerl/cultivator/releases/download/${version}/${filename}"

  group { 'cultivator':
    ensure => present,
    system => true,
  }

  user { 'cultivator':
    ensure => present,
    system => true,
    gid    => 'cultivator',
    shell  => '/usr/bin/nologin',
    home   => $dir,
  }

  exec { 'download cultivator':
    command => "/usr/bin/curl -sLo '${binfile}' '${url}' && chmod a+x '${binfile}'",
    unless  => "/usr/bin/test -f ${binfile} && ${binfile} version | grep '${version}'",
  }

  file { [$dir, $check_dir]:
    ensure => directory,
    owner  => 'root',
    group  => 'cultivator',
    mode   => '0750',
  }

  file { $cache_dir:
    ensure => directory,
    owner  => 'cultivator',
    group  => 'cultivator',
    mode   => '0750',
  }

  file { "${dir}/config.yaml":
    ensure  => file,
    mode    => '0640',
    owner   => 'root',
    group   => 'cultivator',
    content => template('cultivator/config.yaml.erb'),
  }

  vcsrepo { $check_dir:
    ensure   => latest,
    provider => git,
    source   => $check_repo,
  }

  file { '/etc/systemd/system/cultivator.service':
    ensure => file,
    source => 'puppet:///modules/cultivator/cultivator.service',
  }

  file { '/etc/systemd/system/cultivator.timer':
    ensure  => file,
    content => template('cultivator/cultivator.timer.erb'),
  }

  ~> service { 'cultivator.timer':
    ensure  => running,
    enable  => true,
    require => File['/var/lib/cultivator/config.yaml'],
  }
}

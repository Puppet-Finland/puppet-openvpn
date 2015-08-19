#
# == Define: openvpn::config::client::inline
#
# Configuration specific for OpenVPN clients that use inline configuration 
# files.
#
define openvpn::config::client::inline
(
    $enable_service,
    $tunif,
    $clientname
)
{
    include ::openvpn::params

    # Determine whether to use a configuration file tailored for this node, or 
    # for some other node. The latter is useful when a single configuration file 
    # will work on multiple clients (e.g. when using password authentication).
    if $clientname {
        $certname = $clientname
    } else {
        $certname = $::fqdn
    }

    # On systemd we don't have to play tricks with file extensions; instead we 
    # play tricks with links, because enabling individual OpenVPN connections 
    # using systemctl does not work due to systemd's internal limitations:
    #
    # <https://bugzilla.redhat.com/show_bug.cgi?id=746472>
    # <https://ask.fedoraproject.org/en/question/23085/how-to-start-openvpn-service-at-boot-time/>
    #
    if str2bool($::has_systemd) {

        # Add the configuration file
        file { "openvpn-${title}.conf":
            ensure  => present,
            name    => "${::openvpn::params::config_dir}/${title}.conf",
            source  => "puppet:///files/openvpn-${title}-${certname}.conf",
            owner   => $::os::params::adminuser,
            group   => $::os::params::admingroup,
            mode    => '0644',
            require => Class['openvpn::install'],
        }

        if $enable_service {
            file { "openvpn@${title}.service":
                ensure  => link,
                path    => "/etc/systemd/system/multi-user.target.wants/openvpn@${title}.service",
                target  => '/usr/lib/systemd/system/openvpn@.service',
                require => File["openvpn-${title}.conf"],
            }
        } else {
            file { "openvpn@${title}.service":
                ensure => absent,
                path   => "/etc/systemd/system/multi-user.target.wants/openvpn@${title}.service",
            }
        }

    # There is no common way to enable and disable individual VPN connections on 
    # non-systemd distros. This trickery is probably the best we can do without 
    # complexity going through the roof.
    } else {
        if $enable_service {
            $active_config = "${::openvpn::params::config_dir}/${title}.conf"
            $inactive_config = "${::openvpn::params::config_dir}/${title}.conf.disabled"
        } else {
            $active_config = "${::openvpn::params::config_dir}/${title}.conf.disabled"
            $inactive_config = "${::openvpn::params::config_dir}/${title}.conf"
        }

        # Add the active configuration file
        file { "openvpn-${title}.conf-active":
            ensure  => present,
            name    => $active_config,
            source  => "puppet:///files/openvpn-${title}-${certname}.conf",
            owner   => $::os::params::adminuser,
            group   => $::os::params::admingroup,
            mode    => '0644',
            require => Class['openvpn::install'],
        }

        # Remove the inactive configuration file (if we switched from 
        # $enable_service = true to false, or vice versa.
        file { "openvpn-${title}.conf-inactive":
            ensure  => absent,
            name    => $inactive_config,
            require => File["openvpn-${title}.conf-active"],
            notify  => Class['openvpn::service'],
        }
    }
}

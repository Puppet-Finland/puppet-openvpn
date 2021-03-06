#
# == Define: openvpn::monit
#
# Enable local monitoring of an OpenVPN process
#
# == Parameters
#
# [*title*]
#   While not strictly a parameter, the resource title is used as an identifier 
#   for this OpenVPN instance.
# [*service_type*]
#   Service type. Valid values are 'client', 'server' and undef (default). 
#   Define this only for those systemd distros that need it. 
#
define openvpn::monit
(
    Boolean                           $enable_service,
    Optional[Enum['client','server']] $service_type = undef
)
{
    include ::openvpn::params

    if $enable_service {
        $ensure = present
    } else {
        $ensure = absent
    }

    if $::openvpn::params::pidfile_prefix {
        $pidfile = "${::openvpn::params::pid_dir}/${::openvpn::params::pidfile_prefix}${title}.pid"
    } else {
        $pidfile = "${::openvpn::params::pid_dir}/${title}.pid"
    }

    # This will fail if there are client and server configs with the same name.
    # But there is no easy workaround for that, unless we force creation of
    # a pidfile, which is its own can of worms with different systemd versions.
    if $::openvpn::params::use_monit_procmatch {
        $match = "matching \"/usr/sbin/openvpn .* --config ${title}.conf\""
    } else {
        $match = "with pidfile ${pidfile}"
    }

    # On systemd-enabled distros we can manage individual VPN connections 
    # separately, without having to restart all connections if one of them goes 
    # down. More recent packages on systemd distros distinguish between client
    # and server connections as well.
    if $::systemd {
        if $service_type {
            $service_start = "${::openvpn::params::service_start}-${service_type}@${title}"
            $service_stop = "${::openvpn::params::service_stop}-${service_type}@${title}"
        } else {
            $service_start = "${::openvpn::params::service_start}@${title}"
            $service_stop = "${::openvpn::params::service_stop}@${title}"
        }
    } else {
        $service_start = $::openvpn::params::service_start
        $service_stop = $::openvpn::params::service_stop
    }

    @file { "openvpn-${title}-openvpn.monit":
        ensure  => $ensure,
        name    => "${::monit::params::fragment_dir}/openvpn-${title}.monit",
        content => template('openvpn/openvpn.monit.erb'),
        owner   => $::os::params::adminuser,
        group   => $::os::params::admingroup,
        mode    => '0600',
        require => Class['monit::config'],
        notify  => Class['monit::service'],
        tag     => 'monit',
    }
}

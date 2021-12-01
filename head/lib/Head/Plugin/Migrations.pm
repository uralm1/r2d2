package Head::Plugin::Migrations;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::mysql;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # apply db migrations
  $app->helper(migrate_database => sub {
    my $self = shift;
    my $mysql = $self->mysql_inet;

    $mysql->auto_migrate(1)->migrations->name('inetdb')->from_data;
    #$mysql->auto_migrate(1);
  });
}


1;
__DATA__
@@ inetdb
-- 1 up
CREATE TABLE IF NOT EXISTS `devices` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `login` varchar(30) DEFAULT NULL,
  `name` VARCHAR(255) NOT NULL,
  `desc` varchar(255) DEFAULT NULL,
  `bot` tinyint(1) NOT NULL,
  `create_time` datetime DEFAULT NULL,
  `ip` bigint(20) UNSIGNED NOT NULL,
  `mac` varchar(30) NOT NULL,
  `rt` tinyint(3) UNSIGNED NOT NULL,
  `defjump` varchar(255) NOT NULL,
  `speed_in` varchar(100) NOT NULL,
  `speed_out` varchar(100) NOT NULL,
  `no_dhcp` tinyint(1) NOT NULL,
  `sum_in` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `sum_out` bigint(20) UNSIGNED NOT NULL DEFAULT '0',
  `qs` tinyint(3) UNSIGNED NOT NULL,
  `limit_in` bigint(20) UNSIGNED NOT NULL,
  `sum_limit_in` bigint(20) UNSIGNED NOT NULL,
  `notified` tinyint(1) NOT NULL,
  `blocked` tinyint(1) NOT NULL,
  `profile` varchar(30) NOT NULL,
  `client_id` INT(11) UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ip` (`ip`),
  KEY `no_dhcp` (`no_dhcp`),
  KEY `profile` (`profile`),
  KEY `login` (`login`) USING BTREE,
  KEY `client_id` (`client_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `devices_sync` (
  `device_id` int(11) UNSIGNED NOT NULL,
  `login` varchar(30) NOT NULL,
  `sync_rt` tinyint(1) NOT NULL,
  `sync_fw` tinyint(1) NOT NULL,
  `sync_dhcp` tinyint(1) NOT NULL,
  `email_notified` tinyint(1) NOT NULL,
  PRIMARY KEY (`login`),
  KEY `sync_rt` (`sync_rt`),
  KEY `sync_fw` (`sync_fw`),
  KEY `sync_dhcp` (`sync_dhcp`),
  KEY `id` (`device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `adaily` (
  `device_id` int(11) UNSIGNED NOT NULL,
  `login` varchar(30) NOT NULL,
  `date` date NOT NULL,
  `d_in` bigint(20) UNSIGNED NOT NULL,
  `d_out` bigint(20) UNSIGNED NOT NULL,
  PRIMARY KEY (`login`,`date`),
  KEY `date` (`date`),
  KEY `login` (`login`),
  KEY `device_id` (`device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `amonthly` (
  `device_id` int(11) UNSIGNED NOT NULL,
  `login` varchar(30) NOT NULL,
  `date` date NOT NULL,
  `m_in` bigint(20) UNSIGNED NOT NULL,
  `m_out` bigint(20) UNSIGNED NOT NULL,
  PRIMARY KEY (`date`,`login`),
  KEY `date` (`date`),
  KEY `login` (`login`),
  KEY `device_id` (`device_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `clients` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `type` tinyint(3) UNSIGNED NOT NULL,
  `guid` char(36) CHARACTER SET ascii NOT NULL,
  `login` varchar(255) NOT NULL,
  `desc` varchar(255) NOT NULL,
  `create_time` datetime DEFAULT NULL,
  `cn` varchar(255) NOT NULL,
  `email` varchar(255) NOT NULL,
  `email_notify` tinyint(1) NOT NULL,
  `lost` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `typelogin` (`type`, `login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `op_log` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL,
  `subsys` varchar(30) NOT NULL,
  `info` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `audit_log` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL,
  `login` varchar(30) NOT NULL,
  `info` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `profiles` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `profile` varchar(30) NOT NULL,
  `name` varchar(255) NOT NULL,
  `lastcheck` datetime DEFAULT NULL,
  PRIMARY KEY(`id`),
  UNIQUE KEY `profile` (`profile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `profiles_agents` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `profile_id` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `type` varchar(30) NOT NULL,
  `url` varchar(255) NOT NULL,
  `block` tinyint(1) NOT NULL,
  `lastcheck` datetime DEFAULT NULL,
  `state` tinyint(1) NOT NULL,
  `status` varchar(255) NOT NULL,
  PRIMARY KEY(`id`),
  KEY `profile_id` (`profile_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- 1 down
DROP TABLE IF EXISTS `clients`;
DROP TABLE IF EXISTS `devices`;
DROP TABLE IF EXISTS `devices_sync`;
DROP TABLE IF EXISTS `adaily`;
DROP TABLE IF EXISTS `amonthly`;
DROP TABLE IF EXISTS `op_log`;
DROP TABLE IF EXISTS `audit_log`;
DROP TABLE IF EXISTS `profiles`;
DROP TABLE IF EXISTS `profiles_agents`;


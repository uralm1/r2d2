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
CREATE TABLE IF NOT EXISTS `clients` (
  `login` varchar(30) NOT NULL,
  `desc` varchar(255) NOT NULL,
  `email_notify` tinyint(1) NOT NULL,
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
  PRIMARY KEY (`ip`),
  UNIQUE KEY `login` (`login`),
  KEY `no_dhcp` (`no_dhcp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `clients_sync` (
  `login` varchar(30) NOT NULL,
  `sync_rt` tinyint(1) NOT NULL,
  `sync_fw` tinyint(1) NOT NULL,
  `sync_dhcp` tinyint(1) NOT NULL,
  `email_notified` tinyint(1) NOT NULL,
  PRIMARY KEY (`login`),
  KEY `sync_rt` (`sync_rt`),
  KEY `sync_fw` (`sync_fw`),
  KEY `sync_dhcp` (`sync_dhcp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `adaily` (
  `login` varchar(30) NOT NULL,
  `date` date NOT NULL,
  `d_in` bigint(20) UNSIGNED NOT NULL,
  `d_out` bigint(20) UNSIGNED NOT NULL,
  PRIMARY KEY (`login`,`date`),
  KEY `date` (`date`),
  KEY `login` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `amonthly` (
  `login` varchar(30) NOT NULL,
  `date` date NOT NULL,
  `m_in` bigint(20) UNSIGNED NOT NULL,
  `m_out` bigint(20) UNSIGNED NOT NULL,
  PRIMARY KEY (`date`,`login`),
  KEY `date` (`date`),
  KEY `login` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `log_admin` (
  `log_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `row_id` int(10) UNSIGNED NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `msg` varchar(255) NOT NULL,
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `row_id` (`row_id`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `log_agents` (
  `log_id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `row_id` int(10) UNSIGNED NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `msg` varchar(255) NOT NULL,
  PRIMARY KEY (`log_id`),
  UNIQUE KEY `row_id` (`row_id`),
  KEY `timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- 1 down
DROP TABLE IF EXISTS `clients`;
DROP TABLE IF EXISTS `clients_sync`;
DROP TABLE IF EXISTS `adaily`;
DROP TABLE IF EXISTS `amonthly`;
DROP TABLE IF EXISTS `log_admin`;
DROP TABLE IF EXISTS `log_agents`;

-- 2 up
ALTER TABLE `clients` DROP PRIMARY KEY;
ALTER TABLE `clients` ADD UNIQUE INDEX (`ip`);
ALTER TABLE `clients` ADD `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (`id`);
ALTER TABLE `clients` ADD `profile` varchar(30) NOT NULL AFTER `sum_limit_in`, ADD INDEX (`profile`);
ALTER TABLE `clients_sync` ADD `client_id` int(11) UNSIGNED NOT NULL FIRST, ADD INDEX (`client_id`);
ALTER TABLE `adaily` ADD `client_id` int(11) UNSIGNED NOT NULL FIRST, ADD INDEX (`client_id`);
ALTER TABLE `amonthly` ADD `client_id` int(11) UNSIGNED NOT NULL FIRST, ADD INDEX (`client_id`);

CREATE TABLE IF NOT EXISTS `profiles` (
  `profile` varchar(30) NOT NULL,
  `name` varchar(255) NOT NULL,
  PRIMARY KEY (`profile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `op_log` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL,
  `subsys` varchar(30) NOT NULL,
  `info` varchar(1024) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `date` (`date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2 down
ALTER TABLE `clients` DROP `id`;
ALTER TABLE `clients` DROP `profile`;
ALTER TABLE `clients` DROP INDEX `ip`;
ALTER TABLE `client` ADD PRIMARY KEY (`ip`);
ALTER TABLE `clients_sync` DROP `client_id`;
ALTER TABLE `adaily` DROP `client_id`;
ALTER TABLE `amonthly` DROP `client_id`;

DROP TABLE IF EXISTS `profiles`;
DROP TABLE IF EXISTS `op_log`;

-- 3 up
UPDATE clients_sync, clients SET clients_sync.client_id = clients.id WHERE clients_sync.login = clients.login;
UPDATE adaily, clients SET adaily.client_id = clients.id WHERE adaily.login = clients.login;
UPDATE amonthly, clients SET amonthly.client_id = clients.id WHERE amonthly.login = clients.login;

-- 3 down

-- 4 up
ALTER TABLE `clients` ADD `notified` tinyint(1) NOT NULL AFTER `sum_limit_in`;
ALTER TABLE `clients` ADD `blocked` tinyint(1) NOT NULL AFTER `notified`;

-- 4 down
ALTER TABLE `clients` DROP `notified`;
ALTER TABLE `clients` DROP `blocked`;

-- 5 up
CREATE TABLE IF NOT EXISTS `servers` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `desc` varchar(255) NOT NULL,
  `create_time` datetime DEFAULT NULL,
  `clients_id` int(11) UNSIGNED NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

ALTER TABLE `clients` DROP INDEX `login`, ADD INDEX `login` (`login`) USING BTREE;
ALTER TABLE `clients` CHANGE `login` `login` VARCHAR(30) NULL;
ALTER TABLE `clients` CHANGE `desc` `desc` VARCHAR(255) NULL;

-- 5 down
DROP TABLE IF EXISTS `servers`;
ALTER TABLE `clients` DROP INDEX `login`, ADD UNIQUE `login` (`login`) USING BTREE;
ALTER TABLE `clients` CHANGE `login` `login` VARCHAR(30) NOT NULL;
ALTER TABLE `clients` CHANGE `desc` `desc` VARCHAR(255) NOT NULL;


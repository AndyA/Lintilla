CREATE DATABASE /*!32312 IF NOT EXISTS*/ `spider`;
USE `spider`;
-- MySQL dump 10.15  Distrib 10.0.10-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: spider
-- ------------------------------------------------------
-- Server version	10.0.10-MariaDB-1~wheezy

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `spider_page`
--

DROP TABLE IF EXISTS `spider_page`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `spider_page` (
  `url` text NOT NULL,
  `url_hash` varchar(64) NOT NULL,
  `mime` varchar(255) DEFAULT NULL,
  `rank` int(10) DEFAULT NULL,
  `visits` int(10) unsigned DEFAULT NULL,
  `elapsed` int(10) unsigned DEFAULT NULL,
  `body` longtext,
  `header` mediumtext,
  `code` int(3) DEFAULT NULL,
  `message` text,
  `last_visit` int(12) unsigned DEFAULT NULL,
  `worker_start` int(12) unsigned DEFAULT NULL,
  `worker_id` varchar(80) DEFAULT NULL,
  PRIMARY KEY (`url_hash`),
  KEY `worker_id` (`worker_id`),
  KEY `last_visit` (`last_visit`),
  KEY `rank` (`rank`),
  KEY `last_visit_rank` (`last_visit`,`rank`),
  KEY `mime` (`mime`),
  KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `spider_via`
--

DROP TABLE IF EXISTS `spider_via`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `spider_via` (
  `url_hash` varchar(64) NOT NULL,
  `via_hash` varchar(64) NOT NULL,
  `last_visit` int(12) unsigned DEFAULT NULL,
  UNIQUE KEY `hash` (`url_hash`,`via_hash`),
  KEY `via_hash` (`via_hash`),
  KEY `url_hash` (`url_hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'spider'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-04-06 12:15:10

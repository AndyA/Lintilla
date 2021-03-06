CREATE DATABASE /*!32312 IF NOT EXISTS*/ `sfx`;
USE `sfx`;
-- MySQL dump 10.14  Distrib 10.0.6-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: sfx
-- ------------------------------------------------------
-- Server version	10.0.6-MariaDB-1~wheezy

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
-- Table structure for table `sfx_collection`
--

DROP TABLE IF EXISTS `sfx_collection`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_collection` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Collection id',
  `name` varchar(60) NOT NULL COMMENT 'Collection name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_copyright_class`
--

DROP TABLE IF EXISTS `sfx_copyright_class`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_copyright_class` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Copyright class id',
  `name` char(1) NOT NULL COMMENT 'Copyright class',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_copyright_holder`
--

DROP TABLE IF EXISTS `sfx_copyright_holder`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_copyright_holder` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Copyright holder id',
  `name` varchar(200) NOT NULL COMMENT 'Copyright holder name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=568 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_format`
--

DROP TABLE IF EXISTS `sfx_format`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_format` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Format id',
  `name` varchar(50) NOT NULL COMMENT 'Format name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=20 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_image`
--

DROP TABLE IF EXISTS `sfx_image`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_image` (
  `hash` char(64) DEFAULT NULL COMMENT 'SHA1 hash',
  `acno` int(10) unsigned NOT NULL COMMENT 'Asset id',
  `kind_id` int(10) unsigned DEFAULT NULL,
  `collection_id` int(10) unsigned DEFAULT NULL,
  `copyright_class_id` int(10) unsigned DEFAULT NULL,
  `copyright_holder_id` int(10) unsigned DEFAULT NULL,
  `format_id` int(10) unsigned DEFAULT NULL,
  `location_id` int(10) unsigned DEFAULT NULL,
  `news_restriction_id` int(10) unsigned DEFAULT NULL,
  `personality_id` int(10) unsigned DEFAULT NULL,
  `origin_date` date DEFAULT NULL,
  `photographer_id` int(10) unsigned DEFAULT NULL,
  `subject_id` int(10) unsigned DEFAULT NULL,
  `width` int(5) unsigned DEFAULT NULL,
  `height` int(5) unsigned DEFAULT NULL,
  `annotation` text,
  `headline` text,
  `seq` double DEFAULT NULL,
  PRIMARY KEY (`acno`),
  KEY `sfx_image_hash` (`hash`),
  KEY `sfx_image_seq` (`seq`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_kind`
--

DROP TABLE IF EXISTS `sfx_kind`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_kind` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Image kind id',
  `name` varchar(60) NOT NULL COMMENT 'Image kind name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_location`
--

DROP TABLE IF EXISTS `sfx_location`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_location` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Location id',
  `name` varchar(100) NOT NULL COMMENT 'Location name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=229 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_news_restriction`
--

DROP TABLE IF EXISTS `sfx_news_restriction`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_news_restriction` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'News restriction id',
  `name` varchar(1000) NOT NULL COMMENT 'News restriction name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_personality`
--

DROP TABLE IF EXISTS `sfx_personality`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_personality` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Personality id',
  `name` varchar(2000) NOT NULL COMMENT 'Personality name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=12792 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_photographer`
--

DROP TABLE IF EXISTS `sfx_photographer`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_photographer` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Photographer id',
  `name` varchar(200) NOT NULL COMMENT 'Photographer name',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1339 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sfx_subject`
--

DROP TABLE IF EXISTS `sfx_subject`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sfx_subject` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Subject term id',
  `name` varchar(200) NOT NULL COMMENT 'Subject term',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=288 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'sfx'
--
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-12-07  2:46:10

START TRANSACTION;

SELECT `seq` FROM `elvis_hwm` WHERE `id` = 11901 INTO @hwm;
SELECT COUNT(*) FROM `elvis_image` INTO @bump;
UPDATE `elvis_image` SET `seq` = `seq` + @bump WHERE `seq` < @hwm - 10;

COMMIT;


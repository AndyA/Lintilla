SELECT 
  pl.id,
  pa.url, 
  pa.rank, 
  pl.plain 
FROM 
  spider_page AS pa, spider_plain AS pl 
WHERE 
  pa.url_hash = pl.url_hash

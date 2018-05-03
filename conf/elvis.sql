SELECT
  i.acno,
  i.annotation,
  i.headline,
  i.width,
  i.height,
  i.width / i.height AS aspect,
  i.width * i.height AS area,
  TO_DAYS(i.origin_date) * 86400 + TIME_TO_SEC(i.origin_date) AS `origin_date`,
  i.collection_id,
  i.copyright_class_id,
  i.copyright_holder_id,
  i.format_id,
  i.kind_id,
  i.location_id,
  i.news_restriction_id,
  i.personality_id,
  i.photographer_id,
  i.subject_id,
  l.name AS location,
  pe.name AS personality,
  ph.name AS photographer,
  s.name AS subject, 
  (
    SELECT
      GROUP_CONCAT(k.name SEPARATOR ', ')
    FROM
      elvis_keyword AS k,
      elvis_image_keyword AS ik
    WHERE ik.id=k.id
      AND ik.acno=i.acno
  ) AS keywords
FROM
  elvis_image AS i
LEFT JOIN (
  elvis_location AS l,
  elvis_personality AS pe,
  elvis_photographer AS ph,
  elvis_subject AS s
)
ON (
      i.location_id = l.id
  AND i.personality_id = pe.id
  AND i.photographer_id = ph.id
  AND i.subject_id = s.id
)

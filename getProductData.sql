
SELECT * FROM UpdateProducts('Filial_east', ARRAY['Filial_west', 'Warehouse'], '2016-01-01', '2018-01-01');
SELECT * FROM UpdateCardsFromFilials(ARRAY['Filial_west', 'Filial_east'], '2016-01-01', '2018-01-01');
SELECT * FROM UpdateChecksFromFilials(ARRAY['Filial_west', 'Filial_east'], '2016-01-01', '2018-01-01');


SELECT * FROM UpdateProducts('Filial_east', ARRAY['Filial_south'], '2016-01-01', '2018-01-01');
SELECT * FROM SendCardsToFilial('Filial_south', 'Filial_west');
SELECT * FROM SendChecksToFilial('Filial_south', 'Filial_west', '2016-01-01', '2018-01-01');

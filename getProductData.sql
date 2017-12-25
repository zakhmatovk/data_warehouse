-- Получим данные о продуктах из 'Filial_east' и разошлём их во все остальные таблицы филиалов и хранилище
SELECT * FROM UpdateProducts('Filial_east', ARRAY['Filial_west', 'Warehouse'], '2016-01-01', '2018-01-01');
-- Получим данные о картах из филиалов и запишем их в хранилище
SELECT * FROM UpdateCardsFromFilials(ARRAY['Filial_west', 'Filial_east'], '2016-01-01', '2018-01-01');
-- Получим данные о чеках из филиалов и запишем их в хранилище
SELECT * FROM UpdateChecksFromFilials(ARRAY['Filial_west', 'Filial_east'], '2016-01-01', '2018-01-01');


-- Заполним Filial_south данными из Filial_west
-- Отправим данные о продуктах в Filial_south
SELECT * FROM UpdateProducts('Filial_east', ARRAY['Filial_south'], '2016-01-01', '2018-01-01');
-- Отправим данные о картах по филиалу Filial_west из хранилища в Filial_south
SELECT * FROM SendCardsToFilial('Filial_south', 'Filial_west');
-- Отправим данные о чеках по филиалу Filial_west из хранилища в Filial_south
SELECT * FROM SendChecksToFilial('Filial_south', 'Filial_west', '2016-01-01', '2018-01-01');


-- Создадим таблицу в витрине и положим туда данные об пара продуктов, которые чаще всего покупаю вместе
SELECT * FROM FindProductPairs('Showcase', '2016-01-01', '2018-01-01');

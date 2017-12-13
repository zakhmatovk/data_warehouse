set search_path = "public";
WITH source
AS (
   SELECT *
   FROM dblink(
      'host=localhost user=postgres password=12345 dbname=Filial_west'::TEXT,
      'SELECT * FROM getNewProducts(''2016-01-01'', ''2018-01-01'')'::TEXT
   ) AS dataSet(
      "@Price" INT,
      "Cost" FLOAT,
      "CostSale" FLOAT,
      "SetDate" TIMESTAMP,
      "@Product" INT,
      "Name" VARCHAR(50),
      "VendorCode" VARCHAR(30),
      "@Supplier" INT,
      "SupplierName" VARCHAR(50),
      "INN" VARCHAR(30))
),
supplier_data
AS (
      SELECT DISTINCT "@Supplier",
         "SupplierName",
         "INN"
      FROM source
   ),
insert_supplier
AS (
   INSERT INTO "Supplier"
   SELECT "@Supplier",
      "SupplierName",
      "INN"
   FROM supplier_data
   ON CONFLICT ("@Supplier") DO UPDATE
   SET "Name" = EXCLUDED."Name",
      "INN" = EXCLUDED."INN"
   RETURNING "@Supplier"
   ),
suppliers_text
AS (
   SELECT 'INSERT INTO "Supplier" ("@Supplier", "Name", "INN") VALUES ' || string_agg('(' || concat_ws(', ',
         CoverInQuotes("@Supplier"),
         CoverInQuotes("SupplierName"),
         CoverInQuotes("INN")
      ) || ')', ', ')
      || ' ON CONFLICT ("@Supplier")
      DO UPDATE
      SET
         "Name" = EXCLUDED."Name",
         "INN" = EXCLUDED."INN"
      RETURNING "@Supplier"' AS stmt
   FROM supplier_data
   )
--SELECT * FROM suppliers_text

SELECT *
   FROM dblink(
      'host=localhost user=postgres password=12345 dbname=Filial_east'::TEXT,
      (select stmt from suppliers_text)
      ) AS inserted (
      "@Supplier" INT
      )

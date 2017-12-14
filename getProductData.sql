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
      SELECT DISTINCT
         "@Supplier",
         "SupplierName" AS "Name",
         "INN"
      FROM source
   ),
stmt_insert_supplier
AS (
   SELECT
      'INSERT INTO "Supplier" ("@Supplier", "Name", "INN") VALUES '
         || string_agg('('
         || concat_ws(', ',
            CoverInQuotes("@Supplier"),
            CoverInQuotes("Name"),
            CoverInQuotes("INN")
         )
         || ')', ', ')
         || ' ON CONFLICT ("@Supplier")
         DO UPDATE
         SET
            "Name" = EXCLUDED."Name",
            "INN" = EXCLUDED."INN"
      ' AS stmt
   FROM supplier_data
   ),

product_data
AS (
      SELECT DISTINCT
         "@Product",
         "Name",
         "VendorCode",
         "@Supplier" AS "Supplier"
      FROM source
   ),
stmt_insert_product
AS (
   SELECT
      'INSERT INTO "Product" ("@Product", "Name", "VendorCode", "Supplier") VALUES '
         || string_agg('(' || concat_ws(', ',
            CoverInQuotes("@Product"),
            CoverInQuotes("Name"),
            CoverInQuotes("VendorCode"),
            CoverInQuotes("Supplier")
         ) || ')', ', ')
         || ' ON CONFLICT ("@Product")
         DO UPDATE
         SET
            "Name" = EXCLUDED."Name",
            "VendorCode" = EXCLUDED."VendorCode",
            "Supplier" = EXCLUDED."Supplier"
      ' AS stmt
   FROM product_data
   ),

price_data
AS (
      SELECT DISTINCT
         "@Price",
         "@Product" AS "Product",
         "Cost",
         "CostSale",
         "SetDate"
      FROM source
   ),
stmt_insert_price
AS (
   SELECT
      'INSERT INTO "Price" ("@Price", "Product", "Cost", "CostSale", "SetDate") VALUES '
         || string_agg('(' || concat_ws(', ',
            CoverInQuotes("@Price"),
            CoverInQuotes("Product"),
            CoverInQuotes("Cost"),
            CoverInQuotes("CostSale"),
            CoverInQuotes("SetDate")
         )
         || ')', ', ')
         || ' ON CONFLICT ("@Price")
         DO UPDATE
         SET
            "Product" = EXCLUDED."Product",
            "Cost" = EXCLUDED."Cost",
            "CostSale" = EXCLUDED."CostSale",
            "SetDate" = EXCLUDED."SetDate"
      ' AS stmt
   FROM price_data
   ),
insertTo AS (
   SELECT 'Suppler', * FROM InsetToFilial(ARRAY['Filial_east', 'Warehouse'], (SELECT stmt FROM stmt_insert_supplier))
   UNION
   SELECT 'Product', * FROM InsetToFilial(ARRAY['Filial_east', 'Warehouse'], (SELECT stmt FROM stmt_insert_product))
   UNION
   SELECT 'Price', * FROM InsetToFilial(ARRAY['Filial_east', 'Warehouse'], (SELECT stmt FROM stmt_insert_price))
)
SELECT * FROM insertTo;
Select * FROM UpdateCardsFromFilials(ARRAY['Filial_west'], '2016-01-01', '2018-01-01');
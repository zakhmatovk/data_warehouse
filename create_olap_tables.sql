CREATE OR REPLACE FUNCTION fill_date_parts() RETURNS TRIGGER AS $$
BEGIN
    NEW."Year" := date_part('year', NEW."Date");
    NEW."Month" := date_part('month', NEW."Date");
    NEW."Day" := date_part('day', NEW."Date");
    NEW."DayOfWeek" := date_part('isodow', NEW."Date");
    NEW."Hour" := date_part('hour', NEW."Date");
    NEW."Minute" := date_part('minute', NEW."Date");
    NEW."Second" := date_part('second', NEW."Date");

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION CoverInQuotes (source_value anyelement)
   RETURNS TEXT
AS $$
BEGIN
   IF source_value IS NULL
      THEN RETURN 'NULL';
      ELSE RETURN '''' || source_value::text || '''';
   END IF;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION InsetToFilial (
   filial_db_names TEXT [],
   sql_stmt TEXT
   )
RETURNS TABLE (
   "Filial_db_name" TEXT,
   "Result" TEXT)
AS $$
BEGIN
   RETURN QUERY

   SELECT db_name,
      (
         SELECT inserted."Result"
         FROM dblink(
               'host=localhost user=postgres password=12345 dbname=' || db_name,
               sql_stmt
            ) AS inserted("Result" TEXT)
         )
   FROM (
      SELECT unnest(filial_db_names) AS db_name
      ) AS db_names;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION UpdateProducts (
   source_filial TEXT,
   filial_db_names TEXT [],
   startDate timestamp,
   endDate timestamp
)
RETURNS TABLE (
   "Entity" TEXT,
   "Filial_db_name" TEXT,
   "Result" TEXT
)
AS $$
BEGIN
   RETURN QUERY
      WITH source
      AS (
         SELECT *
         FROM dblink(
            'host=localhost user=postgres password=12345 dbname=' || source_filial,
            'SELECT * FROM getNewProducts(''' || startDate || ''', ''' || endDate || ''')'
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
         )
      SELECT 'Suppler', * FROM InsetToFilial(filial_db_names, (SELECT stmt FROM stmt_insert_supplier))
      UNION
      SELECT 'Product', * FROM InsetToFilial(filial_db_names, (SELECT stmt FROM stmt_insert_product))
      UNION
      SELECT 'Price', * FROM InsetToFilial(filial_db_names, (SELECT stmt FROM stmt_insert_price));
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION UpdateCardsFromFilials (
   filial_db_names TEXT [],
   startDate timestamp,
   endDate timestamp
   )
   RETURNS TEXT
AS $$
BEGIN
   WITH RECURSIVE source AS (
      SELECT
         unnest(filial_db_names) AS db_name,
         NULL::INT AS "@Card",
         NULL::TEXT AS "Number",
         NULL::TEXT AS "FirstName",
         NULL::TEXT AS "MiddleName",
         NULL::TEXT AS "LastName",
         NULL::Date AS "BirthDate",
         1 AS level
      UNION
      SELECT
         source.db_name,
         inserted."@Card",
         inserted."Number",
         inserted."FirstName",
         inserted."MiddleName",
         inserted."LastName",
         inserted."BirthDate",
         source."level" + 1 AS "level"
      FROM source, dblink(
            'host=localhost user=postgres password=12345 dbname=' || source.db_name,
            'SELECT * FROM getNewCards(''' || startDate || ''', ''' || endDate || ''')'
         ) AS inserted(
            "@Card" INT,
            "Number" text,
            "FirstName" text,
            "MiddleName" text,
            "LastName" text,
            "BirthDate" date
         )
      WHERE source."level" = 1
   ),
   filtered_source AS (
      SELECT * FROM source
      WHERE "@Card" IS NOT NULL
   )
   INSERT INTO "Card"
   SELECT
      "@Card",
      "Number",
      "FirstName",
      "MiddleName",
      "LastName",
      "BirthDate"
   FROM filtered_source
   ON CONFLICT ("@Card")
   DO UPDATE
   SET
      "Number" = EXCLUDED."Number",
      "FirstName" = EXCLUDED."FirstName",
      "MiddleName" = EXCLUDED."MiddleName",
      "LastName" = EXCLUDED."LastName",
      "BirthDate" = EXCLUDED."BirthDate";
   RETURN 'Complete';
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION UpdateChecksFromFilials (
   filial_db_names TEXT [],
   startDate timestamp,
   endDate timestamp
   )
   RETURNS TEXT
AS $$
BEGIN
   WITH RECURSIVE source AS (
      SELECT
         unnest(filial_db_names) AS db_name,
         NULL::INT AS "Check",
         NULL::INT AS "Card",
         NULL::timestamp AS "CheckDate",
         NULL::BOOLEAN AS "Payed",
         NULL::INT AS "PaymentForm",
         NULL::FLOAT AS "Price",
         NULL::FLOAT AS "Count",
         NULL::INT AS "Product",
         NULL::INT AS "Supplier",
         1 AS level
      UNION
      SELECT
         source.db_name,
         inserted."Check",
         inserted."Card",
         inserted."CheckDate",
         inserted."Payed",
         inserted."PaymentForm",
         inserted."Price",
         inserted."Count",
         inserted."Product",
         inserted."Supplier",
         source."level" + 1 AS "level"
      FROM source, dblink(
            'host=localhost user=postgres password=12345 dbname=' || source.db_name,
            'SELECT * FROM getChecks(''' || startDate || ''', ''' || endDate || ''')'
         ) AS inserted(
            "Check" INT,
            "Card" INT,
            "CheckDate" timestamp,
            "Payed" BOOLEAN,
            "PaymentForm" INT,
            "Price" float,
            "Count" float,
            "Product" INT,
            "Supplier" INT
         )
      WHERE source."level" = 1
   ),
   filtered_source AS (
      SELECT *,
         store."@Store" AS "Store"
      FROM source
      INNER JOIN "Store" store
         ON store."db_name" = source."db_name"
      WHERE "Check" IS NOT NULL
   ),
   insert_date AS (
      INSERT INTO "Date"("Date")
      SELECT DISTINCT "CheckDate"
      FROM filtered_source
      RETURNING "@Date", "Date"
   ),
   source_with_date AS (
      SELECT
         s.*,
         d."@Date"
      FROM filtered_source AS s
      INNER JOIN insert_date AS d
         ON s."CheckDate" = d."Date"
   )
   INSERT INTO "SaleFact" ("Check", "Card", "Date", "Payed", "PaymentForm", "Price", "Count", "Product", "Supplier", "Store")
   SELECT
      "Check",
      "Card",
      "@Date",
      "Payed",
      "PaymentForm",
      "Price",
      "Count",
      "Product",
      "Supplier",
      "Store"
   FROM source_with_date
   ON CONFLICT ("Check", "Product", "Store")
   DO UPDATE
   SET
      "Card" = EXCLUDED."Card",
      "Date" = EXCLUDED."Date",
      "Payed" = EXCLUDED."Payed",
      "PaymentForm" = EXCLUDED."PaymentForm",
      "Price" = EXCLUDED."Price",
      "Count" = EXCLUDED."Count",
      "Supplier" = EXCLUDED."Supplier";
   RETURN 'Complete';
END;
$$ LANGUAGE 'plpgsql';


CREATE OR REPLACE FUNCTION SendCardsToFilial (
   filial_db_name TEXT,
   store_db_name TEXT
)
   RETURNS TABLE (
      "Entity" TEXT,
      "Filial_db_name" TEXT,
      "Result" TEXT
   )
AS $$
BEGIN
   RETURN QUERY
   WITH store AS (
      SELECT
         "@Store" * 10000000 AS _min,
         ("@Store" + 1) * 10000000 AS _max
      FROM "Store"
      WHERE "db_name" = store_db_name
      LIMIT 1
   ),
   stmt_insert_card
      AS (
         SELECT
            'INSERT INTO "Card" ("@Card", "Number", "FirstName", "MiddleName", "LastName", "BirthDate") VALUES '
               || string_agg('(' || concat_ws(', ',
                  CoverInQuotes("@Card"),
                  CoverInQuotes("Number"),
                  CoverInQuotes("FirstName"),
                  CoverInQuotes("MiddleName"),
                  CoverInQuotes("LastName"),
                  CoverInQuotes("BirthDate")
               )
               || ')', ', ')
               || ' ON CONFLICT ("@Card")
               DO UPDATE
               SET
                  "Number" = EXCLUDED."Number",
                  "FirstName" = EXCLUDED."FirstName",
                  "MiddleName" = EXCLUDED."MiddleName",
                  "LastName" = EXCLUDED."LastName",
                  "BirthDate" = EXCLUDED."BirthDate"
            ' AS stmt
         FROM "Card"
         WHERE "@Card" >= (Select _min FROM store)
            AND "@Card" < (Select _max FROM store)
         )
      SELECT 'Card', * FROM InsetToFilial(ARRAY[filial_db_name], (SELECT stmt FROM stmt_insert_card));
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION SendChecksToFilial (
   filial_db_name TEXT,
   store_db_name TEXT,
   startDate timestamp,
   endDate timestamp
)
   RETURNS TABLE (
      "Entity" TEXT,
      "Filial_db_name" TEXT,
      "Result" TEXT
   )
AS $$
BEGIN
   RETURN QUERY
      WITH store AS (
         SELECT
            "@Store"
         FROM "Store"
         WHERE "db_name" = store_db_name
         LIMIT 1
      ),
      source AS (
         SELECT
            fact."Check",
            fact."Card",
            d."Date" AS "CheckDate",
            fact."Payed",
            fact."PaymentForm",
            fact."Price",
            fact."Count",
            fact."Product",
            fact."Supplier"
         FROM "SaleFact" fact
         INNER JOIN store
            ON store."@Store" = fact."Store"
         INNER JOIN "Date" d
            ON d."@Date" = fact."Date"
         WHERE d."Date" >= startDate
            AND d."Date" <= endDate
      ),
      stmt_insert_check AS (
         SELECT
            'INSERT INTO "Check" ("@Check", "Card", "CheckDate", "Payed", "PaymentForm") VALUES '
               || string_agg('(' || concat_ws(', ',
                  CoverInQuotes("@Check"),
                  CoverInQuotes("Card"),
                  CoverInQuotes("CheckDate"),
                  CoverInQuotes("Payed"),
                  CoverInQuotes("PaymentForm")
               )
               || ')', ', ')
               || ' ON CONFLICT ("@Check")
               DO UPDATE
               SET
                  "Card" = EXCLUDED."Card",
                  "CheckDate" = EXCLUDED."CheckDate",
                  "Payed" = EXCLUDED."Payed",
                  "PaymentForm" = EXCLUDED."PaymentForm"
            ' AS stmt
         FROM (
            SELECT DISTINCT
               "Check" AS "@Check",
               "Card",
               "CheckDate",
               "Payed",
               "PaymentForm"
            FROM source
         ) AS temp
      ),
      stmt_insert_product_check AS (
         SELECT
            'INSERT INTO "Product_Check" ("Product", "Check", "Price", "Count") VALUES '
               || string_agg('(' || concat_ws(', ',
                  CoverInQuotes("Product"),
                  CoverInQuotes("Check"),
                  CoverInQuotes("Price"),
                  CoverInQuotes("Count")
               )
               || ')', ', ')
               || ' ON CONFLICT ("Product", "Check")
               DO UPDATE
               SET
                  "Price" = EXCLUDED."Price",
                  "Count" = EXCLUDED."Count"
            ' AS stmt
         FROM source
      )
      SELECT 'Check', * FROM InsetToFilial(ARRAY[filial_db_name], (SELECT stmt FROM stmt_insert_check))
      UNION
      SELECT 'Product_Check', * FROM InsetToFilial(ARRAY[filial_db_name], (SELECT stmt FROM stmt_insert_product_check));
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION FindProductPairs (
   showcase_db_name TEXT,
   startDate timestamp,
   endDate timestamp
)
   RETURNS TABLE (
      "Entity" TEXT,
      "Showcase_db_name" TEXT,
      "Result" TEXT
   )
AS $$
BEGIN
   RETURN QUERY
      WITH source AS (
         SELECT
            main."Product",
            main."Supplier",
            sub."Product" AS "SubProduct",
            sub."Supplier" AS "SubSupplier",
            COUNT(main."Product") AS "Amount"

         FROM "SaleFact" main
         INNER JOIN "SaleFact" sub
            ON main."Check" = sub."Check"
            AND main."Store" = sub."Store"
            AND main."Product" > sub."Product"
         INNER JOIN "Date" d
            ON main."Date" = d."@Date"
         WHERE d."Date" >= startDate
            AND d."Date" <= endDate
         GROUP BY main."Product", sub."Product", main."Supplier", sub."Supplier"
      ),
      extension AS (
         SELECT
            source."Amount",
            p1."@Product",
            p1."Name" AS "ProductName",
            p1."VendorCode",
            s1."Name" AS "SupplierName",
            p2."@Product" AS "@Product2",
            p2."Name" AS "ProductName2",
            p2."VendorCode" AS "VendorCode2",
            s2."Name" AS "SupplierName2"
         FROM source
         INNER JOIN "Product" AS p1
            ON p1."@Product" = source."Product"
         INNER JOIN "Supplier" AS s1
            ON s1."@Supplier" = source."Supplier"
         INNER JOIN "Product" AS p2
            ON p2."@Product" = source."SubProduct"
         INNER JOIN "Supplier" AS s2
            ON s2."@Supplier" = source."SubSupplier"

         ORDER BY "Amount" DESC
      ),
      stmt_insert_pairs AS (
         SELECT
            'DROP TABLE IF EXISTS "ProductPairs";
            CREATE TABLE "ProductPairs" (
               "Amount" INT,
               "@Product" INT,
               "ProductName" varchar(50),
               "VendorCode" varchar(30),
               "SupplierName" varchar(50),
               "@Product2" INT,
               "ProductName2" varchar(50),
               "VendorCode2" varchar(30),
               "SupplierName2" varchar(50)
            );
            INSERT INTO "ProductPairs" ("Amount",
               "@Product", "ProductName", "VendorCode", "SupplierName",
               "@Product2", "ProductName2", "VendorCode2", "SupplierName2")
               VALUES '
               || string_agg('(' || concat_ws(', ',
                  CoverInQuotes("Amount"),
                  CoverInQuotes("@Product"),
                  CoverInQuotes("ProductName"),
                  CoverInQuotes("VendorCode"),
                  CoverInQuotes("SupplierName"),
                  CoverInQuotes("@Product2"),
                  CoverInQuotes("ProductName2"),
                  CoverInQuotes("VendorCode2"),
                  CoverInQuotes("SupplierName2")
               )
               || ')', ', ') AS stmt
         FROM extension
      )
      SELECT 'ProductPairs', * FROM InsetToFilial(ARRAY[showcase_db_name], (SELECT stmt FROM stmt_insert_pairs));
END;
$$ LANGUAGE 'plpgsql';


DROP TABLE IF EXISTS "SaleFact";
DROP TABLE IF EXISTS "Card";
DROP TABLE IF EXISTS "Price";
DROP TABLE IF EXISTS "Product";
DROP TABLE IF EXISTS "Supplier";
DROP TABLE IF EXISTS "Store";
DROP TABLE IF EXISTS "Date";

CREATE TABLE "Card" (
    "@Card" serial PRIMARY KEY,
    "Number" varchar(19) NOT NULL,
    "FirstName" varchar(50) NOT NULL,
    "MiddleName" varchar(50),
    "LastName" varchar(50) NOT NULL,
    "BirthDate" date NOT NULL
);

CREATE TABLE "Supplier" (
    "@Supplier" serial PRIMARY KEY,
    "Name" varchar(50) NOT NULL,
    "INN" varchar(30) NOT NULL
);

CREATE TABLE "Product" (
    "@Product" serial PRIMARY KEY,
    "Name" varchar(50) NOT NULL,
    "VendorCode" varchar(30) NOT NULL,
    "Supplier" INT NOT NULL
);

ALTER TABLE "Product"
   ADD CONSTRAINT "fk_Supplier"
   FOREIGN KEY ("Supplier")
   REFERENCES "Supplier"("@Supplier");

 CREATE TABLE "Price" (
     "@Price" serial PRIMARY KEY,
     "Product" int NOT NULL,
     "Cost" float NOT NULL,
     "CostSale" float NOT NULL,
     "SetDate" timestamp NOT NULL
 );

 ALTER TABLE "Price"
    ADD CONSTRAINT "fk_Product"
    FOREIGN KEY ("Product")
    REFERENCES "Product"("@Product");

CREATE TABLE "Store" (
    "@Store" serial PRIMARY KEY,
    "Name" varchar(50) NOT NULL,
    "Address" varchar(50) NOT NULL,
    "db_name" varchar(50) NOT NULL
 );

CREATE TABLE "Date" (
    "@Date" serial PRIMARY KEY,
    "Year" int NOT NULL,
    "Month" int NOT NULL,
    "Day" int NOT NULL,
    "DayOfWeek" int NOT NULL,
    "Hour" int NOT NULL,
    "Minute" int NOT NULL,
    "Second" int NOT NULL,
    "Date" timestamp NOT NULL
);

CREATE TABLE "SaleFact" (
    "Product" int NOT NULL,
    "Card" int NOT NULL,
    "Supplier" int NOT NULL,
    "Check" int NOT NULL,
    "Payed" BOOLEAN NOT NULL DEFAULT FALSE,
    "PaymentForm" INT CHECK ("PaymentForm" IN (1, 2)),
    "Store" int NOT NULL,
    "Date" int NOT NULL,
    "Price" float NOT NULL,
    "Count" float NOT NULL,
    PRIMARY KEY("Product", "Check", "Store")
 );

ALTER TABLE "SaleFact"
    ADD CONSTRAINT "fk_Product"
    FOREIGN KEY ("Product")
    REFERENCES "Product"("@Product");

ALTER TABLE "SaleFact"
    ADD CONSTRAINT "fk_Card"
    FOREIGN KEY ("Card")
    REFERENCES "Card"("@Card");

ALTER TABLE "SaleFact"
    ADD CONSTRAINT "fk_Supplier"
    FOREIGN KEY ("Supplier")
    REFERENCES "Supplier"("@Supplier");

ALTER TABLE "SaleFact"
    ADD CONSTRAINT "fk_Store"
    FOREIGN KEY ("Store")
    REFERENCES "Store"("@Store");

ALTER TABLE "SaleFact"
    ADD CONSTRAINT "fk_Date"
    FOREIGN KEY ("Date")
    REFERENCES "Date"("@Date");

CREATE TRIGGER fill_date_parts
   BEFORE UPDATE OR INSERT ON "Date"
   FOR EACH ROW
   EXECUTE PROCEDURE fill_date_parts();

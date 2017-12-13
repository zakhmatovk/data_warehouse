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

CREATE OR REPLACE FUNCTION InsetToFilial (conection_strings, sql text)
   RETURNS TEXT
AS $$
DECLARE
   conection_strings text ARRAY;
BEGIN
   SELECT conection_string FROM

END;
$$ LANGUAGE 'plpgsql';

DROP TABLE IF EXISTS "SaleFact";
DROP TABLE IF EXISTS "Check";
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

CREATE TABLE "Check" (
    "@Check" serial PRIMARY KEY,
    "Payed" BOOLEAN NOT NULL DEFAULT FALSE,
    "PaymentForm" INT CHECK ("PaymentForm" IN (1, 2))
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
    "Address" varchar(50) NOT NULL
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
    "@SaleFact" serial PRIMARY KEY,
    "Product" int NOT NULL,
    "Card" int NOT NULL,
    "Supplier" int NOT NULL,
    "Check" int NOT NULL,
    "Store" int NOT NULL,
    "Date" int NOT NULL,
    "Price" float NOT NULL
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
    ADD CONSTRAINT "Check"
    FOREIGN KEY ("Check")
    REFERENCES "Check"("@Check");

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

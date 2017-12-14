SET search_path = "public";

CREATE OR REPLACE FUNCTION update_modify_datetime() RETURNS TRIGGER AS $$
BEGIN
   IF (TG_OP = 'UPDATE') THEN
      NEW."ModifyDatetime" := current_timestamp;
   ELSIF (TG_OP = 'INSERT') THEN
      NEW."CreateDatetime" := current_timestamp;
      NEW."ModifyDatetime" := current_timestamp;
   END IF;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_price() RETURNS TRIGGER AS $$
BEGIN
   NEW."Price" := (
      SELECT "CostSale"
      FROM "Price"
      WHERE "Product" = NEW."Product"
         AND "SetDate" <= (
            SELECT "CheckDate"
            FROM "Check"
            WHERE "@Check" = NEW."Check"
            LIMIT 1
         )
      ORDER BY "SetDate" DESC
      LIMIT 1
   );
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TABLE IF EXISTS "Product_Check";
DROP TABLE IF EXISTS "Check";
DROP TABLE IF EXISTS "Card";
DROP TABLE IF EXISTS "Price";
DROP TABLE IF EXISTS "Product";
DROP TABLE IF EXISTS "Supplier";

CREATE TABLE "Card" (
    "@Card" serial PRIMARY KEY,
    "Number" varchar(19) NOT NULL,
    "FirstName" varchar(50) NOT NULL,
    "MiddleName" varchar(50),
    "LastName" varchar(50) NOT NULL,
    "BirthDate" date NOT NULL,
    "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
);
ALTER SEQUENCE "Card_@Card_seq" RESTART WITH 10000000;

CREATE TABLE "Check" (
    "@Check" serial PRIMARY KEY,
    "Card" INT NOT NULL,
    "CheckDate" timestamp NOT NULL,
    "Payed" BOOLEAN NOT NULL DEFAULT FALSE,
    "PaymentForm" INT CHECK ("PaymentForm" IN (1, 2)),
    "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE "Check"
   ADD CONSTRAINT "fk_Card"
   FOREIGN KEY ("Card")
   REFERENCES "Card"("@Card");

CREATE TABLE "Supplier" (
    "@Supplier" serial PRIMARY KEY,
    "Name" varchar(50) NOT NULL,
    "INN" varchar(30) NOT NULL,
    "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE "Product" (
    "@Product" serial PRIMARY KEY,
    "Name" varchar(50) NOT NULL,
    "VendorCode" varchar(30) NOT NULL,
    "Supplier" INT NOT NULL,
    "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
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
     "SetDate" timestamp NOT NULL,
     "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
     "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
 );

 ALTER TABLE "Price"
    ADD CONSTRAINT "fk_Product"
    FOREIGN KEY ("Product")
    REFERENCES "Product"("@Product");

CREATE TABLE "Product_Check" (
    "Product" int NOT NULL,
    "Check" int NOT NULL,
    "Price" float NOT NULL,
    "Count" int NOT NULL default 0,
    "CreateDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
    "ModifyDatetime" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE "Product_Check"
    ADD CONSTRAINT "fk_Product"
    FOREIGN KEY ("Product")
    REFERENCES "Product"("@Product");

ALTER TABLE "Product_Check"
    ADD CONSTRAINT "fk_Check"
    FOREIGN KEY ("Check")
    REFERENCES "Check"("@Check");


CREATE TRIGGER update_price
   BEFORE INSERT ON "Product_Check"
   FOR EACH ROW
   EXECUTE PROCEDURE update_price();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Product_Check"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Check"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Card"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Price"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Product"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();
CREATE TRIGGER update_modify_datetime
   BEFORE UPDATE OR INSERT ON "Supplier"
   FOR EACH ROW
   EXECUTE PROCEDURE update_modify_datetime();

CREATE OR REPLACE FUNCTION getNewProducts (startDate timestamp, endDate timestamp)
   RETURNS TABLE (
      "@Price" INT,
      "Cost" FLOAT,
      "CostSale" FLOAT,
      "SetDate" timestamp,
      "@Product" INT,
      "Name" varchar(50),
      "VendorCode" varchar(30),
      "@Supplier" INT,
      "SupplierName" varchar(50),
      "INN" varchar(30)
   )
AS $$
BEGIN
   RETURN QUERY
      SELECT
         price."@Price",
         price."Cost",
         price."CostSale",
         price."SetDate",
         product."@Product",
         product."Name",
         product."VendorCode",
         supplier."@Supplier",
         supplier."Name" AS "SupplierName",
         supplier."INN"
      FROM "Price" AS price
      INNER JOIN "Product" AS product
         ON price."Product" = product."@Product"
      INNER JOIN "Supplier" AS supplier
         ON product."Supplier" = supplier."@Supplier"
      WHERE product."CreateDatetime" >= startDate
         AND product."CreateDatetime" <= endDate;
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION getNewCards (startDate timestamp, endDate timestamp)
   RETURNS TABLE (
      "@Card" INT,
      "Number" varchar(19),
      "FirstName" varchar(50),
      "MiddleName" varchar(50),
      "LastName" varchar(50),
      "BirthDate" date
   )
AS $$
BEGIN
   RETURN QUERY
      SELECT
         _card."@Card",
         _card."Number",
         _card."FirstName",
         _card."MiddleName",
         _card."LastName",
         _card."BirthDate"
      FROM "Card" AS _card
      WHERE _card."ModifyDatetime" >= startDate
         AND _card."ModifyDatetime" <= endDate;
END;
$$ LANGUAGE 'plpgsql';

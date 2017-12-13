# -*- coding: utf-8 -*-
import sys
import codecs
if sys.stdout.encoding != 'cp850':
    sys.stdout = codecs.getwriter('utf8')(sys.stdout.buffer, 'strict')
import csv
from mimesis import Generic
from mimesis.builtins import RussiaSpecProvider
from datetime import datetime as dt
import random
import math


g = Generic('ru')
g.add_provider(RussiaSpecProvider)

def get_item(items_set, generator):
    def gen_item(items_set, generator):
        item = generator()
        if item in items_set:
            item = gen_item(items_set, generator)
        return item
    item = gen_item(items_set, generator)
    items_set.add(item)
    return item, items_set

def create_table_data(total_rows, table_name, fields, gen_rows):
    rows = gen_rows(total_rows)
    stmt = """INSERT INTO {table_name} ({fields})\nVALUES {values};""".format(
        table_name=table_name,
        fields=", ".join(['"{}"'.format(field) for field in fields]),
        values=',\n\t'.join(["({})".format(', '.join(row)) for row in rows])
    )
    return stmt;

def gen_card_number():
    return '4{}'.format(' '.join([
        g.code.custom_code(mask='###'),
        g.code.custom_code(mask='####'),
        g.code.custom_code(mask='####'),
        g.code.custom_code(mask='####')
    ]))

def gen_person():
    gender_value = ('male', 'female')[random.randint(0, 1)]
    return (
        g.personal.name(gender=gender_value),
        g.russia_provider.patronymic(gender=gender_value),
        g.personal.surname(gender=gender_value),
        g.datetime.date(start=1950, end=2001, fmt='%Y-%m-%d')
    )

def gen_inn():
    return ''.join(['78', g.code.custom_code(mask='####'), g.code.custom_code(mask='####')])

def gen_vendor_code():
    return ''.join(['7', g.code.custom_code(mask='###'), g.code.custom_code(mask='###'), g.code.custom_code(mask='###')])
    
def gen_product_name():
    product_types = (
        g.food.spices,
        g.food.dish,
        g.food.drink,
        g.food.fruit,
        g.food.vegetable
    )
    return product_types[random.randint(0, len(product_types) - 1)]()

def gen_table_card_rows(total_rows):
    rows = []
    card_numbers = set()
    persons = set()
    for _ in range(total_rows):
        person, persons = get_item(persons, gen_person)
        card_number, card_numbers = get_item(card_numbers, gen_card_number)
        rows.append(["'{}'".format(v) for v in [card_number] + list(person)])
    return rows

def gen_table_check_rows(total_rows):
    rows = []
    for _ in range(total_rows):
        row = [
            random.randint(1, 100),
            ' '.join([g.datetime.date(start=2017, end=2017, fmt='%Y-%m-%d'), g.datetime.time(fmt='%H:%M:%S.%f')]),
            'TRUE',
            random.randint(1, 2)
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

def gen_table_supplier_rows(total_rows):
    rows = []
    company_set = set()
    inn_set = set()
    for _ in range(total_rows):
        company, company_set = get_item(company_set, g.business.company)
        inn, inn_set = get_item(inn_set, gen_inn)
        row = [
            company,
            inn
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

def gen_table_product_rows(total_rows):
    rows = []
    name_set = set()
    vendor_code_set = set()
    for _ in range(total_rows):
        vendor_code, vendor_code_set = get_item(vendor_code_set, gen_vendor_code)
        row = [
            gen_product_name(),
            vendor_code,
            random.randint(1, 50)
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

def gen_table_price_rows(total_rows):
    rows = []
    product_total = 200
    for product_id in range(1, product_total + 1):
        price = g.business.price()
        price_value = float(price.split(' ')[0])
        row = [
            product_id,
            price_value,
            '{:.2f}'.format(price_value * random.randint(10, 80) / 100.0),
            '2017-01-01'
        ]
        rows.append(["'{}'".format(v) for v in row])
    for _ in range(total_rows - product_total):
        price = g.business.price()
        price_value = float(price.split(' ')[0])
        row = [
            random.randint(1, 200),
            price_value,
            '{:.2f}'.format(price_value * random.randint(10, 80) / 100.0),
            g.datetime.date(start=2017, end=2017, fmt='%Y-%m-%d')
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

def gen_table_product_check_rows(total_rows):
    rows = []
    for _ in range(total_rows):
        row = [
            random.randint(1, 200),
            random.randint(1, 500),
            0.0,
            random.randint(1, 5)
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

def gen_table_store_rows(total_rows):
    rows = []
    filial_set = ['Восток', 'Запад', 'Юг']
    address_set = set()

    for _ in range(total_rows):
        company = filial_set[_]
        address, address_set = get_item(address_set, g.address.address)
        row = [
            company,
            address
        ]
        rows.append(["'{}'".format(v) for v in row])
    return rows

# file = codecs.open("data.sql", "w", "utf-8")
# file.write('SET search_path = "shop";\n')

# file.write(create_table_data(100, '"Card"', ["Number", "FirstName", "MiddleName", "LastName", "BirthDate"], gen_table_card_rows))

# file.write(create_table_data(500, '"Check"', ["Card", "CheckDate", "Payed", "PaymentForm"], gen_table_check_rows))

# file.write(create_table_data(50, '"Supplier"', ["Name", "INN"], gen_table_supplier_rows))

# file.write(create_table_data(200, '"Product"', ["Name", "VendorCode", "Supplier"], gen_table_product_rows))

# file.write(create_table_data(300, '"Price"', ["Product", "Cost", "CostSale", "SetDate"], gen_table_price_rows))

# file.write(create_table_data(200, '"Product_Check"', ["Product", "Check", "Price", "Count"], gen_table_product_check_rows))
# file.close()


file = codecs.open("data-wharehouse.sql", "w", "utf-8")
file.write('SET search_path = "warehouse";\n')
file.write(create_table_data(3, '"Store"', ["Name", "Address"], gen_table_store_rows))

file.close()
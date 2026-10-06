-- Script de inicializacion de la base de datos del microservicio de productos.
-- Base de datos: products_db

CREATE DATABASE IF NOT EXISTS products_db;
USE products_db;

CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    quantity INT NOT NULL
);

INSERT INTO products (name, price, quantity) VALUES
    ('Laptop Lenovo ThinkPad', 3500.00, 10),
    ('Mouse inalambrico Logitech', 25.50, 50),
    ('Teclado mecanico Redragon', 120.00, 30);

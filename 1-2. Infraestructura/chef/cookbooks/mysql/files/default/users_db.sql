-- Script de inicializacion de la base de datos del microservicio de usuarios.
-- Base de datos: users_db

CREATE DATABASE IF NOT EXISTS users_db;
USE users_db;

CREATE TABLE IF NOT EXISTS users (
    id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name varchar(255),
    email varchar(255),
    username varchar(255),
    password varchar(255)
);

INSERT INTO users (name, email, username, password) VALUES
    ("juan", "juan@gmail.com", "juan", "123"),
    ("maria", "maria@gmail.com", "maria", "456");

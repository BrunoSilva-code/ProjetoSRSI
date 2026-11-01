-- Base de dados ficticia do laboratorio (dados nao reais)
CREATE DATABASE IF NOT EXISTS loja;
USE loja;

CREATE TABLE IF NOT EXISTS clientes (
    id    INT,
    nome  VARCHAR(50),
    saldo DECIMAL(10,2)
);

INSERT INTO clientes VALUES
    (1, 'Ana',   100.00),
    (2, 'Bruno', 250.00);

-- Utilizador que se pode ligar de qualquer maquina da rede do lab ('%')
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'senha123';
GRANT ALL ON loja.* TO 'app'@'%';
FLUSH PRIVILEGES;

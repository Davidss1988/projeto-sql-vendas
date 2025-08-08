CREATE DATABASE IF NOT EXISTS sistema_vendas;
USE sistema_vendas;

-- Tabela fornecedores
CREATE TABLE fornecedores (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  contato VARCHAR(100),
  telefone VARCHAR(20)
);

-- Tabela categorias de produtos
CREATE TABLE categorias_produtos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(50) NOT NULL UNIQUE
);

-- Tabela produtos
CREATE TABLE produtos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  descricao TEXT,
  preco_unitario DECIMAL(10,2) NOT NULL,
  estoque_atual INT DEFAULT 0,
  id_fornecedor INT,
  FOREIGN KEY (id_fornecedor) REFERENCES fornecedores(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

-- Tabela produtos_categorias (relacionamento N:N)
CREATE TABLE produtos_categorias (
  id_produto INT,
  id_categoria INT,
  PRIMARY KEY(id_produto, id_categoria),
  FOREIGN KEY (id_produto) REFERENCES produtos(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_categoria) REFERENCES categorias_produtos(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- Tabela clientes
CREATE TABLE clientes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE,
  telefone VARCHAR(20),
  endereco VARCHAR(255)
);

-- Tabela funcionarios
CREATE TABLE funcionarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(100) NOT NULL,
  cargo VARCHAR(50),
  email VARCHAR(100) UNIQUE
);

-- Tabela departamentos
CREATE TABLE departamentos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(50) NOT NULL UNIQUE
);

-- Relação funcionarios_departamentos
CREATE TABLE funcionarios_departamentos (
  id_funcionario INT,
  id_departamento INT,
  PRIMARY KEY (id_funcionario, id_departamento),
  FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_departamento) REFERENCES departamentos(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

-- Tabela vendas
CREATE TABLE vendas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  id_cliente INT,
  data_venda DATETIME DEFAULT CURRENT_TIMESTAMP,
  total_venda DECIMAL(12,2) NOT NULL DEFAULT 0,
  FOREIGN KEY (id_cliente) REFERENCES clientes(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

-- Itens da venda
CREATE TABLE itens_venda (
  id INT AUTO_INCREMENT PRIMARY KEY,
  id_venda INT,
  id_produto INT,
  quantidade INT NOT NULL,
  preco_unitario DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (id_venda) REFERENCES vendas(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (id_produto) REFERENCES produtos(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

-- Movimentações de estoque
CREATE TABLE estoque_movimentacoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  id_produto INT,
  quantidade INT NOT NULL,
  tipo_movimentacao VARCHAR(20), -- "entrada" ou "saida"
  data_movimentacao DATETIME DEFAULT CURRENT_TIMESTAMP,
  id_funcionario INT,
  FOREIGN KEY (id_produto) REFERENCES produtos(id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id)
    ON DELETE SET NULL
    ON UPDATE CASCADE
);

-- Índices
CREATE INDEX idx_produtos_nome ON produtos(nome);
CREATE INDEX idx_clientes_nome ON clientes(nome);
CREATE INDEX idx_vendas_data ON vendas(data_venda);

-- Procedure para registrar venda
DELIMITER $$
CREATE PROCEDURE registrar_venda(
  IN p_id_cliente INT,
  IN p_itens JSON
)
BEGIN
  DECLARE v_total DECIMAL(12,2) DEFAULT 0;
  DECLARE v_id_venda INT;
  DECLARE i INT DEFAULT 0;
  DECLARE qtd INT;
  DECLARE prod_id INT;
  DECLARE preco DECIMAL(10,2);

  -- Inserir venda
  INSERT INTO vendas (id_cliente, total_venda) VALUES (p_id_cliente, 0);
  SET v_id_venda = LAST_INSERT_ID();

  -- Loop nos itens do JSON
  WHILE i < JSON_LENGTH(p_itens) DO
    SET prod_id = JSON_UNQUOTE(JSON_EXTRACT(p_itens, CONCAT('$[', i, '].id_produto')));
    SET qtd = JSON_UNQUOTE(JSON_EXTRACT(p_itens, CONCAT('$[', i, '].quantidade')));

    SELECT preco_unitario INTO preco FROM produtos WHERE id = prod_id;

    INSERT INTO itens_venda (id_venda, id_produto, quantidade, preco_unitario)
    VALUES (v_id_venda, prod_id, qtd, preco);

    SET v_total = v_total + (preco * qtd);

    UPDATE produtos SET estoque_atual = estoque_atual - qtd WHERE id = prod_id;

    INSERT INTO estoque_movimentacoes (id_produto, quantidade, tipo_movimentacao)
    VALUES (prod_id, qtd, 'saida');

    SET i = i + 1;
  END WHILE;

  UPDATE vendas SET total_venda = v_total WHERE id = v_id_venda;
END$$
DELIMITER ;

-- Views
CREATE VIEW vw_estoque_baixo AS
SELECT id, nome, estoque_atual
FROM produtos
WHERE estoque_atual <= 5;

CREATE VIEW vw_vendas_diarias AS
SELECT DATE(data_venda) AS data, SUM(total_venda) AS total_dia, COUNT(id) AS total_vendas
FROM vendas
GROUP BY DATE(data_venda);

CREATE VIEW vw_produtos_mais_vendidos_mes AS
SELECT p.id, p.nome, SUM(iv.quantidade) AS total_vendido
FROM itens_venda iv
JOIN produtos p ON iv.id_produto = p.id
JOIN vendas v ON iv.id_venda = v.id
WHERE MONTH(v.data_venda) = MONTH(CURRENT_DATE())
GROUP BY p.id, p.nome
ORDER BY total_vendido DESC;





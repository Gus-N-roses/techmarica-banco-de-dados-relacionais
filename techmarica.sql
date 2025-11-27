
CREATE DATABASE IF NOT EXISTS techmarica;
USE techmarica;

-- TABELA FUNCIONARIO

CREATE TABLE funcionario (
    id_funcionario INT AUTO_INCREMENT PRIMARY KEY,
    nome           VARCHAR(100) NOT NULL,
    area_atuacao   VARCHAR(100) NOT NULL,
    ativo          TINYINT(1) NOT NULL DEFAULT 1,
    data_admissao  DATE NOT NULL,
    CONSTRAINT uq_funcionario_nome_area UNIQUE (nome, area_atuacao)
);
-- TABELA MAQUINA

CREATE TABLE maquina (
    id_maquina INT AUTO_INCREMENT PRIMARY KEY,
    codigo_maquina VARCHAR(20) NOT NULL,
    descricao      VARCHAR(150) NOT NULL,
    setor          VARCHAR(100) NOT NULL,
    ativa          TINYINT(1) NOT NULL DEFAULT 1,
    CONSTRAINT uq_maquina_codigo UNIQUE (codigo_maquina)
);

-- TABELA PRODUTO

CREATE TABLE produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    codigo_interno VARCHAR(20) NOT NULL,
    nome_comercial VARCHAR(100) NOT NULL,
    id_responsavel_tecnico INT NOT NULL,
    custo_producao DECIMAL(10,2) NOT NULL,
    data_criacao_catalogo DATE NOT NULL,
    CONSTRAINT uq_produto_codigo UNIQUE (codigo_interno),
    CONSTRAINT fk_produto_responsavel
        FOREIGN KEY (id_responsavel_tecnico)
        REFERENCES funcionario(id_funcionario)
);

-- TABELA ORDEM DE PRODUÇÃO

CREATE TABLE ordem_producao (
    id_ordem INT AUTO_INCREMENT PRIMARY KEY,
    id_produto INT NOT NULL,
    id_funcionario_autorizou INT NOT NULL,
    id_maquina INT NOT NULL,
    quantidade INT NOT NULL,
    data_inicio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_conclusao DATETIME NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'EM PRODUCAO',
    CONSTRAINT fk_op_produto FOREIGN KEY (id_produto) 
        REFERENCES produto(id_produto),
    CONSTRAINT fk_op_func FOREIGN KEY (id_funcionario_autorizou)
        REFERENCES funcionario(id_funcionario),
    CONSTRAINT fk_op_maquina FOREIGN KEY (id_maquina)
        REFERENCES maquina(id_maquina)
);

-- INSERÇÃO DE FUNCIONÁRIOS

INSERT INTO funcionario (nome, area_atuacao, ativo, data_admissao) VALUES
('Ana Luiza Campos', 'Engenharia de Produção', 1, '2018-03-10'),
('Bruno Santos', 'Manutenção', 1, '2020-07-01'),
('Carla Menezes', 'Qualidade', 1, '2019-11-25'),
('Diego Oliveira', 'Engenharia Eletrônica', 0, '2016-05-15'),
('Eduarda Marinho', 'Logística', 1, '2022-01-05'),
('Felipe Braga', 'Engenharia Eletrônica', 1, '2021-09-01');

-- INSERÇÃO DE MÁQUINAS

INSERT INTO maquina (codigo_maquina, descricao, setor, ativa) VALUES
('MC-SMT-01', 'Linha SMT Alta Precisão', 'Montagem de Placas', 1),
('MC-TEST-01','Bancada de Teste Automatizado','Teste', 1),
('MC-SOLD-01','Estação de Solda Reflow','Soldagem', 1);

-- INSERÇÃO DE PRODUTOS

INSERT INTO produto
(codigo_interno, nome_comercial, id_responsavel_tecnico, custo_producao, data_criacao_catalogo)
VALUES
('P-SENS-001', 'Sensor de Temperatura WiFi',        1, 75.50, '2020-02-10'),
('P-PLACA-010','Placa Controladora Industrial',     4, 230.00, '2019-06-01'),
('P-MOD-INT-5','Módulo IoT Inteligente 5G',         1, 310.90, '2021-09-15'),
('P-SENS-002', 'Sensor de Umidade LoRaWAN',         6, 88.00, '2022-03-01'),
('P-GATE-001','Gateway de Comunicação Industrial',  4, 560.00, '2018-11-20');

-- INSERÇÃO DE ORDENS DE PRODUÇÃO

INSERT INTO ordem_producao
(id_produto, id_funcionario_autorizou, id_maquina, quantidade, data_inicio, data_conclusao, status)
VALUES
(1, 1, 1, 500, '2024-10-10 08:00:00', '2024-10-11 16:30:00', 'FINALIZADA'),
(2, 4, 2, 120, '2024-10-12 09:15:00', NULL, 'EM PRODUCAO'),
(3, 1, 1, 300, '2024-10-13 07:50:00', '2024-10-14 18:10:00', 'FINALIZADA'),
(4, 6, 3, 1000, '2024-10-15 10:00:00', NULL, 'EM PRODUCAO'),
(5, 1, 2, 200, '2024-10-16 13:20:00', NULL, 'PENDENTE');

-- CONSULTAS PEDIDAS NA PROVA

-- 1) Listagem completa das ordens
SELECT
    op.id_ordem, op.data_inicio, op.data_conclusao, op.status, op.quantidade,
    p.nome_comercial, p.codigo_interno,
    m.codigo_maquina,
    f.nome AS funcionario_autorizou
FROM ordem_producao op
JOIN produto p ON op.id_produto = p.id_produto
JOIN maquina m ON op.id_maquina = m.id_maquina
JOIN funcionario f ON op.id_funcionario_autorizou = f.id_funcionario;

-- 2) Funcionários inativos
SELECT * FROM funcionario WHERE ativo = 0;

-- 3) Total de produtos por responsável técnico
SELECT f.nome, COUNT(p.id_produto) AS total_produtos
FROM funcionario f
LEFT JOIN produto p ON p.id_responsavel_tecnico = f.id_funcionario
GROUP BY f.nome;

-- 4) Produtos que começam com "S"
SELECT * FROM produto WHERE nome_comercial LIKE 'S%';

-- 5) Idade do produto em anos
SELECT 
    nome_comercial,
    TIMESTAMPDIFF(YEAR, data_criacao_catalogo, CURDATE()) AS idade_anos
FROM produto;

-- VIEW CONSOLIDADA

CREATE OR REPLACE VIEW vw_resumo_producao AS
SELECT
    op.id_ordem,
    op.status,
    op.data_inicio,
    op.data_conclusao,
    p.nome_comercial,
    p.codigo_interno,
    p.custo_producao,
    m.codigo_maquina,
    f.nome AS funcionario_autorizou,
    TIMESTAMPDIFF(DAY, op.data_inicio, IFNULL(op.data_conclusao, NOW())) AS dias_desde_inicio
FROM ordem_producao op
JOIN produto p ON op.id_produto = p.id_produto
JOIN maquina m ON op.id_maquina = m.id_maquina
JOIN funcionario f ON op.id_funcionario_autorizou = f.id_funcionario;

-- STORED PROCEDURE

DELIMITER $$

CREATE PROCEDURE sp_registrar_ordem_producao (
    IN p_id_produto INT,
    IN p_id_funcionario INT,
    IN p_id_maquina INT,
    IN p_quantidade INT
)
BEGIN
    INSERT INTO ordem_producao
    (id_produto, id_funcionario_autorizou, id_maquina, quantidade, data_inicio, status)
    VALUES
    (p_id_produto, p_id_funcionario, p_id_maquina, p_quantidade, NOW(), 'EM PRODUCAO');

    SELECT CONCAT('Ordem criada com sucesso! ID: ', LAST_INSERT_ID()) AS mensagem;
END$$

DELIMITER ;

-- TRIGGER

DELIMITER $$

CREATE TRIGGER trg_status_finalizada
BEFORE UPDATE ON ordem_producao
FOR EACH ROW
BEGIN
    IF OLD.data_conclusao IS NULL AND NEW.data_conclusao IS NOT NULL THEN
        SET NEW.status = 'FINALIZADA';
    END IF;
END$$

DELIMITER ;

ALTER TABLE maquina
ADD COLUMN observacoes VARCHAR(200) NULL AFTER setor;

-- UPDATE: tornar funcionário inativo
UPDATE funcionario
SET ativo = 0
WHERE id_funcionario = 2;

-- UPDATE: aumentar custo de produção em 10%
UPDATE produto
SET custo_producao = custo_producao * 1.10
WHERE codigo_interno = 'P-SENS-001';

-- DELETE: criando ordem de teste e removendo
INSERT INTO ordem_producao
(id_produto, id_funcionario_autorizou, id_maquina, quantidade, data_inicio, status)
VALUES
(1, 1, 1, 10, NOW(), 'EM PRODUCAO');

SET @id_teste := LAST_INSERT_ID();

DELETE FROM ordem_producao
WHERE id_ordem = @id_teste;

-- FUNÇÕES DE TEXTO + AGREGAÇÃO

SELECT
    UPPER(p.nome_comercial) AS nome_maiusculo,
    p.codigo_interno,
    COUNT(op.id_ordem) AS total_ordens
FROM produto p
LEFT JOIN ordem_producao op ON op.id_produto = p.id_produto
GROUP BY p.id_produto, p.nome_comercial, p.codigo_interno
ORDER BY total_ordens DESC;

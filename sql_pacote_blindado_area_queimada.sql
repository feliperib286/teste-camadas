
-- ============================================
-- PACOTE BLINDADO COMPLETO - AREA QUEIMADA
-- ============================================

-- 1️⃣ Criação das tabelas auxiliares (Estados e Biomas)
CREATE TABLE IF NOT EXISTS Estados (
    id_estado INT PRIMARY KEY,
    estado VARCHAR(100)
);

INSERT INTO Estados (id_estado, estado) VALUES
    (11, 'Rondônia'), (12, 'Acre'), (13, 'Amazonas'), (14, 'Roraima'),
    (15, 'Pará'), (16, 'Amapá'), (17, 'Tocantins'), (21, 'Maranhão'),
    (22, 'Piauí'), (23, 'Ceará'), (24, 'Rio Grande do Norte'), 
    (25, 'Paraíba'), (26, 'Pernambuco'), (27, 'Alagoas'), (28, 'Sergipe'), 
    (29, 'Bahia'), (31, 'Minas Gerais'), (32, 'Espírito Santo'), 
    (33, 'Rio de Janeiro'), (35, 'São Paulo'), (41, 'Paraná'), 
    (42, 'Santa Catarina'), (43, 'Rio Grande do Sul'), (50, 'Mato Grosso do Sul'), 
    (51, 'Mato Grosso'), (52, 'Goiás'), (53, 'Distrito Federal')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS Bioma (
    id INT PRIMARY KEY,
    bioma VARCHAR(100)
);

INSERT INTO Bioma (id, bioma) VALUES
    (1, 'Amazônia'), (2, 'Caatinga'), (3, 'Cerrado'),
    (4, 'Mata Atlântica'), (5, 'Pampa'), (6, 'Pantanal')
ON CONFLICT DO NOTHING;

-- 2️⃣ Criação da tabela principal Area_Queimada (PONTOS)
CREATE TABLE IF NOT EXISTS Area_Queimada (
    id SERIAL PRIMARY KEY,
    estado_id INT REFERENCES Estados(id_estado),
    bioma_id INT REFERENCES Bioma(id),
    data_pas DATE NOT NULL,
    risco DECIMAL(15,2),
    frp DECIMAL(7,2),
    geom GEOMETRY(Point, 4326),
    satelite VARCHAR(50),
    tipo VARCHAR(20) DEFAULT 'area_queimada',
    CONSTRAINT chk_tipo_area_queimada CHECK (tipo IN ('area_queimada'))
);

-- 3️⃣ Criação da tabela de polígonos (Poligonos serão sempre gerados depois)
CREATE TABLE IF NOT EXISTS Area_Queimada_Poligono_Diario (
    id SERIAL PRIMARY KEY,
    data_pas DATE NOT NULL,
    estado_id INT REFERENCES Estados(id_estado),
    cluster_id INT,
    poligono GEOMETRY(Polygon, 4326)
);

-- 4️⃣ Limpeza de dados antigos (opcional - para evitar duplicações)
TRUNCATE TABLE Area_Queimada;
TRUNCATE TABLE Area_Queimada_Poligono_Diario;

-- 5️⃣ Neste ponto, após executar esse SQL:
-- ✅ Você insere normalmente os 5486 registros no Area_Queimada usando seu arquivo já pronto.

-- 6️⃣ Após carregar os dados, execute o bloco abaixo para gerar os polígonos:

WITH pontos AS (
  SELECT id, data_pas, estado_id, geom
  FROM Area_Queimada
),
clusters AS (
  SELECT
    id,
    data_pas,
    estado_id,
    ST_ClusterDBSCAN(geom, eps := 0.05, minpoints := 3) OVER (
      PARTITION BY data_pas, estado_id
    ) AS cluster_id,
    geom
  FROM pontos
),
poligonos AS (
  SELECT
    data_pas,
    estado_id,
    cluster_id,
    ST_ConvexHull(ST_Collect(geom)) AS poligono
  FROM clusters
  WHERE cluster_id IS NOT NULL
  GROUP BY data_pas, estado_id, cluster_id
)
INSERT INTO Area_Queimada_Poligono_Diario (data_pas, estado_id, cluster_id, poligono)
SELECT data_pas, estado_id, cluster_id, poligono
FROM poligonos;

-- ============================================
-- FIM DO PACOTE BLINDADO COMPLETO
-- ============================================

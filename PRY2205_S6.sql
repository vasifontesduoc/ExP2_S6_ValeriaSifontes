-- =========================================================================
-- soluciones a los casos semana 6
-- Valeria Sifontes
-- =========================================================================

-- ---------------------------------------------------------------------------
-- CASO 1
-- reportería de asesorías
-- ---------------------------------------------------------------------------

SELECT
    p.id_profesional AS ID,
    INITCAP(p.appaterno) || ', ' || INITCAP(p.apmaterno) || ', ' || INITCAP(p.nombre) AS PROFESIONAL, 
    NVL(B.NRO_ASESORIA_BANCA, 0) AS "NRO ASESORIA BANCA", 
    TO_CHAR(NVL(B.MONTO_TOTAL_BANCA, 0), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''') AS MONTO_TOTAL_BANCA,
    NVL(R.NRO_ASESORIA_RETAIL, 0) AS "NRO ASESORIA RETAIL",
    TO_CHAR(NVL(R.MONTO_TOTAL_RETAIL, 0), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''') AS MONTO_TOTAL_RETAIL,
    NVL(B.NRO_ASESORIA_BANCA, 0) + NVL(R.NRO_ASESORIA_RETAIL, 0) AS "TOTAL ASESORIAS",
    TO_CHAR(
    NVL(B.MONTO_TOTAL_BANCA, 0) + NVL(R.MONTO_TOTAL_RETAIL, 0),
    '$999G999G999',
    'NLS_NUMERIC_CHARACTERS = '',.'''
    ) AS "TOTAL HONORARIOS"

FROM profesional p

-- 1. subconsulta para encontrar ids que tienen asesorías en banca y retail
JOIN (
    SELECT id_profesional
    FROM (
        -- ids en banca
        SELECT id_profesional FROM asesoria a JOIN empresa e ON a.cod_empresa = e.cod_empresa WHERE e.cod_sector = 3
        INTERSECT 
        -- ids en retail
        SELECT id_profesional FROM asesoria a JOIN empresa e ON a.cod_empresa = e.cod_empresa WHERE e.cod_sector = 4
    )
) PROF_VERSATIL ON p.id_profesional = PROF_VERSATIL.id_profesional

-- 2. subconsulta para los detalles de banca
LEFT JOIN (
    SELECT
        a.id_profesional,
        COUNT(a.honorario) AS NRO_ASESORIA_BANCA, 
        ROUND(SUM(a.honorario)) AS MONTO_TOTAL_BANCA 
    FROM asesoria a
    JOIN empresa e ON a.cod_empresa = e.cod_empresa
    WHERE e.cod_sector = 3
    GROUP BY a.id_profesional
) B ON p.id_profesional = B.id_profesional

-- 3. subconsulta para los detalles de retail
LEFT JOIN (
    SELECT
        a.id_profesional,
        COUNT(a.honorario) AS NRO_ASESORIA_RETAIL, 
        ROUND(SUM(a.honorario)) AS MONTO_TOTAL_RETAIL 
    FROM asesoria a
    JOIN empresa e ON a.cod_empresa = e.cod_empresa
    WHERE e.cod_sector = 4
    GROUP BY a.id_profesional
) R ON p.id_profesional = R.id_profesional
ORDER BY 1; -- se ordena por id ascendente

-- ---------------------------------------------------------------------------
-- CASO 2 
-- resumen de honorarios
-- ---------------------------------------------------------------------------

-- eliminamos la tabla
DROP TABLE REPORTE_MES CASCADE CONSTRAINTS;

-- creación de la tabla REPORTE_MES 
CREATE TABLE REPORTE_MES AS
SELECT
    p.id_profesional AS ID_PROF,
    INITCAP(p.appaterno) || ', ' || INITCAP(p.apmaterno) || ', ' || INITCAP(p.nombre) AS NOMBRE_COMPLETO, 
    INITCAP(pr.nombre_profesion) AS NOMBRE_PROFESION,
    INITCAP(c.nom_comuna) AS NOM_COMUNA,
    COUNT(a.honorario) AS NRO_ASESORIAS, 
    TO_CHAR(ROUND(SUM(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS MONTO_TOTAL_HONORARIOS,
    TO_CHAR(ROUND(AVG(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS PROMEDIO_HONORARIO,
    TO_CHAR(ROUND(MIN(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS HONORARIO_MINIMO,
    TO_CHAR(ROUND(MAX(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS HONORARIO_MAXIMO
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
JOIN profesion pr ON p.cod_profesion = pr.cod_profesion
JOIN comuna c ON p.cod_comuna = c.cod_comuna
WHERE TO_CHAR(a.fin_asesoria, 'MM/YYYY') = '04/' || (EXTRACT(YEAR FROM SYSDATE) - 1)
GROUP BY
    p.id_profesional,
    p.appaterno,
    p.apmaterno,
    p.nombre,
    pr.nombre_profesion,
    c.nom_comuna
ORDER BY ID_PROF ASC; -- se ordena por id ascendente

SELECT * FROM REPORTE_MES;

-- ---------------------------------------------------------------------------
-- CASO 3 
-- modificación de honorarios
-- ---------------------------------------------------------------------------

-- el id, sueldo actual y el total de honorarios acumulados en marzo del año pasado
SELECT
    p.id_profesional AS ID_PROFESIONAL,
    TO_CHAR(p.sueldo, '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS SUELDO_ACTUAL,
    TO_CHAR(ROUND(SUM(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS HONORARIO_ACUMULADO_MARZO_ANIO_PASADO
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
WHERE TO_CHAR(a.fin_asesoria, 'MM/YYYY') = '03/' || (EXTRACT(YEAR FROM SYSDATE) - 1) 
GROUP BY
    p.id_profesional,
    p.sueldo
ORDER BY 1;

-- actualización del sueldo / update
UPDATE profesional p
SET p.sueldo = (
    -- subconsulta para calcular el nuevo sueldo basado en el total de honorarios de marzo
    SELECT
        ROUND(
            CASE 
                WHEN H.HONORARIO_TOTAL < 1000000 THEN p.sueldo * 1.10 -- el 10%
                ELSE p.sueldo * 1.15 -- el 15%
            END
        )
    FROM (
        -- subconsulta para obtener el total de honorarios acumulados en marzo del año pasado por profesional
        SELECT
            id_profesional,
            SUM(honorario) AS HONORARIO_TOTAL 
        FROM asesoria
        WHERE TO_CHAR(fin_asesoria, 'MM/YYYY') = '03/' || (EXTRACT(YEAR FROM SYSDATE) - 1) 
        GROUP BY id_profesional
    ) H
    WHERE H.id_profesional = p.id_profesional
)
-- aquí restringe la actualización solo a los profesionales que finalizaron asesorías en el mes especificado
WHERE p.id_profesional IN (
    SELECT DISTINCT id_profesional
    FROM asesoria
    WHERE TO_CHAR(fin_asesoria, 'MM/YYYY') = '03/' || (EXTRACT(YEAR FROM SYSDATE) - 1) 
);

COMMIT;

-- reporte después de la modificación
-- se muestra el id, sueldo nuevo y el total de honorarios acumulados en marzo del año pasado para verificar los cambios
SELECT
    p.id_profesional AS ID_PROFESIONAL,
    TO_CHAR(p.sueldo, '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS SUELDO_NUEVO,
    TO_CHAR(ROUND(SUM(a.honorario)), '$999G999G999', 'NLS_NUMERIC_CHARACTERS = '',.''' ) AS HONORARIO_ACUMULADO_MARZO_ANIO_PASADO
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
WHERE TO_CHAR(a.fin_asesoria, 'MM/YYYY') = '03/' || (EXTRACT(YEAR FROM SYSDATE) - 1)
GROUP BY
    p.id_profesional,
    p.sueldo
ORDER BY 1;

-- cierre de los 3 casos
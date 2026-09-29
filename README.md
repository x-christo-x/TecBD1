# Informe de Migración de Base de Datos: MariaDB a PostgreSQL

**Estudiante / Administrador:** Christopher  
**Fecha:** 28 de Septiembre de 2026  
**Proyecto:** Migración masiva de la base de datos de prueba `employees`  
**Tecnologías:** MariaDB 11.8, PostgreSQL 18.6, pgloader 3.6.10, Debian Linux

---

## 1. Resumen Ejecutivo
Se completó exitosamente el proceso de migración de la base de datos `employees` desde un servidor **MariaDB** local hacia un servidor de producción **PostgreSQL** (`pdb_employees`, IP `192.168.56.55`).

El procedimiento abarcó la migración masiva de esquemas y tablas mediante `pgloader`, la recreación funcional de vistas relacionales, la escritura de funciones almacenadas en **PL/pgSQL**, la verificación de la integridad referencial y financiera, y la generación de un respaldo físico final `.sql`.

---

## 2. Configuración del Archivo de Carga (`migracion.load`)

Para garantizar la estabilidad y rendimiento durante la transferencia de los 3.9 millones de registros, se configuró el archivo de definición de `pgloader` optimizando el paralelismo y ajustando los parámetros de memoria:

LOAD DATABASE
    FROM mysql://root:123456@localhost:3306/employees
    INTO postgresql://christopher:lotore@192.168.56.55:5432/pdb_employees

WITH include drop,
    create tables,
    create indexes,
    reset sequences,
    workers = 8, concurrency = 2,
    batch rows = 10000

SET maintenance_work_mem to '256MB',
    work_mem to '32MB'

CAST type datetime to timestamptz drop default drop not null using zero-dates-to-null,
     type enum to text
;

---

## 3. Ejecución y Logs de Migración Masiva (`pgloader`)

Se ejecutó la migración utilizando la configuración definida en `migracion.load`.

### Comando Ejecutado:
pgloader migracion.load

### Salida del Proceso:
2026-09-28T23:55:14.055999Z LOG pgloader version "3.6.10~devel"
2026-09-28T23:55:15.207978Z LOG Migrating from #<MYSQL-CONNECTION mysql://root@localhost:3306/employees {1006AC4A83}>
2026-09-28T23:55:15.207978Z LOG Migrating into #<PGSQL-CONNECTION pgsql://christopher@192.168.56.55:5432/pdb_employees {1006AC4C73}>
2026-09-28T23:57:07.190093Z LOG report summary reset
              table name     errors       rows      bytes      total time
-----------------------  ---------  ---------  ---------  --------------
        fetch meta data          0         21                     0.936s
         Create Schemas          0          0                     0.004s
       Create SQL Types          0          0                     0.020s
          Create tables          0         12                     0.816s
         Set Table OIDs          0          6                     0.032s
-----------------------  ---------  ---------  ---------  --------------
     employees.salaries          0    2844047    94.2 MB       1m35.586s
       employees.titles          0     443308    16.9 MB         23.112s
     employees.dept_emp          0     331603    10.7 MB         23.744s
  employees.departments          0          9     0.1 kB          2.512s
 employees.dept_manager          0         24     0.8 kB          0.076s
    employees.employees          0     300024    13.2 MB         16.584s
-----------------------  ---------  ---------  ---------  --------------
COPY Threads Completion          0          8                  1m35.566s
         Create Indexes          0          9                    18.264s
 Index Build Completion          0          9                     9.476s
        Reset Sequences          0          0                     0.408s
           Primary Keys          0          6                     0.028s
    Create Foreign Keys          0          6                     3.536s
        Create Triggers          0          0                     0.000s
        Set Search Path          0          1                     0.012s
       Install Comments          0          0                     0.000s
-----------------------  ---------  ---------  ---------  --------------
      Total import time          ✓    3919015   134.9 MB        2m7.290s

---

## 4. Verificación Inicial de Datos Importados

Conexión mediante `psql` para validar el conteo de registros por tabla principal en PostgreSQL:

### Comando Ejecutado:
psql -U christopher -d pdb_employees -h 192.168.56.55

SET search_path TO employees, public;

SELECT 'employees' AS tabla, COUNT(*) FROM employees.employees
UNION ALL
SELECT 'salaries', COUNT(*) FROM employees.salaries
UNION ALL
SELECT 'titles', COUNT(*) FROM employees.titles;

### Salida Obtenida:
   tabla   |  count  
-----------+---------
 employees |  300024
 salaries  | 2844047
 titles    |  443308
(3 filas)

---

## 5. Implementación de Objetos (Vistas y Funciones PL/pgSQL)

Se procedió a estructurar las vistas requeridas y adaptar la lógica procedural a funciones PostgreSQL.

### 5.1. Creación de Vistas
SET search_path TO employees, public;

CREATE OR REPLACE VIEW employees.dept_emp_latest_date AS
SELECT emp_no, MAX(from_date) AS max_from_date, MAX(to_date) AS max_to_date
FROM employees.dept_emp
GROUP BY emp_no;

CREATE OR REPLACE VIEW employees.current_dept_emp AS
SELECT l.emp_no, l.dept_no, l.from_date, l.to_date
FROM employees.dept_emp l
JOIN employees.dept_emp_latest_date d 
  ON l.emp_no = d.emp_no 
 AND l.from_date = d.max_from_date 
 AND l.to_date = d.max_to_date;

### 5.2. Creación de Funciones Almacenadas PL/pgSQL
CREATE OR REPLACE FUNCTION employees.get_fullname(p_emp_no BIGINT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$ DECLARE     v_fullname VARCHAR; BEGIN     SELECT CONCAT(first_name, ' ', last_name) INTO v_fullname     FROM employees.employees     WHERE emp_no = p_emp_no;          RETURN v_fullname; END; $$;

CREATE OR REPLACE FUNCTION employees.get_current_salary(p_emp_no BIGINT)
RETURNS INT
LANGUAGE plpgsql
AS $$ DECLARE     v_salary INT; BEGIN     SELECT salary INTO v_salary     FROM employees.salaries     WHERE emp_no = p_emp_no     ORDER BY to_date DESC     LIMIT 1;          RETURN COALESCE(v_salary, 0); END; $$;

### 5.3. Prueba de Integración
SELECT 
    e.emp_no,
    employees.get_fullname(e.emp_no) AS nombre_completo,
    c.dept_no,
    employees.get_current_salary(e.emp_no) AS salario_actual
FROM employees.employees e
JOIN employees.current_dept_emp c ON e.emp_no = c.emp_no
LIMIT 5;

### Salida Obtenida:
 emp_no |  nombre_completo  | dept_no | salario_actual 
--------+-------------------+---------+----------------
  10004 | Chirstian Koblick | d004    |          74057
  10018 | Kazuhide Peha     | d004    |          84672
  10020 | Mayuko Warwick    | d004    |          47017
  10025 | Prasadram Heyers  | d005    |          57157
  10027 | Divier Reistad    | d005    |          46145
(5 filas)

---

## 6. Pruebas de Integridad Referencial y Paridad de Datos

### 6.1. Búsqueda de Registros Huérfanos en PostgreSQL
SELECT 'salaries sin empleado' AS prueba, COUNT(*) AS inconsistencias
FROM employees.salaries s
LEFT JOIN employees.employees e ON s.emp_no = e.emp_no
WHERE e.emp_no IS NULL;

SELECT 'dept_emp sin departamento' AS prueba, COUNT(*) AS inconsistencias
FROM employees.dept_emp de
LEFT JOIN employees.departments d ON de.dept_no = d.dept_no
WHERE d.dept_no IS NULL;

### Salida Obtenida:
        prueba         | inconsistencias 
-----------------------+-----------------
 salaries sin empleado |               0
(1 fila)

          prueba           | inconsistencias 
---------------------------+-----------------
 dept_emp sin departamento |               0
(1 fila)

### 6.2. Verificación de Consistencia Financiera (MariaDB vs PostgreSQL)

**Consulta en MariaDB:**
mariadb -h 127.0.0.1 -u root -p123456

USE employees;
SELECT 
    COUNT(*) AS total_registros,
    SUM(salary) AS suma_total_salarios,
    ROUND(AVG(salary), 2) AS salario_promedio,
    MIN(salary) AS salario_minimo,
    MAX(salary) AS salario_maximo
FROM salaries;

### Salida Obtenida en MariaDB:
+-----------------+---------------------+------------------+----------------+----------------+
| total_registros | suma_total_salarios | salario_promedio | salario_minimo | salario_maximo |
+-----------------+---------------------+------------------+----------------+----------------+
|         2844047 |        181480757419 |         63810.74 |          38623 |         158220 |
+-----------------+---------------------+------------------+----------------+----------------+
1 row in set (6,995 sec)

**Consulta en PostgreSQL:**
SELECT 
    COUNT(*) AS total_registros,
    SUM(salary::bigint) AS suma_total_salarios,
    ROUND(AVG(salary), 2) AS salario_promedio,
    MIN(salary) AS salario_minimo,
    MAX(salary) AS salario_maximo
FROM employees.salaries;

### Salida Obtenida en PostgreSQL:
 total_registros | suma_total_salarios | salario_promedio | salario_minimo | salario_maximo 
-----------------+---------------------+------------------+----------------+----------------
         2844047 |        181480757419 |         63810.74 |          38623 |         158220 
(1 fila)

### Cuadro Comparativo de Paridad Exacta (100% Coincidencia):

| Métrica | MariaDB (Origen) | PostgreSQL (Destino) | Resultado |
| :--- | :--- | :--- | :--- |
| **Total de Registros** | `2,844,047` | `2,844,047` | Coincidencia exacta |
| **Suma Total Salarios**| `181,480,757,419` | `181,480,757,419` | Coincidencia exacta |
| **Promedio Salarial**  | `63,810.74` | `63,810.74` | Coincidencia exacta |
| **Salario Mínimo**     | `38,623` | `38,623` | Coincidencia exacta |
| **Salario Máximo**     | `158,220` | `158,220` | Coincidencia exacta |

---

## 7. Generación del Respaldo Final (`pg_dump`)

Se ejecutó la exportación de la base de datos migrada desde PostgreSQL hacia un archivo plano `.sql`:

### Comando Ejecutado:
pg_dump -U christopher -h 192.168.56.55 -d pdb_employees -n employees -F p -f dump_employees_postgresql.sql

---

## 8. Enlace de GitHub

[https://github.com/x-christo-x/TecBD1](https://github.com/x-christo-x/TecBD1)

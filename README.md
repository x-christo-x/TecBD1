# Informe de Migración de Base de Datos: MariaDB a PostgreSQL

| Campo | Detalle |
| :--- | :--- |
| **Docente** | Jared Lopez Leaños |
| **Estudiante** | Christopher Lotore Herrera |
| **Fecha** | 28 de septiembre de 2026 |
| **Proyecto** | Migración masiva de la base de datos de prueba `employees` |
| **Origen** | MariaDB 11.8 (local) |
| **Destino** | PostgreSQL 18.6 (`pdb_employees`, `192.168.56.55`) |
| **Herramientas** | pgloader 3.6.10, `psql`, `pg_dump`, Debian Linux |

---

## 1. Resumen Ejecutivo

Se completó exitosamente la migración de la base de datos `employees` desde un servidor **MariaDB** local hacia un servidor de producción **PostgreSQL** (`pdb_employees`, IP `192.168.56.55`).

El procedimiento abarcó:

1. Migración masiva de esquemas y tablas con `pgloader`.
2. Recreación funcional de las vistas relacionales.
3. Escritura de funciones almacenadas en **PL/pgSQL**.
4. Verificación de la integridad referencial y financiera.
5. Generación de un respaldo físico final en formato `.sql`.

---

## 2. Configuración del Archivo de Carga

Archivo: `migracion.load`. Para garantizar estabilidad y rendimiento durante la transferencia de 3.9 millones de registros, se optimizó el paralelismo y los parámetros de memoria.

```pgloader
LOAD DATABASE
    FROM mysql://<USUARIO_ORIGEN>:<CONTRASEÑA_ORIGEN>@localhost:3306/employees
    INTO postgresql://<USUARIO_DESTINO>:<CONTRASEÑA_DESTINO>@192.168.56.55:5432/pdb_employees

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
```

> **Nota:** las credenciales fueron reemplazadas por marcadores. Nunca se deben publicar contraseñas reales en un repositorio.

### Parámetros relevantes

| Parámetro | Valor | Propósito |
| :--- | :--- | :--- |
| `workers` | `8` | Hilos de trabajo en paralelo |
| `concurrency` | `2` | Concurrencia por tabla |
| `batch rows` | `10000` | Filas por lote de carga |
| `maintenance_work_mem` | `256MB` | Memoria para construcción de índices |
| `work_mem` | `32MB` | Memoria por operación de consulta |
| `datetime` → `timestamptz` | `zero-dates-to-null` | Convierte fechas cero a `NULL` |
| `enum` → `text` | — | Reemplaza tipos enumerados |

---

## 3. Ejecución y Logs de Migración Masiva

Se ejecutó la migración con la configuración definida en `migracion.load`.

### 3.1. Comando ejecutado

```bash
pgloader migracion.load
```

### 3.2. Salida del proceso

```text
2026-09-28T23:55:14.055999Z LOG pgloader version "3.6.10~devel"
2026-09-28T23:55:15.207978Z LOG Migrating from #<MYSQL-CONNECTION mysql://root@localhost:3306/employees {1006AC4A83}>
2026-09-28T23:55:15.207978Z LOG Migrating into #<PGSQL-CONNECTION pgsql://christopher@192.168.56.55:5432/pdb_employees {1006AC4C73}>
2026-09-28T23:57:07.190093Z LOG report summary reset
              table name     errors       rows      bytes      total time
-----------------------  ---------  ---------  ---------  --------------
        fetch meta data          0         21                     0.936s
         Create Schemas          0          0                     0.004s
       Create SQL Types          0          0                     0.020s
          Create tables          0         12                     0.816s
         Set Table OIDs          0          6                     0.032s
-----------------------  ---------  ---------  ---------  --------------
     employees.salaries          0    2844047    94.2 MB       1m35.586s
       employees.titles          0     443308    16.9 MB         23.112s
     employees.dept_emp          0     331603    10.7 MB         23.744s
  employees.departments          0          9     0.1 kB          2.512s
 employees.dept_manager          0         24     0.8 kB          0.076s
    employees.employees          0     300024    13.2 MB         16.584s
-----------------------  ---------  ---------  ---------  --------------
COPY Threads Completion          0          8                  1m35.566s
         Create Indexes          0          9                    18.264s
 Index Build Completion          0          9                     9.476s
        Reset Sequences          0          0                     0.408s
           Primary Keys          0          6                     0.028s
    Create Foreign Keys          0          6                     3.536s
        Create Triggers          0          0                     0.000s
        Set Search Path          0          1                     0.012s
       Install Comments          0          0                     0.000s
-----------------------  ---------  ---------  ---------  --------------
      Total import time          ✓    3919015   134.9 MB        2m7.290s
```

### 3.3. Resumen por tabla

| Tabla | Errores | Filas | Tamaño | Tiempo |
| :--- | ---: | ---: | ---: | ---: |
| `employees.salaries` | 0 | 2,844,047 | 94.2 MB | 1m 35.586s |
| `employees.titles` | 0 | 443,308 | 16.9 MB | 23.112s |
| `employees.dept_emp` | 0 | 331,603 | 10.7 MB | 23.744s |
| `employees.employees` | 0 | 300,024 | 13.2 MB | 16.584s |
| `employees.dept_manager` | 0 | 24 | 0.8 kB | 0.076s |
| `employees.departments` | 0 | 9 | 0.1 kB | 2.512s |
| **Total** | **0** | **3,919,015** | **134.9 MB** | **2m 7.290s** |

---

## 4. Verificación Inicial de Datos Importados

Conexión con `psql` para validar el conteo de registros de las tablas principales en PostgreSQL.

### 4.1. Conexión

```bash
psql -U christopher -d pdb_employees -h 192.168.56.55
```

### 4.2. Consulta

```sql
SET search_path TO employees, public;

SELECT 'employees' AS tabla, COUNT(*) FROM employees.employees
UNION ALL
SELECT 'salaries', COUNT(*) FROM employees.salaries
UNION ALL
SELECT 'titles', COUNT(*) FROM employees.titles;
```

### 4.3. Salida obtenida

```text
   tabla   |  count  
-----------+---------
 employees |  300024
 salaries  | 2844047
 titles    |  443308
(3 filas)
```

---

## 5. Implementación de Objetos (Vistas y Funciones PL/pgSQL)

Se estructuraron las vistas requeridas y se adaptó la lógica procedural a funciones de PostgreSQL.

### 5.1. Creación de vistas

```sql
SET search_path TO employees, public;

CREATE OR REPLACE VIEW employees.dept_emp_latest_date AS
SELECT emp_no,
       MAX(from_date) AS max_from_date,
       MAX(to_date)   AS max_to_date
FROM employees.dept_emp
GROUP BY emp_no;

CREATE OR REPLACE VIEW employees.current_dept_emp AS
SELECT l.emp_no, l.dept_no, l.from_date, l.to_date
FROM employees.dept_emp l
JOIN employees.dept_emp_latest_date d
  ON l.emp_no    = d.emp_no
 AND l.from_date = d.max_from_date
 AND l.to_date   = d.max_to_date;
```

### 5.2. Creación de funciones almacenadas

**Función `get_fullname`:** devuelve el nombre completo de un empleado.

```sql
CREATE OR REPLACE FUNCTION employees.get_fullname(p_emp_no BIGINT)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_fullname VARCHAR;
BEGIN
    SELECT CONCAT(first_name, ' ', last_name)
    INTO v_fullname
    FROM employees.employees
    WHERE emp_no = p_emp_no;

    RETURN v_fullname;
END;
$$;
```

**Función `get_current_salary`:** devuelve el salario más reciente (o `0` si no existe).

```sql
CREATE OR REPLACE FUNCTION employees.get_current_salary(p_emp_no BIGINT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_salary INT;
BEGIN
    SELECT salary
    INTO v_salary
    FROM employees.salaries
    WHERE emp_no = p_emp_no
    ORDER BY to_date DESC
    LIMIT 1;

    RETURN COALESCE(v_salary, 0);
END;
$$;
```

### 5.3. Prueba de integración

```sql
SELECT
    e.emp_no,
    employees.get_fullname(e.emp_no)       AS nombre_completo,
    c.dept_no,
    employees.get_current_salary(e.emp_no) AS salario_actual
FROM employees.employees e
JOIN employees.current_dept_emp c ON e.emp_no = c.emp_no
LIMIT 5;
```

**Salida obtenida:**

```text
 emp_no |  nombre_completo  | dept_no | salario_actual 
--------+-------------------+---------+----------------
  10004 | Chirstian Koblick | d004    |          74057
  10018 | Kazuhide Peha     | d004    |          84672
  10020 | Mayuko Warwick    | d004    |          47017
  10025 | Prasadram Heyers  | d005    |          57157
  10027 | Divier Reistad    | d005    |          46145
(5 filas)
```

---

## 6. Pruebas de Integridad Referencial y Paridad de Datos

### 6.1. Búsqueda de registros huérfanos en PostgreSQL

```sql
SELECT 'salaries sin empleado' AS prueba, COUNT(*) AS inconsistencias
FROM employees.salaries s
LEFT JOIN employees.employees e ON s.emp_no = e.emp_no
WHERE e.emp_no IS NULL;

SELECT 'dept_emp sin departamento' AS prueba, COUNT(*) AS inconsistencias
FROM employees.dept_emp de
LEFT JOIN employees.departments d ON de.dept_no = d.dept_no
WHERE d.dept_no IS NULL;
```

**Salida obtenida:**

```text
        prueba         | inconsistencias 
-----------------------+-----------------
 salaries sin empleado |               0
(1 fila)

          prueba           | inconsistencias 
---------------------------+-----------------
 dept_emp sin departamento |               0
(1 fila)
```

| Prueba | Inconsistencias | Resultado |
| :--- | ---: | :---: |
| Salarios sin empleado | 0 | OK |
| Asignaciones sin departamento | 0 | OK |

### 6.2. Verificación de consistencia financiera (MariaDB vs PostgreSQL)

#### Consulta en MariaDB

```bash
mariadb -h 127.0.0.1 -u root -p
```

```sql
USE employees;

SELECT
    COUNT(*)              AS total_registros,
    SUM(salary)           AS suma_total_salarios,
    ROUND(AVG(salary), 2) AS salario_promedio,
    MIN(salary)           AS salario_minimo,
    MAX(salary)           AS salario_maximo
FROM salaries;
```

**Salida obtenida en MariaDB:**

```text
+-----------------+---------------------+------------------+----------------+----------------+
| total_registros | suma_total_salarios | salario_promedio | salario_minimo | salario_maximo |
+-----------------+---------------------+------------------+----------------+----------------+
|         2844047 |        181480757419 |         63810.74 |          38623 |         158220 |
+-----------------+---------------------+------------------+----------------+----------------+
1 row in set (6,995 sec)
```

#### Consulta en PostgreSQL

```sql
SELECT
    COUNT(*)                AS total_registros,
    SUM(salary::bigint)     AS suma_total_salarios,
    ROUND(AVG(salary), 2)   AS salario_promedio,
    MIN(salary)             AS salario_minimo,
    MAX(salary)             AS salario_maximo
FROM employees.salaries;
```

**Salida obtenida en PostgreSQL:**

```text
 total_registros | suma_total_salarios | salario_promedio | salario_minimo | salario_maximo 
-----------------+---------------------+------------------+----------------+----------------
         2844047 |        181480757419 |         63810.74 |          38623 |         158220 
(1 fila)
```

#### Cuadro comparativo de paridad exacta

| Métrica | MariaDB (origen) | PostgreSQL (destino) | Resultado |
| :--- | ---: | ---: | :---: |
| **Total de registros** | `2,844,047` | `2,844,047` |  Coincidencia exacta |
| **Suma total de salarios** | `181,480,757,419` | `181,480,757,419` |  Coincidencia exacta |
| **Promedio salarial** | `63,810.74` | `63,810.74` |  Coincidencia exacta |
| **Salario mínimo** | `38,623` | `38,623` |  Coincidencia exacta |
| **Salario máximo** | `158,220` | `158,220` |  Coincidencia exacta |

---

## 7. Generación del Respaldo Final

Se generó el respaldo de la base migrada en dos formatos con `pg_dump`: **plano (`.sql`)** y **personalizado (`.dump`)**. Cada uno se restaura con una herramienta distinta.

| Formato | Opción `-F` | Extensión | Se restaura con | Ventajas |
| :--- | :---: | :---: | :--- | :--- |
| Plano (SQL) | `p` | `.sql` | `psql` | Legible y editable con cualquier editor de texto |
| Personalizado | `c` | `.dump` | `pg_restore` | Comprimido, permite restauración selectiva y en paralelo |

### 7.1. Respaldo en formato plano (`.sql`)

```bash
pg_dump -U christopher -h 192.168.56.55 -d pdb_employees -n employees -F p -f dump_employees_postgresql.sql
```

### 7.2. Respaldo en formato personalizado (`.dump`)

```bash
pg_dump -U christopher -h 192.168.56.55 -d pdb_employees -n employees -F c -f dump_employees_postgresql.dump
```

| Opción | Significado |
| :--- | :--- |
| `-U` / `-h` | Usuario y servidor de PostgreSQL |
| `-d pdb_employees` | Base de datos de origen |
| `-n employees` | Exporta solo el esquema `employees` |
| `-F p` / `-F c` | Formato plano (SQL) / formato personalizado (binario comprimido) |
| `-f` | Archivo de salida |

### 7.3. Restauración

Ambas restauraciones requieren una base de datos de destino existente y vacía. Se crea una base de prueba para no sobrescribir la original:

```bash
createdb -U christopher -h 192.168.56.55 pdb_employees_restore
```

#### Restaurar el archivo `.sql` con `psql`

```bash
psql -U christopher -h 192.168.56.55 -d pdb_employees_restore -v ON_ERROR_STOP=1 -f dump_employees_postgresql.sql
```

#### Restaurar el archivo `.dump` con `pg_restore`

```bash
pg_restore -U christopher -h 192.168.56.55 -d pdb_employees_restore -v dump_employees_postgresql.dump
```

Un archivo `.dump` no se puede leer ni restaurar con `psql`; solo `pg_restore` lo interpreta. Para ver su contenido sin restaurarlo:

```bash
pg_restore -l dump_employees_postgresql.dump
```

| Opción | Herramienta | Significado |
| :--- | :---: | :--- |
| `-f archivo.sql` | `psql` | Ejecuta el script SQL |
| `-v ON_ERROR_STOP=1` | `psql` | Detiene la restauración ante el primer error |
| `-d base` | `pg_restore` | Base de datos de destino |
| `-v` | `pg_restore` | Muestra el progreso detallado |
| `-l` | `pg_restore` | Lista el contenido del respaldo |
| `-j 4` | `pg_restore` | Restaura con 4 procesos en paralelo (solo formato `.dump`) |
| `--clean --if-exists` | `pg_restore` | Elimina los objetos existentes antes de recrearlos |

### 7.4. Verificación de la restauración

Conteo de registros en la base restaurada (debe coincidir con la sección 4):

```bash
psql -U christopher -h 192.168.56.55 -d pdb_employees_restore
```

```sql
SELECT 'employees' AS tabla, COUNT(*) FROM employees.employees
UNION ALL
SELECT 'salaries', COUNT(*) FROM employees.salaries
UNION ALL
SELECT 'titles', COUNT(*) FROM employees.titles;
```

| Tabla | Registros esperados |
| :--- | ---: |
| `employees` | 300,024 |
| `salaries` | 2,844,047 |
| `titles` | 443,308 |

---

## 8. Enlace de GitHub

Repositorio del proyecto: [x-christo-x/TecBD1](https://github.com/x-christo-x/TecBD1)
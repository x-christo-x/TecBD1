-- ** Database generated with pgModeler (PostgreSQL Database Modeler).
-- ** pgModeler version: 1.2.3
-- ** PostgreSQL version: 18.0
-- ** Project Site: pgmodeler.io
-- ** Model Author: ---

-- ** Database creation must be performed outside a multi lined SQL file. 
-- ** These commands were put in this file only as a convenience.

-- object: employees | type: DATABASE --
-- DROP DATABASE IF EXISTS employees;
CREATE DATABASE employees
	ENCODING = 'UTF8'
	LC_COLLATE = 'en_US.utf8'
	LC_CTYPE = 'en_US.utf8'
	TABLESPACE = pg_default
	OWNER = christopher;
-- ddl-end --


-- object: employees | type: SCHEMA --
-- DROP SCHEMA IF EXISTS employees CASCADE;
CREATE SCHEMA employees;
-- ddl-end --
ALTER SCHEMA employees OWNER TO christopher;
-- ddl-end --

-- object: employees_cp | type: SCHEMA --
-- DROP SCHEMA IF EXISTS employees_cp CASCADE;
CREATE SCHEMA employees_cp;
-- ddl-end --
ALTER SCHEMA employees_cp OWNER TO christopher;
-- ddl-end --

SET search_path TO pg_catalog,public,employees,employees_cp;
-- ddl-end --

-- object: employees.gender_enum | type: TYPE --
-- DROP TYPE IF EXISTS employees.gender_enum CASCADE;
CREATE TYPE employees.gender_enum AS
ENUM ('M','F');
-- ddl-end --
ALTER TYPE employees.gender_enum OWNER TO christopher;
-- ddl-end --

-- object: employees.employees | type: TABLE --
-- DROP TABLE IF EXISTS employees.employees CASCADE;
CREATE TABLE employees.employees (
	emp_no integer NOT NULL,
	birth_date date NOT NULL,
	first_name character varying(14) COLLATE pg_catalog."default" NOT NULL,
	last_name character varying(16) COLLATE pg_catalog."default" NOT NULL,
	gender employees.gender_enum NOT NULL,
	hire_date date NOT NULL,
	CONSTRAINT employees_pk PRIMARY KEY (emp_no)
);
-- ddl-end --
ALTER TABLE employees.employees OWNER TO christopher;
-- ddl-end --

-- object: employees.departments | type: TABLE --
-- DROP TABLE IF EXISTS employees.departments CASCADE;
CREATE TABLE employees.departments (
	dept_no character(4) COLLATE pg_catalog."default" NOT NULL,
	dept_name character varying(40) COLLATE pg_catalog."default" NOT NULL,
	CONSTRAINT departments_pk PRIMARY KEY (dept_no),
	CONSTRAINT dept_name UNIQUE (dept_name)
);
-- ddl-end --
ALTER TABLE employees.departments OWNER TO christopher;
-- ddl-end --

-- object: employees.dept_emp | type: TABLE --
-- DROP TABLE IF EXISTS employees.dept_emp CASCADE;
CREATE TABLE employees.dept_emp (
	emp_no integer NOT NULL,
	dept_no character(4) COLLATE pg_catalog."default" NOT NULL,
	from_date date NOT NULL,
	to_date date NOT NULL,
	CONSTRAINT dept_emp_pk PRIMARY KEY (emp_no,dept_no)
);
-- ddl-end --
ALTER TABLE employees.dept_emp OWNER TO christopher;
-- ddl-end --

-- object: employees.titles | type: TABLE --
-- DROP TABLE IF EXISTS employees.titles CASCADE;
CREATE TABLE employees.titles (
	emp_no integer NOT NULL,
	title character varying(50) COLLATE pg_catalog."default" NOT NULL,
	from_date date NOT NULL,
	to_date date,
	CONSTRAINT titles_pk PRIMARY KEY (emp_no,title,from_date)
);
-- ddl-end --
ALTER TABLE employees.titles OWNER TO christopher;
-- ddl-end --

-- object: employees.dept_manager | type: TABLE --
-- DROP TABLE IF EXISTS employees.dept_manager CASCADE;
CREATE TABLE employees.dept_manager (
	emp_no integer NOT NULL,
	dept_no character(4) COLLATE pg_catalog."default" NOT NULL,
	from_date date NOT NULL,
	to_date date NOT NULL,
	CONSTRAINT dept_manager_pk PRIMARY KEY (emp_no,dept_no)
);
-- ddl-end --
ALTER TABLE employees.dept_manager OWNER TO christopher;
-- ddl-end --

-- object: employees.salaries_cp | type: TABLE --
-- DROP TABLE IF EXISTS employees.salaries_cp CASCADE;
CREATE TABLE employees.salaries_cp (
	emp_no integer NOT NULL,
	salary integer NOT NULL,
	from_date date NOT NULL,
	to_date date NOT NULL,
	CONSTRAINT salaries_pk PRIMARY KEY (emp_no,from_date)
);
-- ddl-end --
ALTER TABLE employees.salaries_cp OWNER TO christopher;
-- ddl-end --

-- object: emp_no | type: CONSTRAINT --
-- ALTER TABLE employees.dept_emp DROP CONSTRAINT IF EXISTS emp_no CASCADE;
ALTER TABLE employees.dept_emp ADD CONSTRAINT emp_no FOREIGN KEY (emp_no)
REFERENCES employees.employees (emp_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: dept_no | type: CONSTRAINT --
-- ALTER TABLE employees.dept_emp DROP CONSTRAINT IF EXISTS dept_no CASCADE;
ALTER TABLE employees.dept_emp ADD CONSTRAINT dept_no FOREIGN KEY (dept_no)
REFERENCES employees.departments (dept_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: emp_no | type: CONSTRAINT --
-- ALTER TABLE employees.dept_manager DROP CONSTRAINT IF EXISTS emp_no CASCADE;
ALTER TABLE employees.dept_manager ADD CONSTRAINT emp_no FOREIGN KEY (emp_no)
REFERENCES employees.employees (emp_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: dept_no | type: CONSTRAINT --
-- ALTER TABLE employees.dept_manager DROP CONSTRAINT IF EXISTS dept_no CASCADE;
ALTER TABLE employees.dept_manager ADD CONSTRAINT dept_no FOREIGN KEY (dept_no)
REFERENCES employees.departments (dept_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: emp_no | type: CONSTRAINT --
-- ALTER TABLE employees.titles DROP CONSTRAINT IF EXISTS emp_no CASCADE;
ALTER TABLE employees.titles ADD CONSTRAINT emp_no FOREIGN KEY (emp_no)
REFERENCES employees.employees (emp_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --

-- object: emp_no | type: CONSTRAINT --
-- ALTER TABLE employees.salaries_cp DROP CONSTRAINT IF EXISTS emp_no CASCADE;
ALTER TABLE employees.salaries_cp ADD CONSTRAINT emp_no FOREIGN KEY (emp_no)
REFERENCES employees.employees (emp_no) MATCH SIMPLE
ON DELETE CASCADE ON UPDATE CASCADE;
-- ddl-end --



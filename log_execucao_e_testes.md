# Registro de Execução: Modelos Incrementais

Este documento arquiva o extrato oficial e bruto retirado de dentro do `dbt.log`, assinalando a comunicação entre a engine (dbt) e o banco de dados (PostgreSQL) sob as threads de execução durante os eventos disparados para as tabelas fato, englobando tanto os logs de debug físico quanto os reports de progresso (info).

## 1. fct_bookings

**Comando Invocado:**
```bash
dbt run --select fct_bookings
```

**Logs Nativos (Status & Debug da Sessão):**
```text
15:59:45.384228 [debug] [MainThread]: running dbt with arguments {... 'invocation_command': 'dbt run --select fct_bookings' ...}

...

15:59:47.669346 [info ] [MainThread]: Found 16 models, 32 data tests, 5 sources, 466 macros

...

15:59:54.944166 [debug] [Thread-1 (]: Began running node model.aluguel_veiculo.fct_bookings
15:59:54.946040 [info ] [Thread-1 (]: 1 of 1 START sql incremental model public_marts_core.fct_bookings .............. [RUN]
15:59:54.948551 [debug] [Thread-1 (]: Acquiring new postgres connection 'model.aluguel_veiculo.fct_bookings'
15:59:54.950251 [debug] [Thread-1 (]: Began compiling node model.aluguel_veiculo.fct_bookings
15:59:54.973282 [debug] [Thread-1 (]: Writing injected SQL for node "model.aluguel_veiculo.fct_bookings"
15:59:54.978438 [debug] [Thread-1 (]: Began executing node model.aluguel_veiculo.fct_bookings
15:59:55.087450 [debug] [Thread-1 (]: Writing runtime sql for node "model.aluguel_veiculo.fct_bookings"
15:59:55.091054 [debug] [Thread-1 (]: Using postgres connection "model.aluguel_veiculo.fct_bookings"

...

15:59:56.884979 [info ] [Thread-1 (]: 1 of 1 OK created sql incremental model public_marts_core.fct_bookings ......... [SELECT 17203 in 1.93s]
15:59:58.032243 [info ] [MainThread]: Finished running 1 incremental model in 0 hours 0 minutes and 10.35 seconds (10.35s).
15:59:58.156899 [info ] [MainThread]: Completed successfully
15:59:58.158747 [info ] [MainThread]: Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1
```

---

## 2. fct_sessions

**Comando Invocado:**
```bash
dbt run --select fct_sessions
```

**Logs Nativos (Status & Debug da Sessão):**
```text
16:02:36.477369 [debug] [MainThread]: running dbt with arguments {... 'invocation_command': 'dbt run --select fct_sessions' ...}

...

16:02:38.061194 [info ] [MainThread]: Found 16 models, 32 data tests, 5 sources, 466 macros

...

16:02:42.330682 [debug] [Thread-1 (]: Began running node model.aluguel_veiculo.fct_sessions
16:02:42.331851 [info ] [Thread-1 (]: 1 of 1 START sql incremental model public_marts_core.fct_sessions .............. [RUN]
16:02:42.333717 [debug] [Thread-1 (]: Acquiring new postgres connection 'model.aluguel_veiculo.fct_sessions'
16:02:42.334654 [debug] [Thread-1 (]: Began compiling node model.aluguel_veiculo.fct_sessions
16:02:42.355772 [debug] [Thread-1 (]: Writing injected SQL for node "model.aluguel_veiculo.fct_sessions"
16:02:42.358212 [debug] [Thread-1 (]: Began executing node model.aluguel_veiculo.fct_sessions
16:02:42.460640 [debug] [Thread-1 (]: Writing runtime sql for node "model.aluguel_veiculo.fct_sessions"
16:02:42.462637 [debug] [Thread-1 (]: Using postgres connection "model.aluguel_veiculo.fct_sessions"

...

16:02:44.645048 [info ] [Thread-1 (]: 1 of 1 OK created sql incremental model public_marts_core.fct_sessions ......... [SELECT 111098 in 2.31s]
16:02:45.803986 [info ] [MainThread]: Finished running 1 incremental model in 0 hours 0 minutes and 7.73 seconds (7.73s).
16:02:45.910717 [info ] [MainThread]: Completed successfully
16:02:45.912951 [info ] [MainThread]: Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1
```

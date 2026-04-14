# Requisitos Técnicos — Customer Success Analytics

## 1. Arquitetura Proposta

### Camadas

* Base: `fct_sessions`, `fct_bookings`
* Intermediário:

  * `int_user_activity`
  * `int_user_revenue`
* Mart:

  * `fct_customer_health`
  * `mart_cs_kpis`
  * `mart_cs_cohorts`

---

## 2. Novos Modelos

### int_user_activity

Grão: user_id + dt_date

Métricas:

* nr_sessions
* nr_searches
* last_session_at
* days_since_last_activity

Fonte:

* `fct_sessions` 

---

### int_user_revenue

Grão: user_id + dt_date

Métricas:

* gross_revenue
* net_revenue (commission)
* nr_bookings
* nr_completed_bookings

Fonte:

* `fct_bookings` 

---

### fct_customer_health

Grão: user_id + dt_reference

Campos:

* activity_7d / 30d
* revenue_30d
* bookings_30d
* days_since_last_activity
* is_active_flag
* is_churned_flag
* health_score

---

### mart_cs_cohorts

Grão: cohort_month + period_index

* cohort_size
* retained_users
* retention_rate
* revenue_per_user

---

### mart_cs_kpis

Grão: dt_date

* churn_rate
* retention_rate
* active_users
* arpu
* ltv_avg
* expansion_revenue

---

## 3. Regras de Negócio (Formalizadas)

### Cliente Ativo

```sql
last_session_at >= current_date - interval '30 days'
```

---

### Churn

```sql
active_last_period = 1
AND activity_current_period = 0
```

---

### LTV

```sql
sum(commission_revenue_amt) by user_id
```

---

### Health Score (exemplo)

```text
score =
  40% recency (dias desde última sessão)
+ 30% frequência (sessões 30d)
+ 30% valor (receita 30d)
```

---

## 4. Dependências

* `fct_sessions` → comportamento 
* `fct_bookings` → receita 
* `dim_users` → aquisição 

---

## 5. Qualidade de Dados

### Testes obrigatórios

* unicidade: user_id + dt
* não nulo: métricas principais
* valores válidos: status, device

### Regras críticas

* revenue >= 0
* sessões >= 0
* churn_rate ∈ [0,1]

---

## 6. Incremental Strategy

* Lookback: 30 dias
* Motivo:

  * churn depende de janela temporal
  * correções tardias de booking

---

## 7. Performance

* Particionamento por dt_date
* Agregações pré-calculadas (30d rolling)

---

## 8. Entregáveis para BI

* Tabela única: `mart_cs_kpis`
* Tabela exploratória: `fct_customer_health`

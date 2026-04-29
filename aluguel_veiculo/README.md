# Projeto DW - Aluguel de Veículos

Este repositório contém a infraestrutura completa de dados (Data Warehouse) desenvolvida via **dbt** (Data Build Tool) para uma operação digital de Aluguel de Veículos.

A solução abrange todo o pipeline analítico: desde o polimento da ingestão primária até a governança das entidades orientadas à decisões de nível Executivo (Marts).

---

## Como executar o projeto dbt do zero

### 1. Pré-Requisitos
- **Python** ativado num ambiente virtual (`.venv`)
- Pacotes instalados globalmente no venv:
  ```bash
  pip install dbt-core dbt-postgres
  ```
- **PostgreSQL** ativo rodando a instância nativa.

### 2. Configurando seu `profiles.yml`
Localize a pasta oculta padrão do dbt (`~/.dbt/profiles.yml` no Linux/Mac ou `C:\Users\<user>\.dbt\profiles.yml` no Windows) e certifique-se de preencher utilizando as credenciais fornecidas para engatar no Data Warehouse:

```yaml
aluguel_veiculo:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: <seu_usuario>
      password: <sua_senha>
      port: 5432
      dbname: <sua_database>
      schema: public # Layer originária
      threads: 4
```

### 3. Rodando o Pipeline
Pelo seu terminal em ativado, faça o navegue ao diretório `aluguel_veiculo/` e execute em ondem:
1. Instale as bibliotecas e pacotes extra de qualidade requeridos:
   ```bash
   dbt deps
   ```
2. Processe a montagem completa dos modelos.
   ```bash
   dbt run
   ```
3. Exija a bateria completa de rigor dos testes de integridade:
   ```bash
   dbt test
   ```

*(Nota: Caso faça alterações estruturais no schema dos fatos, execute `dbt run --full-refresh` para expurgar a tabela transacional da memória antes da recriação).*

---

## 🏛 Diagrama de Arquitetura do Modelo de Dados

O fluxo foi delineado aderindo estritamente aos pilares robustos do dbt modular (Medallion + Kimball Architecture).

```text
       [Raw Postgree Database] 
                 |
                 v
+---------------------------------+
|          STAGING LAYER          | 
|  (Clean, Type-cast, Rename)     |
+---------------------------------+
                 |
                 v
+---------------------------------+
|       INTERMEDIATE LAYER        |
| (Business Rules, Anomaly Flags, |
|      Window Func Dedupl.)       |
+---------------------------------+
                 |
        +--------+--------+
        v                 v
+---------------+ +---------------+
| CORE FACTS    | | DIMENSIONS    |
| - fct_bookings| | - dim_users   |
| - fct_sessions| | - dim_partners|
|               | | - dim_dates   |
+---------------+ +---------------+
                 |
                 v
+---------------------------------+
|         ANALYTICS MARTS         |
| Aggregações finas e Dashboards  |
| - mart_funnel                   |
+---------------------------------+
```

---

## Justificativas: Modelagem e Materialização

### Modelagem Dimensional
Optamos por enveredar na abstração do Star Schema dividindo a inteligência em **Dimensões** estritas (`dim_users`, `dim_partners`) para fatiamento (slice-and-dice), operando contra as **Fatos** granulares e cronológicas (`fct_bookings`, `fct_sessions`). A premissa central aqui foi desacoplar entidades lógicas, isolando os cálculos intensos em um bloco central `Intermediate`, impedindo vazamento de complexidade para a camada analítica final.

### Estratégia de Materialização
- **Staging** (`view`): Por serem puramente cascatas de renomeação de colunas e castings leves, materializar em disco causaria custos inócuos de redundância em cloud computing.
- **Intermediate** (`table`): São efetuados dectecções de anomalias por JOINs multi-tabelas grossos e deduplicações pesadas por `row_number()`. Cachar essa carga como de forma espessa na memória tira o burden imposto às facts na ponta.
- **Marts_Core - Facts** (`incremental` com _delete+insert_): São logs que explodem geometricamente em volume de linhas a cada mês que se passa. Refazê-los do zero todo dia seria péssima arquitetura. A estratégia incremental engata apenas a "fatia temporal nova" do dia preservando o orçamento da infraestrutura sem impactar performance de merge nativo por conflito temporal.
- **Marts_Analytics** (`table`): Para leitura direta no painel do Business Intelligence. Exigem velocidade vertiginosa e estão frequentemente recalculando agregações do nível superior.

### Estratégia de Modelagem Incremental

Para otimizar o processamento e garantir a integridade dos dados nas tabelas `fct_booking` e `fct_session`, adotei a materialização **Incremental** com a estratégia `delete+insert` (padrão robusto para PostgreSQL).

#### 1. Lógica de Atualização e Lookback

Diferente de uma carga incremental simples que apenas anexa novos dados, nossa lógica utiliza uma **Janela de Lookback (Retrocesso)** de **7 a 30 dias**.

- **Por quê:** Reservas (*bookings*) e Sessões (*sessions*) são entidades "vivas". Uma reserva pode ser criada hoje, mas ter seu status alterado para "cancelado" ou "concluído" dias depois.
- **Funcionamento:** O modelo revisita os últimos dias de dados, garantindo que qualquer alteração de status na origem seja sincronizada com o Data Warehouse, mantendo a precisão das métricas financeiras e operacionais.

#### 2. Tratamento de Sessões Órfãs (Regra dos 1440 min)

Para a `fct_session`, implementei uma lógica de **fechamento forçado**:

- Sessões que não possuem um evento de término (`ended_at`) e que ultrapassam **1440 minutos (24 horas)** de duração são encerradas artificialmente.
- **Filtro Incremental Especial:** O modelo monitora registros onde `ended_at_final IS NULL`, garantindo que sessões abertas sejam reavaliadas a cada execução até que recebam um status final.

#### 3. Garantia de Unicidade e Prevenção de Fan-out

Como as tabelas de fatos realizam joins com dimensões e eventos (como buscas e cancelamentos), existe o risco de duplicação de linhas (*fan-out*).

- **Deduplicação Explícita:** Utilizamos a função de janela `row_number()` particionada pela `unique_key` (`booking_id` / `session_id`) no estágio final da transformação.
- Isso garante que, mesmo que ocorram inconsistências na origem ou nos joins, cada registro seja único na camada final, respeitando a integridade referencial do modelo.

#### 4. Otimização de Performance

Para evitar o escaneamento completo das tabelas (*Full Table Scan*) no PostgreSQL:

- Aplicamos filtros baseados na coluna de partição (`started_at` / `tsp_booked`) limitando a busca aos **últimos 10 dias**.
- Isso garante que a consulta seja executada apenas sobre os índices, reduzindo drasticamente o tempo de processamento e o consumo de recursos no Supabase.

> **Plano de Testes:** Para validar cada um desses comportamentos com queries reais, consulte o [plano_teste_incremental.md](extra/plano_teste_incremental.md).

---

## 💱 Currency Normalization (FX)

### Problema

O dataset contém transações em **cinco moedas distintas** (BRL, USD, ARS, CLP, COP), reflexo da operação regional da plataforma. Sem normalização, qualquer métrica agregada — receita bruta, ticket médio, comissão — mistura ordens de grandeza incompatíveis: uma reserva de 500 USD (~R$2.550) seria tratada no mesmo patamar que uma reserva de 500 COP (~R$0,65). Isso invalida toda a camada analítica downstream e qualquer decisão de negócio derivada.

### Solução Implementada

A normalização cambial adota **BRL como moeda base** e opera em três componentes:

| Componente | Layer | Responsabilidade |
|---|---|---|
| `dim_exchange_rates` | Mart (dimension) | Tabela de taxas de câmbio diárias, alimentada via seed |
| `int_valid_bookings` | Intermediate | Conversão efetiva dos valores, aplicação da taxa e flag de qualidade |
| `fct_bookings` / `fct_sessions` | Mart (facts) | Propagação dos valores normalizados para consumo analítico |

### Lógica de Conversão: Last Known Rate

O join entre bookings e taxas de câmbio **não utiliza igualdade de data** (`=`). Em produção, é comum que a tabela de FX não contenha uma taxa para cada dia do calendário (feriados, gaps de ingestão, cobertura parcial). A abordagem adotada foi **last known rate**: buscar a taxa mais recente disponível anterior ou igual à data da reserva.

Implementação via `LEFT JOIN LATERAL` (PostgreSQL):

Essa construção garante que:
- Nenhuma booking seja descartada por ausência de taxa exata no dia
- A taxa aplicada seja sempre a mais próxima e conservadora (backward-looking)
- O tratamento de `currency_code` com `upper(trim())` previne falhas silenciosas por inconsistência de case ou espaços

### Convenção de Nomenclatura

O padrão adotado preserva os valores originais e cria colunas paralelas convertidas:

| Sufixo | Significado | Exemplo |
|---|---|---|
| `*_amt` | Valor na moeda original da transação | `total_amount_amt`, `daily_rate_amt` |
| `*_brl_amt` | Valor convertido para BRL | `total_amount_brl_amt`, `daily_rate_brl_amt` |

As colunas derivadas de receita na `fct_bookings` seguem o mesmo padrão:
- `gross_revenue_amt` → receita bruta na moeda original
- `gross_revenue_brl_amt` → receita bruta normalizada em BRL
- `commission_revenue_brl_amt` → comissão normalizada em BRL

### Qualidade de Dados

A flag `is_missing_fx_rate_flag` sinaliza reservas onde nenhuma taxa de câmbio foi encontrada (cenário extremo: moeda inexistente na seed ou booking anterior à primeira data disponível). Essa flag é testada em `fct_bookings.yml` com `severity: warn`, alertando sem bloquear o pipeline.

A coluna `applied_fx_rate` expõe a taxa efetivamente usada na conversão (1 para BRL, exchange rate para demais), permitindo auditoria direta.

### Impacto Analítico

Após a normalização, métricas como `total_revenue_amt` na `fct_sessions` e `mart_funnel` passaram a refletir valores em BRL, tornando comparações cross-currency válidas. Entretanto, é importante notar que a distribuição de receita por moeda pode ser desigual — mercados em ARS ou COP podem apresentar volumes nominais altos mas receita convertida baixa. Recomenda-se análise segmentada por `currency_code` para evitar conclusões enviesadas.

### Decisão Arquitetural

A conversão cambial foi deliberadamente centralizada na camada **intermediate**, não no BI nem nos marts. Essa decisão garante que:
- Todo modelo downstream consuma valores já normalizados, eliminando risco de inconsistência entre dashboards
- A lógica de FX seja versionada, testada e auditável dentro do pipeline dbt
- Qualquer mudança na regra de conversão (ex: troca de moeda base, adoção de taxa média vs. fechamento) se propague automaticamente para toda a cadeia analítica

---

## Limitações Conhecidas & Melhorias Futuras (Roadmap)
Visando cenários hiper-escaláveis num futuro com maior provisionamento de infraestrutura/equipe, as seguintes abordagens ficariam no topo do backlog técnico:

1. **Testes Estatísticos de Anomalias Dinâmicas**: Utilizar Z-Scores macro e desvios padrões móveis usando testes dbt customizados para substituir lógicas arbitrárias flaggeadas no SQL rígido de outliers de booking (`val > 15000`).
2. **Surrogate Keys Reais via Hashing**: Atualmente identificadores repassam Pks de cordas (`string`). Num pipeline avançado imporia o uso massificado de `dbt_utils.generate_surrogate_key` nas Primary Keys blindando os domínios via criptografia e aliviando processamento de joins.
3. **Dimensões do Tipo SCD2 (Slowly Changing Dimensions)**: A aplicação se beneficiaria em rastrear de forma passiva as flutuações sazonais dos *Tiers de Comissão* associados em épocas específicas da `dim_partners`, o que não pode ser recriado fielmente via Drop+Create no estado atual.
4. **CI/CD Simplificado (Slim CI)**: Trazer o controle pro GitHub Actions validando qualquer Push nos braços das ramificações mediante rodadas de pipeline no schema provisório com suporte e linter (ex: `sqlfluff` no setup do projeto).
5. **Orquestração com Apache Airflow**: A execução atual dos modelos dbt é disparada manualmente via CLI. Num ambiente produtivo, a evolução natural seria encapsular o pipeline em **DAGs do Airflow** utilizando o operador `BashOperator` ou o `DbtTaskGroup` (via `astronomer-cosmos`), permitindo agendamentos por cron, controle de dependências entre tarefas, retentativas automáticas em falha e monitoramento de SLA — substituindo a operação manual por um pipeline verdadeiramente autônomo.
6. **Enriquecimento Semântico com LLMs**: A camada analítica atual opera exclusivamente sobre dados estruturados. Uma próxima fronteira seria integrar **Modelos de Linguagem (LLMs)** — como a API da OpenAI ou modelos open-source via HuggingFace — para enriquecer os dados com inteligência semântica: categorização automática de motivos de cancelamento a partir de campos de texto livre, detecção de anomalias de precificação por contexto, e geração de *insights* narrativos automáticos para os relatórios executivos, conectando a inteligência do DW diretamente à linguagem de negócio.

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

---

## Limitações Conhecidas & Melhorias Futuras (Roadmap)
Visando cenários hiper-escaláveis num futuro com maior provisionamento de infraestrutura/equipe, as seguintes abordagens ficariam no topo do backlog técnico:

1. **Testes Estatísticos de Anomalias Dinâmicas**: Utilizar Z-Scores macro e desvios padrões móveis usando testes dbt customizados para substituir lógicas arbitrárias flaggeadas no SQL rígido de outliers de booking (`val > 15000`).
2. **Surrogate Keys Reais via Hashing**: Atualmente identificadores repassam Pks de cordas (`string`). Num pipeline avançado imporia o uso massificado de `dbt_utils.generate_surrogate_key` nas Primary Keys blindando os domínios via criptografia e aliviando processamento de joins.
3. **Dimensões do Tipo SCD2 (Slowly Changing Dimensions)**: A aplicação se beneficiaria em rastrear de forma passiva as flutuações sazonais dos *Tiers de Comissão* associados em épocas específicas da `dim_partners`, o que não pode ser recriado fielmente via Drop+Create no estado atual.
4. **CI/CD Simplificado (Slim CI)**: Trazer o controle pro GitHub Actions validando qualquer Push nos braços das ramificações mediante rodadas de pipeline no schema provisório com suporte e linter (ex: `sqlfluff` no setup do projeto).

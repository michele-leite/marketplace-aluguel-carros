# Data Governance & Quality Framework
*Aluguel de Veículos - Data Warehouse*

## 1. Dicionário e Identificação de Anomalias (Data Quality Issues)
Durante a estruturação do Data Warehouse, diversos problemas estruturais e de negócios oriundos do *raw layer* foram auditados e devidamente tratados num ambiente protegido de Data Quality na camada *Intermediate*:
- **Faturamento Zerado ou Negativo:** Foram identificados valores de `total_amount <= 0` em transações normais. Removemos as ocorrências do pipeline principal para não inflar ou deflacionar equivocadamente o faturamento base (model: `int_valid_bookings`).
- **Comportamento Abusivo / Bot-Like:** Múltiplas sessões disparando volumes absurdos de procuras automáticas (exemplo: `> 50` buscas numa janela curtíssima de `5 minutos`). Elas foram neutralizadas e decantadas através de um rule-engine via window function no SQL (model: `int_valid_searches`).
- **Anomalias Cronológicas (Tempo e Duração):** Foram barrados os cruzamentos onde o registro indicou `dropoff` sendo anterior ao `pickup`. Em paralelo, em âmbito compportamental, sessões persistindo esticadas por mais de `24 horas` ininterruptas foram ceifadas "na marra" (tratadas com split temporal e flaggadas em `fct_sessions`).
- **Estornos Falsos ou Categóricos:** Intervenção perante cancelamentos onde havia a evidência de um registro de `refund_amount` puramente superior ao valor contratual cobrado originalmente (Criamos um alerta constante no BD usando a flag `is_refund_anomaly_flag` residente no `int_cancellations`).
- **Parceiros Fantasmas na Venda:** Cliques perdidos para fornecedores inexistentes ou sem `partner_id` no CRM foram extirpados e saneados empregando estrita Integridade Referencial através das unificações e left joins do masterbook no modelo relacional.

## 2. Regras de Validação Automática (Testes)
A garantia de consistência da infraestrutura tornou-se coberta de ponta a ponta com testes rigorosos:
- **Integridade Sistêmica:** Implementou-se obrigatoriamente cláusulas macro de `unique` e `not_null` cravadas em todas as PKs de cada tabela do escopo (Staging à Marts).
- **Consistência Relacional:** Validações do tipo `relationships` blindam perdas, conferindo que toda foreign key referenciada dentro de uma transação ou sessão exista de maneira irrevogável nas *dimensões* finais.
- **Policiamento Numérico (dbt_expectations):** Usado e implementado os pacotes restritivos mantendo sob controle anomalias que o SQL puro deixa passar. Exemplo: `expect_column_values_to_be_between: min_value: 0` atrelado no `fct_bookings.yml` proíbe terminantemente inserções com faturamento financeiro e take-rates caindo num espectro negativo.
- **Enforcement Inter-Colunas:** Teste lógico customizado `expect_column_pair_values_A_to_be_greater_than_B` bloqueia qualquer imprecisão material que transponha a cronologia do encerramento das viagens para frente de sua própria origem de embarque.
- **Barreira Temporal (Custom Macros):** Implementação ativa de macro customizada em SQL (`test_no_future_dates`) desenhada para resguardar as lógicas do tempo-real (Real-Time constraints). Ancorada preventivamente em naturezas cronológicas atômicas de *created_at* (exemplo de uso: `tsp_booked` na tabela `stg_bookings`), reprovando transações irreais que supostamente aconteceram no "futuro".

## 3. Catálogo de Modelos (Marts) e Glossário de Metadados
Todos os modelos foram marcados sistematicamente (propriedade nativa via tag `meta: {owner, layer, business_domain}`) em seus `.yml`s para futura integração em catálogos como o Datahub/Atlan. Abaixo a macro arquitetura liberada ao usuário de negócio final:

| Modelo Analítico | Tipo Dimensional | Domínio Owner | Descrição Prática do Escopo |
|------------------|------------------|---------------|-----------------------------|
| `dim_dates` | Dimension | Conformed | Dimensão calendário oficial para Time Spine e time-travel das partições da plataforma. |
| `dim_users` | Dimension | Cliente | Informações vitais para o rastreamento do First-Touch baseados no modelo Kimball. |
| `dim_partners` | Dimension | Parceiros | Entidade mestra de cadastro dos fornecedores com rastreio explícito de tiers tarifários e status em atividade. |
| `fct_bookings` | Fact | Financeiro | Livro-razão da locadora. Entidade primária atômica trazendo o log das reservas, engates de cancelamentos, receita global bruta e comissão extraída do pipeline. |
| `fct_sessions` | Fact | Comportamento | Fact Table sobre navegação que amarra a experiência interativa. O grão foca em como a aquisição atua ao afunilar cliques na direção aos *checkouts*. |
| `mart_funnel` | Aggregation | Produto | Tabela pronta para painel unificando sessões → procuras → sucesso de carrinho aberto em dimensões dia/canal/device. |

**Dicionário Analítico das Métricas:**
- **Search Rate**: Porcentagem proporcional do cômputo que iniciou uma sessão de uso contra o sub-segmento que gerou interatividade em alguma *feature* de leilão.
- **Booking Rate**: Taxa sintética de sucesso transmutando *visits* ou *hits* crus para a consumação bem-sucedida atrelada ao faturamento oficial do veículo.
- **Avg Ticket**: Rateio financeiro (Receita Média) auferido perante o agrupamento validado das compras consolidadas.
- **Gross Revenue & Commission Revenue**: Valor absoluto bruto tarifário gerado por contrato contra a fatia líquida (take-rate real) transferida à matriz da plataforma.

## 4. Acordos de SLA (Service Level Agreement) de Dados
As FCTs consolidadas recebem a denominação técnica de **Confiança Plena** quando obedecem aos limiares:
1. **Time-to-Data (D+1):** É proibitivo expor a sumarização se as rotinas de incremental build do DBT não atingirem completude garantida até as imposições da *08h00 AM*; o que vier após é submetido à revisão do Eng. Analytics.
2. **Crash & Reliability:** `100% de Taxa de Sucesso (PASS RATE)` perante as baterias predefinidas no modelo de QA de ponta-a-ponta (`dbt test`). Warning causa flag no log corporativo e impede o *Publish*. 
3. **Threshold de Risco Transacional:** Se em uma dada carga for mensurado a penetração volumétrica igual ou acima de **2%** enquadrada através da régua paramétrica de `is_high_value_booking_flag`, o report fica em quarentena técnica por indícios fortes de ruídos operacionais nas origens DB.

## 5. Política de Governança Identitária e PII
Maturidade em obediência primária contra vazamentos em instâncias operacionais ou corporativas de Business Intelligence:
- **Ocultação de Contatos na Raiz Pessoal (`contact_email`):** Sob imposição da governança, informações mapeadas dos fornecedores atreladas intencionalmente dentro do repositório *crú* (`stg_partners`) não progrediram sob nenhuma hipótese natural pelas camadas e *NUNCA* são repassadas ao braço *Marts*; foram silenciadas ainda no *Intermediate*.
- **Localização e ID Comportamentais (`IP/User_id`):** Não se carrega nem se disponibiliza chaves de infraestrutura de rastreio de navegação via MAC Adress, as entidades pessoais adentram a ferramenta como chaves de Surrogates anonimizados (`user_id`), transformando métricas comportamentais com segurança e retendo geografia local a níveis rasos não dedutíveis por mapeamento global de **Country Code**.

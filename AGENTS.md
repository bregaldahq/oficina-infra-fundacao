# oficina-infra-fundacao — guia para agentes

Fundação do sistema Oficina Mecânica: VPC, subnets, RDS MySQL, **todos** os segredos e as
migrations SQL. Terraform puro (>= 1.6, AWS provider ~> 5.60). É o primeiro repo a ser aplicado
e o último a ser destruído (ADR-009), e muda raramente.

O sistema tem quatro repos; o mapa, as regras entre eles e as ferramentas (`bin/ws`) ficam no
repositório principal `oficina-mecanica`. O contrato entre os repos é o
`docs/fase-3/CONTRATOS.md` do `oficina-api`. Se ele divergir daqui, **o documento vence**:
corrija o código ou altere o documento no mesmo conjunto de PRs.

## O que cria

- `network.tf`: VPC `10.20.0.0/16`.
  - 2 subnets públicas, com rota `0.0.0.0/0` para o IGW; é onde ficam os nodes do EKS.
  - 2 subnets privadas, sem rota para a internet; é onde ficam o RDS e a Lambda.
  - **Não há NAT** (ADR-010, custo).
- `security_groups.tf`: SG `db` (ingress 3306) e SG `db-client`, que fica **vazio** e funciona
  como crachá: quem anexa o `db-client` alcança o banco. Assim a dependência vai numa direção só.
- `rds.tf`: MySQL 8.0 `db.t4g.micro`, criptografado. Em prod, `deletion_protection` e snapshot
  final.
- `secrets.tf`: `random_password` gera `oficina/<env>/db` (`host`, `port`, `dbname`,
  `username`, `password`) e `oficina/<env>/auth` (`JWT_SECRET`, `JWT_EXPIRATION`,
  `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `WEBHOOK_TOKEN`). Ninguém digita nem commita esses valores.
- `ssm.tf`: os 10 parâmetros `network/*`, `db/*` e `auth/secret_arn` que os outros repos leem
  (seção 2 do `CONTRATOS.md`).
- `vpc_endpoints.tf`: interface endpoint do Secrets Manager.
- `migrations/NNN_<slug>.sql`:
  - `001`: schema inicial;
  - `002`: ajustes da Fase 3;
  - `003_seed_demo`: 120 OS de demonstração, só em hml.

  Quem executa é o Job `oficina-migrate` da aplicação, não este repo. O modelo de dados está em
  `docs/MODELO-DE-DADOS.md`.

## Contratos

- **Publica:** `/oficina/<env>/network/*`, `/oficina/<env>/db/*`,
  `/oficina/<env>/auth/secret_arn` e os dois segredos. Quem publica é mergeado e aplicado
  **antes** de quem consome. Para remover, o consumidor deixa de ler primeiro. Renomear são três
  etapas (adicionar o novo, migrar os consumidores, remover o antigo).
- **Consome:** nada dos outros repos.

## Migrations

- Precisam ser idempotentes: o `pr.yml` aplica todas **duas vezes** num MySQL 8.0 real. Onde o
  MySQL não aceita `IF NOT EXISTS` (por exemplo, `ADD COLUMN`), consulte o `information_schema`
  e monte o comando com `PREPARE`/`EXECUTE`, como no `002`.
- Proibido: `DELIMITER`, `CREATE DATABASE`, `USE`.
- Seed só com sufixo `_demo`: o runner da aplicação pula esses arquivos em produção.
- Coluna nova usada por um repositório PDO da aplicação também precisa entrar no `CREATE TABLE`
  dos testes de integração de lá (`tests/Integration/`, SQLite) e no `docs/MODELO-DE-DADOS.md`.

## Validar

Não há conta AWS na máquina de desenvolvimento: o teto é `fmt` + `validate` sem backend, mais
as migrations num MySQL descartável.

- A partir do repositório principal: `bin/ws verify --repo fundacao`. Ele roda `terraform fmt`,
  `validate`, a checagem de SQL proibido e as migrations duas vezes, com a conferência dos 7
  status do seed.
- Direto: `terraform fmt -check -recursive` e
  `terraform init -backend=false && terraform validate`.

## Armadilhas

| Sintoma | Causa | O que pega |
|---|---|---|
| A Lambda `auth-cpf` trava até o timeout, sem erro | Serviço AWS chamado de dentro da subnet privada sem endpoint próprio (não há NAT) | Revisão: todo serviço novo usado pela Lambda precisa de interface endpoint em `vpc_endpoints.tf` |
| Os nodes do EKS não entram no cluster | A rota `0.0.0.0/0` das subnets públicas foi removida | Revisão (adendo 3 da seção 2) |
| O apply do cluster ou da Lambda quebra por parâmetro ausente | Parâmetro renomeado ou removido antes de os consumidores mudarem | `bin/check-contracts.py` (SSM-1) |
| A migration passa na primeira vez e quebra na segunda | `ADD COLUMN` sem checar o `information_schema` | `pr.yml` e `bin/ws verify` (`migrations-2x`) |
| O Terraform recria tudo ou perde o state | A chave do state ou a tag `Repo` foi "corrigida" para o nome novo | `bin/check-contracts.py` (NOME-1). Continuam `oficina-infra-database`, de propósito |

O `.terraform.lock.hcl` é ignorado neste repo: cada `init` resolve os providers de novo.

## Convenções

- Branches `feat/…`, `fix/…`, `chore/…`, `ci/…`, com PR para `develop`; `develop` sobe para
  `main` por PR. O deploy é manual (`workflow_dispatch`) e só o usuário dispara.
- Commits em português, sem acento no assunto, Conventional Commits com escopo
  (`fix(rds): ...`), só com o nome do autor: sem `Co-Authored-By` nem rodapé de ferramenta.
- Agente nunca roda `terraform apply`/`destroy` nem lê o valor de um segredo.

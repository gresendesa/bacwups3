# bacwups3

Ferramenta interativa de linha de comando (CLI) desenvolvida em Shell Script (Bash) para automatizar backup completo versionado e recuperação (restore) de volumes Docker e diretórios locais para buckets do AWS S3.

## Características Principais

* **Interface Visual no Terminal (TUI):** Interação amigável baseada em menus utilizando o `whiptail`.
* **Suporte a Múltiplos Alvos:** Realiza backup e restore tanto de **volumes gerenciados pelo Docker** quanto de **diretórios arbitrários** do sistema hospedeiro.
* **Modos de Backup de Diretório:** Diretórios locais podem ser empacotados por completo ou como **Projeto Git**, respeitando automaticamente `.gitignore`, `.git/info/exclude` e excludes globais configurados no Git.
* **Empacotamento Eficiente:** Todos os dados são obrigatoriamente compactados em um arquivo único no formato `.tar.gz`. A sincronização de arquivos soltos (`aws s3 sync`) não é utilizada.
* **Backup completo versionado:** Cada execução gera um pacote `.tar.gz` completo e independente, com ID único temporal (ex: `20260712T184231Z-a94f10d2`) para preservar histórico no S3 sem sobrescrita silenciosa.

## Segurança e Integridade

* **Proteção Anti-Sobrescrita:** A restauração é imediatamente abortada caso o volume Docker ou o diretório de destino já existam e contenham dados, prevenindo perdas acidentais.
* **Manifesto JSON de Rastreabilidade:** Cada backup gera um manifesto JSON com esquema inicial, modo `full`, ID do backup, tipo de alvo, origem, tamanho do pacote e hash SHA-256.
* **Validação Criptográfica Rigorosa (SHA256):**
  * O hash SHA256 do arquivo `.tar.gz` é calculado no momento do upload e gravado no manifesto.
  * No momento do download, o script recalcula o hash do pacote recebido e o cruza com o valor do manifesto para atestar a integridade. 
  * Em caso de divergência, o arquivo corrompido é sumariamente apagado e a extração é bloqueada.
* **Verificação sem Restore:** A TUI permite baixar manifesto e pacote, validar SHA256 e inspecionar a estrutura do `.tar.gz` sem criar volume ou diretório de destino.
* **Execução Segura:** A ferramenta atua de forma passiva em relação aos serviços; ela emite avisos, mas não pausa contêineres automaticamente. O controle de concorrência é delegado ao administrador.

## Pré-requisitos

Para executar o `bacwups3`, certifique-se de ter os seguintes pacotes instalados no seu ambiente Linux:

* `bash` (Testado em ambientes Debian/Ubuntu/Mint)
* `whiptail` (Para renderização da interface TUI)
* `aws-cli` (Configurado com credenciais de acesso ao bucket S3 destino)
* `jq` (Para geração e validação segura do manifesto JSON)
* `git` (Obrigatório apenas para o modo de backup "Projeto Git")
* `docker` (Obrigatório apenas se for interagir com volumes de contêineres)
* Utilitários padrão do sistema: `tar`, `sha256sum`, `grep`, `awk`

## Instalação e Uso

1. Clone ou baixe os scripts para o seu servidor.
2. Certifique-se de que o script principal possui permissão de execução:
```bash
chmod +x bacwups3.sh
```

3. Execute a ferramenta:
```bash
./bacwups3.sh
```
4. Siga as instruções em tela para selecionar a operação (Backup/Restore/Verify), o tipo de alvo quando aplicável, o nome/caminho e a URI do bucket S3.

## Configuração AWS com IAM restrito

Para um usuário IAM restrito a um único bucket, configure o bucket explicitamente no `.env`. Assim a TUI não precisa executar `aws s3 ls` sem bucket, operação que exige `s3:ListAllMyBuckets`.

Exemplo:

```bash
ACCESS_KEY=...
SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
BACWUPS3_S3_BUCKET=bkp-playground
```

Também são aceitos os nomes nativos da AWS CLI:

```bash
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
BACWUPS3_S3_BUCKET=bkp-playground
```

Se preferir usar profile, exporte antes de abrir a TUI:

```bash
AWS_PROFILE=s3-backup AWS_REGION=us-east-1 ./bacwups3.sh
```

## Modos de Backup de Diretório

Ao selecionar um diretório para backup, a TUI oferece dois modos:

* **Diretório completo:** comportamento tradicional. O diretório inteiro é compactado sem exclusões automáticas e o manifesto registra `"filter_mode": "none"`.
* **Projeto Git, respeitando .gitignore:** o diretório precisa pertencer a um repositório Git. A seleção de arquivos da árvore de trabalho é feita com `git ls-files --cached --others --exclude-standard -z`, incluindo arquivos rastreados e arquivos não rastreados não ignorados. O pacote inclui o diretório `.git`, inclui arquivos `.env*` mesmo quando ignorados, e respeita `.gitignore` da raiz, `.gitignore` em subdiretórios, `.git/info/exclude`, excludes globais e regras de reinclusão com `!`.

No modo Git, o manifesto registra `"filter_mode": "gitignore"`, commit, branch, estado dirty e `"git_metadata_included": true`. O backup gerado continua sendo um `.tar.gz` completo e independente.

## Testes locais

Execute a suíte essencial com um único comando:

```bash
bash tests/run_all.sh
```

Os testes usam mocks locais para AWS e Docker, não exigem uma conta AWS real e validam o bundle gerado com `bash -n`. Quando `shellcheck` estiver instalado, o mesmo comando também executa a análise estática.

Para executar também o teste de integração real de volumes Docker:

```bash
BACWUPS3_RUN_DOCKER_INTEGRATION=1 bash tests/run_all.sh
```

Esse teste cria volumes Docker temporários, valida backup/restore real de volume e remove os volumes ao final.

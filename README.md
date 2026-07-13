# bacwups3

Ferramenta interativa de linha de comando (CLI) desenvolvida em Shell Script (Bash) para automatizar backup completo versionado e recuperação (restore) de volumes Docker e diretórios locais para buckets do AWS S3.

## Características Principais

* **Interface Visual no Terminal (TUI):** Interação amigável baseada em menus utilizando o `whiptail`.
* **Suporte a Múltiplos Alvos:** Realiza backup e restore tanto de **volumes gerenciados pelo Docker** quanto de **diretórios arbitrários** do sistema hospedeiro.
* **Modos de Backup de Diretório:** Diretórios locais podem ser empacotados por completo ou como **Projeto Git**, respeitando automaticamente `.gitignore`, `.git/info/exclude` e excludes globais configurados no Git.
* **Empacotamento Eficiente:** Todos os dados são obrigatoriamente compactados em um arquivo único no formato `.tar.gz`. A sincronização de arquivos soltos (`aws s3 sync`) não é utilizada.
* **Backup completo versionado:** Cada execução gera um pacote `.tar.gz` completo e independente, com sufixo de versão sequencial (ex: `v1`, `v2`, `v3`) para preservar histórico no S3.

## Segurança e Integridade

* **Proteção Anti-Sobrescrita:** A restauração é imediatamente abortada caso o volume Docker ou o diretório de destino já existam e contenham dados, prevenindo perdas acidentais.
* **Manifesto JSON de Rastreabilidade:** Cada backup gera um arquivo de metadados correspondente contendo o nome do alvo, versão, máquina de origem, usuário, caminho original, data e hash do pacote.
* **Validação Criptográfica Rigorosa (SHA256):** * O hash SHA256 do arquivo `.tar.gz` é calculado no momento do upload e gravado no manifesto.
  * No momento do download, o script recalcula o hash do pacote recebido e o cruza com o valor do manifesto para atestar a integridade. 
  * Em caso de divergência, o arquivo corrompido é sumariamente apagado e a extração é bloqueada.
* **Execução Segura:** A ferramenta atua de forma passiva em relação aos serviços; ela emite avisos, mas não pausa contêineres automaticamente. O controle de concorrência é delegado ao administrador.

## Pré-requisitos

Para executar o `bacwups3`, certifique-se de ter os seguintes pacotes instalados no seu ambiente Linux:

* `bash` (Testado em ambientes Debian/Ubuntu/Mint)
* `whiptail` (Para renderização da interface TUI)
* `aws-cli` (Configurado com credenciais de acesso ao bucket S3 destino)
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
4. Siga as instruções em tela para selecionar a operação (Backup/Restore), o tipo de alvo (Volume/Diretório), o nome/caminho e a URI do bucket S3.

## Modos de Backup de Diretório

Ao selecionar um diretório para backup, a TUI oferece dois modos:

* **Diretório completo:** comportamento tradicional. O diretório inteiro é compactado sem exclusões automáticas e o manifesto registra `"filter_mode": "none"`.
* **Projeto Git, respeitando .gitignore:** o diretório precisa pertencer a um repositório Git. A seleção de arquivos é feita com `git ls-files --cached --others --exclude-standard -z`, incluindo arquivos rastreados e arquivos não rastreados não ignorados. O pacote exclui o diretório `.git` e respeita `.gitignore` da raiz, `.gitignore` em subdiretórios, `.git/info/exclude`, excludes globais e regras de reinclusão com `!`.

No modo Git, o manifesto registra `"filter_mode": "gitignore"`, commit, branch, estado dirty e `"git_metadata_included": false`. O backup gerado continua sendo um `.tar.gz` completo e independente.

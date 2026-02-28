# bAcWapS3

Ferramenta interativa de linha de comando (CLI) desenvolvida em Shell Script (Bash) para automatizar o processo de envio (backup) e recuperação (restore) de volumes Docker e diretórios locais para buckets do AWS S3.

## 📋 Características Principais

* **Interface Visual no Terminal (TUI):** Interação amigável baseada em menus utilizando o `whiptail`.
* **Suporte a Múltiplos Alvos:** Realiza backup e restore tanto de **volumes gerenciados pelo Docker** quanto de **diretórios arbitrários** do sistema hospedeiro.
* **Empacotamento Eficiente:** Todos os dados são obrigatoriamente compactados em um arquivo único no formato `.tar.gz`. A sincronização de arquivos soltos (`aws s3 sync`) não é utilizada.
* **Versionamento Incremental Inteligente:** Backups sucessivos do mesmo volume/diretório recebem sufixos numéricos sequenciais (ex: `v1`, `v2`, `v3`) automaticamente, preservando o histórico completo no S3.

## 🔒 Segurança e Integridade

* **Proteção Anti-Sobrescrita:** A restauração é imediatamente abortada caso o volume Docker ou o diretório de destino já existam e contenham dados, prevenindo perdas acidentais.
* **Manifesto JSON de Rastreabilidade:** Cada backup gera um arquivo de metadados correspondente contendo o nome do alvo, versão, máquina de origem, usuário, caminho original, data e hash do pacote.
* **Validação Criptográfica Rigorosa (SHA256):** * O hash SHA256 do arquivo `.tar.gz` é calculado no momento do upload e gravado no manifesto.
  * No momento do download, o script recalcula o hash do pacote recebido e o cruza com o valor do manifesto para atestar a integridade. 
  * Em caso de divergência, o arquivo corrompido é sumariamente apagado e a extração é bloqueada.
* **Execução Segura:** A ferramenta atua de forma passiva em relação aos serviços; ela emite avisos, mas não pausa contêineres automaticamente. O controle de concorrência é delegado ao administrador.

## 🛠️ Pré-requisitos

Para executar o `bAcWapS`, certifique-se de ter os seguintes pacotes instalados no seu ambiente Linux:

* `bash` (Testado em ambientes Debian/Ubuntu/Mint)
* `whiptail` (Para renderização da interface TUI)
* `aws-cli` (Configurado com credenciais de acesso ao bucket S3 destino)
* `docker` (Obrigatório apenas se for interagir com volumes de contêineres)
* Utilitários padrão do sistema: `tar`, `sha256sum`, `grep`, `awk`

## 🚀 Instalação e Uso

1. Clone ou baixe os scripts para o seu servidor.
2. Certifique-se de que o script principal possui permissão de execução:
```bash
   chmod +x bacwaps.sh
```

3. Execute a ferramenta:
```bash
./bAcWapS.sh
```
4. Siga as instruções em tela para selecionar a operação (Backup/Restore), o tipo de alvo (Volume/Diretório), o nome/caminho e a URI do bucket S3.
# Privacidade das evidências versionadas

Os relatórios, logs e resultados históricos do repositório usam marcadores como `<ABT_REPO>`, `<JULIA_BIN>`, `<JULIA_DEPOT>` e `<USER_HOME>` no lugar de caminhos locais. Os resultados numéricos e as categorias de falha foram preservados. Para reproduzir comandos históricos, substitua esses marcadores pelos caminhos da sua instalação.

Dois logs de uma falha de CondaPkg continham uma cópia extensa das variáveis de ambiente do processo. Apenas essa lista de variáveis foi substituída por `<ENV_REDACTED>`; o comando, a falha e a causa continuam registrados.

O validador da documentação remove o caminho do clone e o diretório pessoal dos detalhes que grava em `logs/documentation/`. O comando `python3 tools/check_privacy.py` percorre os arquivos textuais rastreados e rejeita caminhos pessoais de Linux, macOS e Windows e cadeias com formato de token GitHub. O workflow executa essa verificação antes de publicar.

Esta correção limpa a árvore atual do repositório. Commits já publicados ainda contêm suas versões anteriores; eliminá-las exigiria reescrever o histórico remoto e invalidar referências existentes. Essa operação não foi feita nesta auditoria.

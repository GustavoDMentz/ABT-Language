# Contribuir e manter a documentação

Crie uma branch a partir de `main`; mantenha mudanças de documentação separadas de correções semânticas. Para uma operação nova, escreva contrato e exemplo reproduzível, atualize o registro e rode os testes dos três backends. Defeitos descobertos durante a redação devem ter relatório ou issue própria antes de qualquer correção de linguagem.

A validação dos exemplos de interoperação requer PythonCall 0.9.37 no ambiente de teste e Python 3 disponível. PythonCall permanece opcional para quem executa ABT sem importar Python. O workflow instala essa dependência somente no job de documentação.

```bash
python3 tools/generate_docs_reference.py --check
JULIA_CONDAPKG_BACKEND=Null JULIA_PYTHONCALL_EXE=/usr/bin/python3 julia --project=. -e 'import Pkg; Pkg.add(Pkg.PackageSpec(name="PythonCall", version="0.9.37"))'
python3 tools/validate_docs.py
julia --project=docs docs/make.jl
```

O gerador mantém as cinco páginas de operações e a página de exemplos sincronizadas com os contratos revisados em `tools/generate_docs_reference.py`; para alterar o conteúdo, edite esse arquivo e rode o gerador sem `--check`. O validador compara os 42 nomes documentados com `ABT.ABT_STDLIB_NAMES`, checa links e arquivos locais, executa exemplos ABT e inspeciona comandos CLI. As páginas manuais e os tutoriais são editados diretamente em `docs/src/`.

Documenter.jl usa o ambiente isolado `docs/Project.toml` e `docs/Manifest.toml`; o runtime ABT não depende dele. O workflow publica apenas após validação e build na `main`. Se o GitHub Pages ainda não estiver habilitado, o mantenedor deve selecionar **GitHub Actions** como fonte em *Settings → Pages*; a PR de documentação não muda essa configuração. Versões futuras podem usar aliases ou tags no site, mas a publicação inicial aponta para o conteúdo da `main`.

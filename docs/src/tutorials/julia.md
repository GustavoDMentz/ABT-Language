# Tutorial 7 — biblioteca Julia

**Objetivo:** importar uma API permitida com nome e aridade explícitos. **Pré-requisito:** [módulos e ponte](../manual/interop.md). **Arquivo:** `examples/pacote_dates.abt`; `Dates` já consta de `ABT.packages.toml`.

```abt
usar Julia.Dates
data = Julia.Dates.Date("2026-11-06")
mostrar data
mostrar Julia.Dates.year(data)
```

Execute `bin/abt run examples/pacote_dates.abt`. A última linha é `2026`. `usar Julia.Dates` precisa estar no nível superior e não instala o pacote; UUID, versão e funções permitidas são declarados no manifesto ABT, enquanto `Project.toml`/`Manifest.toml` governam a resolução Julia. Um método ou aridade fora da lista é erro, mesmo que exista em Julia.

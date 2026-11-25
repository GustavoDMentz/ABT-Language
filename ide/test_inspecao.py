"""Testes do modo de inspeção.

Dois grupos:
  * Com FIXTURES (ide/fixtures/*.json): saída REAL do compilador ABT 0.15.0 gravada por gerar_fixtures.py. Rodam em
    qualquer máquina (inclusive no CI, sem Julia) e validam tudo o que a IDE deriva desses dados.
  * De INTEGRAÇÃO (classe Integracao): usam a ABT instalada; são pulados quando ela não existe.
"""
import base64
import csv
import io
import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import zipfile
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import abt_ide  # noqa: E402
import exportar  # noqa: E402
import g2 as gramatica  # noqa: E402
import inspecao  # noqa: E402
import processos  # noqa: E402

FIX = Path(__file__).resolve().parent / "fixtures"


def carregar(nome):
    codigo = (FIX / (nome + ".abt")).read_text(encoding="utf-8")
    bruto = json.loads((FIX / (nome + ".json")).read_text(encoding="utf-8"))
    return codigo, bruto


def pacote(nome):
    codigo, bruto = carregar(nome)
    return inspecao.construir_pacote(codigo, bruto, ms_parede=1000)


def sx(n):
    """S-expressão de um nó serializado (só para comparar formas de árvore nos testes)."""
    if "n" in n:
        return "(" + " ".join([n["n"]] + [sx(x) for x in n["a"]]) + ")"
    if "l" in n:
        return "[" + " ".join(sx(x) for x in n["l"]) + "]"
    return str(n["v"])


class GramaticaG2(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = gramatica.G2()

    def test_tamanho_documentado(self):
        self.assertEqual(len(self.g.g.nts), 17)
        self.assertEqual(len(self.g.g.regras), 38)
        self.assertEqual(self.g.g.inicial, "Programa")
        self.assertEqual(len(self.g.M), 117)

    def test_sem_conflitos_e_ll1(self):
        self.assertEqual(self.g.conflitos, [])
        self.assertTrue(self.g.para_dict()["ll1"])

    def test_first_follow_calculados(self):
        self.assertEqual(self.g.first["Fator"], {"id", "num", "(", "["})
        self.assertEqual(self.g.first["Instrucao"], {"id", "mostrar", "se", "para"})
        self.assertIn("$", self.g.follow["Programa"])
        self.assertIn("}", self.g.follow["Instrucoes"])
        anulaveis = {"Programa", "Instrucoes", "Senao", "ExprR", "SomaR", "ProdR", "ElemsR"}   # Programa → Instrucoes → ε
        self.assertEqual(self.g.nul, anulaveis)

    def test_origem_das_entradas_da_tabela_m(self):
        celulas = {(c["nt"], c["terminal"]): c for c in self.g.para_dict()["tabela_m"]}
        self.assertEqual(celulas[("Instrucao", "mostrar")]["origem"], ["FIRST"])
        self.assertEqual(celulas[("ProdR", "+")]["origem"], ["FOLLOW"])     # ε-produção: vem de FOLLOW(ProdR)
        self.assertEqual(self.g.g.regras[celulas[("ProdR", "+")]["producoes"][0] - 1][1], ())

    def test_gramatica_ambigua_gera_conflito(self):
        g = gramatica.G2("S -> a | a b\n")
        self.assertEqual(g.conflitos, [("S", "a", [1, 2])])
        self.assertFalse(g.para_dict()["ll1"])

    def test_recalcula_ao_mudar_producoes(self):
        g = gramatica.G2("S -> a S | ε\n")
        self.assertEqual(g.first["S"], {"a"})
        self.assertEqual(g.follow["S"], {"$"})
        self.assertEqual(len(g.M), 2)


class ReferenciaAcademica(unittest.TestCase):
    """Programa de referência (média da turma): resultados documentados no relatório acadêmico."""

    @classmethod
    def setUpClass(cls):
        cls.p = pacote("referencia")

    def test_445_passos(self):
        a = self.p["sintatica"]["g2"]
        self.assertTrue(a["aceita"])
        self.assertEqual(a["n_passos"], 445)
        self.assertEqual(a["producoes_aplicadas"], 332)
        self.assertEqual(a["tokens_casados"], 111)
        self.assertEqual(a["nos"], 553)
        self.assertEqual(a["passos"][0]["tipo"], "inicio")
        self.assertEqual(a["passos"][-1]["tipo"], "aceita")
        self.assertEqual(a["passos"][-1]["pilha"], ["$"])

    def test_passos_consistentes(self):
        a = self.p["sintatica"]["g2"]
        prods = [x for x in a["passos"] if x["tipo"] == "producao"]
        self.assertEqual([x["producao"] for x in prods], a["sequencia_producoes"])      # derivação mais à esquerda
        for i, x in enumerate(a["passos"], start=1):
            self.assertEqual(x["n"], i)
            if x["consulta"]:
                self.assertEqual(x["consulta"]["producoes"], [x["producao"]] if x["producao"] else [])

    def test_aceito_pelos_dois_parsers(self):
        self.assertEqual(self.p["sintatica"]["veredito"]["codigo"], "aceito")
        self.assertEqual(self.p["sintatica"]["fora_do_recorte"], [])

    def test_tokens_identificadores_numeros_e_operadores(self):
        toks = [t for t in self.p["lexica"]["tokens"] if not t["eof"]]
        self.assertEqual(len(toks), 111)
        self.assertEqual(toks[0]["lexema"], "total")
        self.assertEqual((toks[0]["tipo"], toks[0]["linha"], toks[0]["coluna"]), ("IDENT", 2, 1))   # a linha 1 é comentário
        tipos = {t["tipo"] for t in toks}
        self.assertTrue({">=", "<=", "==", "!=", "<", ">"} <= tipos)      # operadores compostos e simples
        self.assertEqual(toks[2]["valor"], 0.0)
        self.assertEqual([t["indice"] for t in toks], list(range(1, 112)))
        for t in toks:
            self.assertEqual(t["comprimento"], len(t["lexema"]))

    def test_normalizacao_pelos_tokens(self):
        linhas = self.p["normalizado"]["texto"].splitlines()
        self.assertEqual(linhas[0], "")                                   # comentário não vira nada
        self.assertEqual(linhas[1], "id = num")
        self.assertIn("para cada id em [ num , num , num , num ] {", linhas)
        self.assertIn("se id < id {", linhas)
        self.assertNotRegex(self.p["normalizado"]["texto"], r"\b(total|contador|nota|7\.5)\b")
        self.assertEqual(len(linhas), 28)                                 # uma linha por linha do original

    def test_simbolos(self):
        nomes = {s["nome"]: s for s in self.p["simbolos"]["usuario"]}
        self.assertEqual(set(nomes), {"total", "contador", "baixas", "limite1", "nota", "media_turma", "ajuste", "situacao"})
        self.assertEqual(nomes["nota"]["categoria"], "variável de laço")
        self.assertEqual(nomes["total"]["primeira"], {"linha": 2, "coluna": 1})
        self.assertEqual(len(nomes["total"]["definicoes"]), 2)
        self.assertTrue(all(s["tipo"] is None for s in nomes.values()))    # tipos não são inventados
        atribuidos = set()                                                 # consistência com a AST real

        def visita(n):
            if "n" in n:
                if n["n"] == "assign":
                    atribuidos.add(n["a"][0]["v"])
                for f in n["a"]:
                    visita(f)
            elif "l" in n:
                for f in n["l"]:
                    visita(f)
        for n in self.p["ast"]["arvore"]:
            visita(n)
        self.assertEqual(atribuidos, {s["nome"] for s in nomes.values() if s["categoria"] == "variável"})

    def test_ast_e_ir_consistentes(self):
        ast, ir = self.p["ast"]["arvore"], self.p["ir"]["arvore"]
        self.assertEqual(len(ast), len(ir))
        par = {"assign": "store", "show": "print", "if": "branch", "for": "foreach"}
        self.assertEqual([par[n["n"]] for n in ast], [n["n"] for n in ir])
        c = self.p["correspondencia"]
        self.assertEqual(len(c), len(ast))
        self.assertEqual(c[0]["linhas"], [2, 2])
        self.assertEqual(c[4]["ast"], "for")
        self.assertEqual(c[4]["linhas"], [6, 12])

    def test_codigo_julia_exibido_e_o_gerado(self):
        _, bruto = carregar("referencia")
        self.assertEqual(self.p["gerado"]["normal"], bruto["etapas"]["geracao"]["codigo"])
        self.assertEqual(self.p["gerado"]["otimizado"], bruto["etapas"]["geracao_otimizada"]["codigo"])
        self.assertTrue(self.p["gerado"]["normal"].startswith("# Generated by ABT 0.15.0"))

    def test_sem_otimizacao_e_informado(self):
        self.assertFalse(self.p["otimizacao"]["aplicada"])
        self.assertIn("Nenhuma otimização", self.p["otimizacao"]["mensagem"])
        self.assertTrue(self.p["gerado"]["iguais"])


class OutrosProgramas(unittest.TestCase):
    def test_precedencia_e_associatividade_na_ast_real(self):
        ast = pacote("precedencia")["ast"]["arvore"]
        self.assertEqual(sx(ast[0]), "(show (bin - (bin - (bin + (lit 1) (bin * (lit 2) (lit 3))) (lit 4)) (lit 5)))")
        self.assertEqual(sx(ast[1]), "(show (bin / (bin / (lit 10) (lit 2)) (lit 5)))")             # associa à esquerda
        self.assertEqual(sx(ast[2]), "(show (bin * (bin + (lit 1) (lit 2)) (lit 3)))")              # parênteses
        self.assertEqual(sx(ast[3]), "(show (bin >= (bin + (lit 1) (lit 2)) (lit 3)))")             # relacional por último

    def test_palavras_em_ingles_condicionais_repeticao_lista_comentarios(self):
        p = pacote("ingles")
        tipos = [t["tipo"] for t in p["lexica"]["tokens"] if not t["eof"]]
        for k in ("FOR", "EACH", "IN", "IF", "AND", "ELSE", "SHOW"):
            self.assertIn(k, tipos)
        self.assertFalse(p["sintatica"]["g2"]["aceita"])                      # 'and' e textos: fora de G2
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "fora_do_recorte")
        self.assertEqual({f["tipo"] for f in p["sintatica"]["fora_do_recorte"]}, {"AND", "STRING"})
        self.assertEqual([n["n"] for n in p["ast"]["arvore"]], ["assign", "for", "show"])
        self.assertEqual(p["lexica"]["tokens"][-2]["linha"], 10)               # o comentário no fim da linha 10 é ignorado
        self.assertIn("[", sx(p["ast"]["arvore"][1]))

    def test_equivalencia_portugues_ingles(self):
        cat = {c["token"]: c for c in pacote("referencia")["lexica"]["reservadas"]}
        self.assertEqual(cat["SHOW"]["portugues"], ["mostrar"])
        self.assertEqual(cat["SHOW"]["ingles"], ["show"])
        self.assertEqual(cat["ELSE"]["lexemas"], ["else", "senao", "senão"])
        self.assertEqual(cat["ELSE"]["terminal_g2"], "senao")
        tokens = {t["lexema"]: t["tipo"] for t in pacote("ingles")["lexica"]["tokens"]}
        self.assertEqual(tokens["show"], "SHOW")
        self.assertEqual(tokens["each"], "EACH")
        self.assertEqual({t["tipo"] for t in pacote("referencia")["lexica"]["tokens"] if t["lexema"] == "mostrar"}, {"SHOW"})

    def test_normalizacao_nao_toca_dentro_de_textos(self):
        p = pacote("texto")
        linhas = p["normalizado"]["texto"].splitlines()
        self.assertEqual(linhas[1], 'id = "total 3 x"')                      # não é substituição textual frágil
        self.assertEqual(linhas[0], "id = num")
        self.assertEqual(p["lexica"]["tokens"][0]["lexema"], "café")         # identificador Unicode

    def test_pipeline_reescrito_pelo_lexer(self):
        p = pacote("pipeline")
        self.assertEqual(p["lexica"]["sinteticos"], 7)                        # tokens criados por expand_pipelines
        self.assertEqual(p["normalizado"]["omitidos"], 7)
        self.assertEqual({s["nome"] for s in p["simbolos"]["usuario"]}, {"dados", "medidas", "selecionadas"})
        self.assertEqual({s["nome"] for s in p["simbolos"]["embutidos_usados"]}, {"filtrar", "transformar", "limitar", "com", "a"})
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "fora_do_recorte")
        self.assertTrue(p["sintatica"]["real"]["ok"])
        for t in p["lexica"]["tokens"]:
            if t["sintetico"]:
                self.assertNotEqual(p["codigo"].split("\n")[t["linha"] - 1][t["coluna"] - 1:t["coluna"] - 1 + t["comprimento"]], t["lexema"])

    def test_fora_do_recorte_g2_mas_valido_na_abt(self):
        p = pacote("fora_g2")
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "fora_do_recorte")
        self.assertTrue(p["sintatica"]["real"]["ok"])
        self.assertFalse(p["sintatica"]["g2"]["aceita"])
        self.assertEqual([f["tipo"] for f in p["sintatica"]["fora_do_recorte"]], ["FUNCTION", "RETURN", "STRING", "^"])
        self.assertEqual(p["semantica"]["funcoes"], [{"nome": "dobro", "parametros": ["n"], "aridade": 1}])
        cats = {s["nome"]: s for s in p["simbolos"]["usuario"]}
        self.assertEqual(cats["n"]["categoria"], "parâmetro")
        self.assertEqual(cats["n"]["escopos_de_definicao"], ["dobro"])
        self.assertEqual(cats["nome"]["escopos_de_definicao"], ["global"])

    def test_funcao_recursiva_escopo(self):
        p = pacote("funcao")
        s = {x["nome"]: x for x in p["simbolos"]["usuario"]}
        self.assertEqual(s["fat"]["categoria"], "função")
        self.assertEqual(len(s["fat"]["usos"]), 2)                           # chamada recursiva e chamada global
        self.assertEqual(s["n"]["escopos_de_definicao"], ["fat"])
        self.assertEqual(s["resultado"]["escopos_de_definicao"], ["global"])

    def test_erro_lexico_real(self):
        p = pacote("erro_lexico")
        self.assertFalse(p["lexica"]["ok"])
        self.assertEqual(p["lexica"]["posicao"], {"linha": 2, "coluna": 7})
        self.assertIn("Unexpected character '@'", p["lexica"]["erro"])
        self.assertEqual(p["lexica"]["codigo"], "E000")
        self.assertEqual(p["lexica"]["total"], 6)                              # tokens antes do erro
        self.assertEqual(p["falha"], "lexica")
        self.assertEqual(len(p["etapas_nao_realizadas"]), 6)
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "lexico")
        self.assertIsNone(p["sintatica"]["g2"])
        self.assertIsNone(p["gerado"]["normal"])

    def test_erro_sintatico_real_e_primeiro_erro_g2(self):
        p = pacote("erro_sintatico")
        self.assertEqual(p["falha"], "sintatica")
        self.assertEqual(p["sintatica"]["real"]["codigo"], "E010")
        self.assertEqual(p["sintatica"]["real"]["posicao"], {"linha": 1, "coluna": 5})
        a = p["sintatica"]["g2"]
        self.assertFalse(a["aceita"])
        self.assertEqual((a["erro"]["linha"], a["erro"]["coluna"]), (1, 5))     # os dois apontam o mesmo token
        self.assertEqual(a["erro"]["tipo"], "celula_vazia")
        self.assertEqual(a["passos"][-1]["tipo"], "erro")
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "rejeitado_ambos")

    def test_erro_semantico_bloqueia_etapas_seguintes(self):
        p = pacote("erro_semantico")
        self.assertEqual(p["falha"], "semantica")
        self.assertEqual(p["semantica"]["codigo"], "E021")
        self.assertIn("undefined variable 'y'", p["semantica"]["erro"])
        self.assertEqual(p["etapas_nao_realizadas"], ["Otimização", "Geração de código Julia", "Geração de código Julia otimizado"])
        self.assertIsNotNone(p["ast"]["arvore"])            # AST e IR existem; o programa só não passa na semântica
        self.assertEqual(p["otimizacao"]["estado"], "nao_executada")
        self.assertEqual(p["sintatica"]["veredito"]["codigo"], "aceito")
        self.assertEqual({s["nome"]: s["categoria"] for s in p["simbolos"]["usuario"]}["y"], "sem definição no texto")

    def test_otimizacoes_reais_identificadas(self):
        p = pacote("otimizavel")
        o = p["otimizacao"]
        self.assertTrue(o["aplicada"])
        self.assertEqual([m["tipo"] for m in o["mudancas"]], ["constant folding", "eliminação de ramo morto", "constant folding"])
        self.assertEqual(o["histograma_antes"]["branch"], 1)
        self.assertNotIn("branch", o["histograma_depois"])
        self.assertTrue(any(m == "-" for m, _ in o["diff_ir"]) and any(m == "+" for m, _ in o["diff_ir"]))
        self.assertFalse(p["gerado"]["iguais"])
        self.assertTrue(any(m != "=" for m, _ in p["gerado"]["diff"]))


class Exportacao(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = pacote("referencia")

    def texto(self, item, p=None):
        nome, mime, dados = exportar.exportar(p or self.p, item)
        return nome, dados.decode("utf-8-sig")

    def test_quatro_arquivos_academicos(self):
        nome, t = self.texto("tokens_simbolos")
        self.assertEqual(nome, "tokens_simbolos.txt")
        for esperado in ("TABELA DE TOKENS", "TABELA DE SÍMBOLOS", "media_turma", "IDENT", r"\d+(?:\.\d+)?", "Padrão"):
            self.assertIn(esperado, t)
        self.assertEqual(self.texto("normalizado")[1].splitlines()[-27], "id = num")
        _, t = self.texto("passos")
        self.assertIn("Passos: 445 | produções aplicadas: 332 | tokens casados: 111", t)
        self.assertIn("M[Programa, id]", t)
        _, t = self.texto("resultado_sintatico")
        self.assertIn("ACEITO em 445 passos", t)
        self.assertIn("Parser real da ABT", t)

    def test_resultado_sintatico_de_erro_traz_primeiro_erro(self):
        _, t = self.texto("resultado_sintatico", pacote("erro_sintatico"))
        self.assertIn("REJEITADO", t)
        self.assertIn("linha 1, coluna 5", t)
        self.assertIn("Unexpected token", t)

    def test_csv_tem_colunas_e_linhas_reais(self):
        linhas = list(csv.reader(io.StringIO(self.texto("tokens_csv")[1])))
        self.assertEqual(linhas[0][:3], ["indice", "lexema", "tipo"])
        self.assertEqual(len(linhas) - 1, 111)
        self.assertEqual(len(list(csv.reader(io.StringIO(self.texto("tabela_m_csv")[1])))) - 1, 117)

    def test_json_valido_e_igual_aos_dados(self):
        self.assertEqual(json.loads(self.texto("ast_json")[1]), self.p["ast"]["arvore"])
        self.assertEqual(json.loads(self.texto("ir_json")[1]), self.p["ir"]["arvore"])
        self.assertEqual(json.loads(self.texto("inspecao_json")[1])["hash"], self.p["hash"])
        nome, mime, dados = exportar.exportar(self.p, "julia")
        self.assertEqual(dados.decode("utf-8"), self.p["gerado"]["normal"])
        self.assertFalse(dados.startswith("﻿".encode("utf-8")))

    def test_html_autossuficiente(self):
        nome, mime, dados = exportar.exportar(self.p, "relatorio_html")
        t = dados.decode("utf-8")
        self.assertEqual(mime, "text/html")
        for proibido in ("http://", "https://", "<script", "<link", "src="):
            self.assertNotIn(proibido, t)
        for esperado in ("Análise léxica", "445", "Gramática G2", "media_turma", "Código Julia gerado"):
            self.assertIn(esperado, t)

    def test_zip_com_tudo(self):
        _, _, dados = exportar.exportar(self.p, "relatorio_zip")
        nomes = set(zipfile.ZipFile(io.BytesIO(dados)).namelist())
        for n in ("tokens_simbolos.txt", "codigo_normalizado.txt", "passos_analise_sintatica.txt", "resultado_sintatico.txt",
                  "relatorio_inspecao.html", "programa_gerado.jl", "programa_gerado_otimizado.jl", "ast.json", "programa.abt"):
            self.assertIn(n, nomes)

    def test_todo_item_exporta_para_todo_cenario(self):
        for nome in sorted(p.stem for p in FIX.glob("*.abt")):
            p = pacote(nome)
            for item in list(exportar.ITENS) + ["relatorio_html", "relatorio_zip"]:
                exportar.exportar(p, item)

    def test_item_desconhecido(self):
        with self.assertRaises(KeyError):
            exportar.exportar(self.p, "../../etc/passwd")


class ServidorInspecao(unittest.TestCase):
    def setUp(self):
        self.srv = ThreadingHTTPServer(("127.0.0.1", 0), abt_ide.Manipulador)
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()
        self.addCleanup(self.srv.server_close)
        self.addCleanup(self.srv.shutdown)
        self.base = "http://127.0.0.1:%d" % self.srv.server_port
        self.token = abt_ide.TOKEN
        codigo, bruto = carregar("referencia")
        self.codigo = codigo
        self.mock = mock.patch.object(inspecao, "rodar_julia_inspecao", return_value=(bruto, 1234))
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def post(self, rota, dados, token=True):
        cab = {"Content-Type": "application/json"}
        if token:
            cab["X-IDE-Token"] = self.token
        req = urllib.request.Request(self.base + rota, data=json.dumps(dados).encode(), headers=cab)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, None

    def test_exige_token(self):
        for rota in ("/api/inspecionar", "/api/exportar", "/api/executar_caminho"):
            self.assertEqual(self.post(rota, {"codigo": "x"}, token=False)[0], 403)

    def test_estaticos_e_botao_na_pagina(self):
        for rota, tipo in (("/inspecao.js", "javascript"), ("/inspecao.css", "css")):
            with urllib.request.urlopen(self.base + rota) as r:
                self.assertIn(tipo, r.headers["Content-Type"])
        with urllib.request.urlopen(self.base + "/") as r:
            html = r.read().decode()
        self.assertIn("/inspecao.js", html)

    def test_estaticos_so_os_listados(self):
        for rota in ("/inspecao.py", "/../abt_ide.py", "/fixtures/referencia.json", "/g2.txt"):
            with self.assertRaises(urllib.error.HTTPError) as e:
                urllib.request.urlopen(self.base + rota)
            self.assertIn(e.exception.code, (403, 404))

    def test_inspecionar_e_exportar(self):
        st, p = self.post("/api/inspecionar", {"codigo": self.codigo})
        self.assertEqual(st, 200)
        self.assertEqual(p["sintatica"]["g2"]["n_passos"], 445)
        self.assertEqual(p["hash"], inspecao.sha(self.codigo))
        st, r = self.post("/api/exportar", {"hash": p["hash"], "item": "passos"})
        self.assertEqual(st, 200)
        self.assertIn("445", base64.b64decode(r["b64"]).decode("utf-8-sig"))
        self.assertEqual(self.post("/api/exportar", {"hash": p["hash"], "item": "nada"})[0], 400)
        st, r = self.post("/api/exportar", {"hash": "0" * 64, "item": "passos"})
        self.assertIn("expirada", r["erro_inspecao"])

    def test_corpo_invalido(self):
        self.assertEqual(self.post("/api/inspecionar", {})[0], 400)

    def test_caminhos_de_execucao_sao_explicitos_e_usam_o_codigo_do_compilador(self):
        _, p = self.post("/api/inspecionar", {"codigo": self.codigo})
        chamadas = []
        antigo = inspecao._rodar_julia
        inspecao._rodar_julia = lambda fonte, caminho: chamadas.append((fonte, caminho)) or {"caminho": caminho, "codigo_saida": 0, "saida": "ok", "erro": "", "ms": 1}
        self.addCleanup(setattr, inspecao, "_rodar_julia", antigo)
        self.assertEqual(chamadas, [])                                      # inspecionar NUNCA executa nada
        with mock.patch.object(abt_ide, "executar", return_value={"codigo_saida": 0, "saida": "interp", "erro": "", "ms": 2}):
            st, r = self.post("/api/executar_caminho", {"codigo": self.codigo, "caminho": "interpretador"})
        self.assertEqual((st, r["saida"]), (200, "interp"))
        self.post("/api/executar_caminho", {"codigo": self.codigo, "caminho": "julia_otimizado"})
        self.assertEqual(chamadas[0][0], p["gerado"]["otimizado"])          # o texto vem do servidor, nunca do cliente
        self.post("/api/executar_caminho", {"codigo": self.codigo, "caminho": "julia", "fonte": "println(1)"})
        self.assertEqual(chamadas[1][0], p["gerado"]["normal"])             # campo extra é ignorado
        self.assertEqual(sorted(inspecao.obter(p["hash"])["execucoes"]), ["interpretador", "julia", "julia_otimizado"])
        st, r = self.post("/api/executar_caminho", {"codigo": self.codigo, "caminho": "bash"})
        self.assertIn("desconhecido", r["erro_inspecao"])


class Descoberta(unittest.TestCase):
    def test_raiz_e_julia_pelo_abt_bin(self):
        with tempfile.TemporaryDirectory() as t:
            raiz = Path(t) / "ABT"
            (raiz / "bin").mkdir(parents=True)
            (raiz / "src").mkdir()
            (raiz / "src" / "ABT.jl").write_text("")
            (raiz / "Project.toml").write_text("")
            bin_ = raiz / "bin" / ("abt.cmd" if os.name == "nt" else "abt")
            bin_.write_text("")
            with mock.patch.dict(os.environ, {"ABT_RAIZ": ""}):
                self.assertEqual(processos.raiz_da_abt(str(bin_)).resolve(), raiz.resolve())
            exe = raiz / "runtime" / "julia" / "bin" / ("julia.exe" if os.name == "nt" else "julia")
            exe.parent.mkdir(parents=True)
            exe.write_text("")
            with mock.patch.dict(os.environ, {"ABT_JULIA": ""}):
                julia, env = processos.localizar_julia(raiz)
            self.assertEqual(julia, str(exe))
            self.assertEqual(env["JULIA_DEPOT_PATH"], str(raiz / "depot"))
            self.assertEqual(env["JULIA_PKG_OFFLINE"], "true")

    def test_sem_abt_levanta_erro_claro(self):
        with mock.patch.object(processos, "raiz_da_abt", return_value=None):
            with self.assertRaises(inspecao.ErroInspecao):
                inspecao.rodar_julia_inspecao("x = 1")


RAIZ = processos.raiz_da_abt()
JULIA = processos.localizar_julia(RAIZ)[0] if RAIZ else None


@unittest.skipUnless(RAIZ and JULIA, "ABT/Julia não instaladas: testes de integração pulados")
class Integracao(unittest.TestCase):
    """Rodam o compilador de verdade (lentos: cada inspeção inicia a Julia)."""

    def test_lexer_real_continua_com_as_regex_documentadas(self):
        fonte = (RAIZ / "src" / "ABT.jl").read_text(encoding="utf-8")
        for r in (inspecao.REGEX_NUMERO, inspecao.REGEX_NOME, inspecao.REGEX_OPERADOR):
            self.assertIn(r, fonte)
        self.assertIn(r'^\"(?:\\.|[^\"\\])*\"', fonte)                       # regex dos textos, como escrita em Julia
        for palavra in inspecao.PALAVRAS_DE_COLECAO:                        # palavras contextuais do parser
            self.assertIn('collection_form(p, "%s"' % palavra, fonte)

    def test_fixtures_continuam_iguais_ao_compilador(self):
        def limpo(x):
            if isinstance(x, dict):
                return {k: limpo(v) for k, v in x.items() if k not in ("ms", "ms_aquecido", "ms_carga_pacote", "julia")}
            if isinstance(x, list):
                return [limpo(v) for v in x]
            return x
        for nome in ("referencia", "otimizavel", "erro_lexico", "erro_semantico"):
            codigo, antigo = carregar(nome)
            novo, _ = inspecao.rodar_julia_inspecao(codigo)
            self.assertEqual(limpo(novo), limpo(antigo), nome)

    def test_instrumentacao_mede_tempo_aquecido(self):
        bruto, _ = inspecao.rodar_julia_inspecao("x = 1\nmostrar x\n", instrumentar=True)
        for e in bruto["etapas"].values():
            self.assertIn("ms_aquecido", e)

    def test_tres_caminhos_concordam_na_referencia(self):
        codigo, _ = carregar("referencia")
        inspecao.inspecionar(codigo)
        saidas = {}
        for c in inspecao.CAMINHOS:
            r = inspecao.executar_caminho(codigo, c, abt_ide.executar)
            self.assertEqual(r["codigo_saida"], 0, r)
            saidas[c] = r["saida"]
        self.assertEqual(len(set(saidas.values())), 1, saidas)
        esperado = (FIX / "referencia.saida").read_text(encoding="utf-8")
        self.assertEqual(saidas["interpretador"], esperado)

    def test_caminhos_concordam_com_otimizacao_ativa(self):
        codigo, _ = carregar("otimizavel")
        inspecao.inspecionar(codigo)
        saidas = {c: inspecao.executar_caminho(codigo, c, abt_ide.executar)["saida"] for c in inspecao.CAMINHOS}
        self.assertEqual(len(set(saidas.values())), 1, saidas)
        self.assertEqual(saidas["julia"], "10\ntrue\n5\n")

    def test_programa_rejeitado_nao_gera_codigo_nem_executa_julia(self):
        codigo, _ = carregar("erro_semantico")
        p = inspecao.inspecionar(codigo)
        self.assertIsNone(p["gerado"]["normal"])
        with self.assertRaises(inspecao.ErroInspecao):
            inspecao.executar_caminho(codigo, "julia", abt_ide.executar)


if __name__ == "__main__":
    unittest.main()

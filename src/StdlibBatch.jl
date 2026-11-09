# ABT 0.11.8 batch extensions. Each operation loads only the Julia package it uses.
function abt_batch_require(name, uuid)
 try
  return Base.invokelatest(Base.require, Base.PkgId(Base.UUID(uuid), name))
 catch err
  error("ABT extensão $name indisponível: " * sprint(showerror, err))
 end
end
abt_batch_number(x) = (typeof(x) === Int64 || typeof(x) === Float64) && isfinite(x)
function abt_batch_table_column(table, name, operation)
 abt_std_istable(table) || error("ABT $operation: esperado tabela tipada")
 name isa String && name in table.columns || error("ABT $operation: coluna inexistente " * repr(name))
 return table.types[findfirst(==(name), table.columns)]
end

function abt_std_group_data(table, group_name, value_name, missing_policy)
 abt_batch_table_column(table, group_name, "agrupar_dados") == "texto" || error("ABT agrupar_dados: grupo deve ser texto")
 kind = abt_batch_table_column(table, value_name, "agrupar_dados")
 kind in ("inteiro", "real") || error("ABT agrupar_dados: valor deve ser numérico")
 group_name != value_name || error("ABT agrupar_dados: colunas devem ser distintas")
 missing_policy in ("erro", "ignorar_linha") || error("ABT agrupar_dados: política inválida")
 df = abt_batch_require("DataFrames", "a93c6f00-e57d-5684-b7b6-d8193f3e46c0")
 return Base.invokelatest(abt_std_group_data_loaded, table, group_name, value_name, missing_policy, df)
end
function abt_std_group_data_loaded(table, group_name, value_name, policy, df)
 groups = String[]; kind=table.types[findfirst(==(value_name),table.columns)]
 values = kind == "inteiro" ? Int64[] : Float64[]; read_count = 0; ignored = 0
 try
  for row in table.rows
   read_count += 1
   group = getproperty(row, Symbol(group_name)); value = getproperty(row, Symbol(value_name))
   if group === missing || value === missing
    policy == "ignorar_linha" || error("ABT agrupar_dados: linha $read_count: valor ausente")
    ignored += 1; continue
   end
   group isa String && abt_batch_number(value) || error("ABT agrupar_dados: linha $read_count: tipo inválido")
   (kind == "inteiro" ? typeof(value) === Int64 : typeof(value) === Float64) || error("ABT agrupar_dados: linha $read_count: tipo incompatível com esquema")
   push!(groups, group); push!(values, value)
  end
 catch err
  abt_std_table_error("agrupar_dados", table, err)
 end
 frame = df.DataFrame(grupo=groups, valor=values)
 ordered = [ (; grupo=String(first(chunk.grupo)), valores=collect(chunk.valor), quantidade=length(chunk.valor))
            for chunk in df.groupby(frame, :grupo; sort=false) ]
 return (; grupos=ordered, linhas_lidas=read_count, linhas_ignoradas=ignored)
end

function abt_std_test_groups(grouped, first_name, second_name, method)
 grouped isa NamedTuple && hasproperty(grouped, :grupos) && grouped.grupos isa Vector || error("ABT testar_grupos: esperado resultado de agrupar_dados")
 first_name isa String && second_name isa String && first_name != second_name || error("ABT testar_grupos: nomes de grupos distintos são obrigatórios")
 method in ("welch", "student") || error("ABT testar_grupos: método deve ser welch ou student")
 selected = [g for g in grouped.grupos if g.grupo in (first_name, second_name)]
 length(selected) == 2 || error("ABT testar_grupos: os dois grupos devem existir")
 a = only(g.valores for g in selected if g.grupo == first_name)
 b = only(g.valores for g in selected if g.grupo == second_name)
 length(a) >= 2 && length(b) >= 2 || error("ABT testar_grupos: cada grupo exige ao menos dois valores")
 all(abt_batch_number, a) && all(abt_batch_number, b) || error("ABT testar_grupos: valores não finitos")
 ht = abt_batch_require("HypothesisTests", "09f84164-cd44-5f33-b23f-e6b0d136a0d5")
 return Base.invokelatest(abt_std_test_groups_loaded, a, b, first_name, second_name, method, ht)
end
function abt_std_test_groups_loaded(a,b,first_name,second_name,method,ht)
 try
  test = method == "welch" ? ht.UnequalVarianceTTest(a,b) : ht.EqualVarianceTTest(a,b)
  return (; metodo=method, grupo_a=first_name, grupo_b=second_name,
          n_a=length(a), n_b=length(b), media_a=sum(a)/length(a), media_b=sum(b)/length(b),
          estatistica=Float64(test.t), p_valor=Float64(ht.pvalue(test)))
 catch err
  error("ABT testar_grupos: " * sprint(showerror, err))
 end
end

function abt_std_categories(table, name, levels, missing_policy)
 abt_batch_table_column(table, name, "categorias") == "texto" || error("ABT categorias: coluna deve ser texto")
 levels isa Vector && !isempty(levels) && all(x -> x isa String, levels) && length(unique(levels)) == length(levels) || error("ABT categorias: níveis explícitos únicos são obrigatórios")
 missing_policy in ("erro", "ignorar_linha") || error("ABT categorias: política inválida")
 ca = abt_batch_require("CategoricalArrays", "324d7699-5711-5eae-9e2f-1d82baa6b597")
 return Base.invokelatest(abt_std_categories_loaded, table, name, levels, missing_policy, ca)
end
function abt_std_categories_loaded(table, name, levels, policy, ca)
 values=String[]; ignored=0; index=0
 try
  for row in table.rows
   index += 1; value=getproperty(row, Symbol(name))
   if value === missing
    policy == "ignorar_linha" || error("ABT categorias: linha $index: ausente")
    ignored += 1; continue
   end
   value isa String && value in levels || error("ABT categorias: linha $index: categoria fora dos níveis")
   push!(values,value)
  end
 catch err
  abt_std_table_error("categorias", table, err)
 end
 categorical=ca.categorical(values; levels=levels, ordered=true)
 return (; categorias=[(; nivel=level, quantidade=count(x -> String(x)==level, categorical)) for level in levels],
          linhas_lidas=index, linhas_ignoradas=ignored)
end

function abt_std_normal_tail(mean_value, deviation, threshold)
 all(abt_batch_number, (mean_value,deviation,threshold)) || error("ABT probabilidade_normal: parâmetros devem ser números finitos")
 deviation > 0 || error("ABT probabilidade_normal: desvio deve ser positivo")
 dist=abt_batch_require("Distributions", "31c24e10-a181-5473-b8eb-7969acd0382f")
 return Base.invokelatest(abt_std_normal_tail_loaded, Float64(mean_value), Float64(deviation), Float64(threshold), dist)
end
function abt_std_normal_tail_loaded(mean_value,deviation,threshold,dist)
 p=dist.ccdf(dist.Normal(mean_value,deviation),threshold)
 return (; modelo="normal", media=mean_value, desvio=deviation, limiar=threshold, probabilidade_acima=p)
end

function abt_std_chart(table, xname, yname, mode)
 xkind=abt_batch_table_column(table,xname,"grafico")
 ykind=abt_batch_table_column(table,yname,"grafico")
 xkind in ("inteiro","real") && ykind in ("inteiro","real") || error("ABT grafico: eixos devem ser numéricos")
 mode in ("linha","pontos") || error("ABT grafico: modo deve ser linha ou pontos")
 xs=Float64[]; ys=Float64[]; index=0
 try
  for row in table.rows
   index += 1; x=getproperty(row,Symbol(xname)); y=getproperty(row,Symbol(yname))
   abt_batch_number(x) && abt_batch_number(y) || error("ABT grafico: linha $index: valor ausente ou inválido")
   push!(xs,Float64(x)); push!(ys,Float64(y))
  end
 catch err
  abt_std_table_error("grafico",table,err)
 end
 isempty(xs) && error("ABT grafico: tabela vazia")
 return (; tipo="grafico_abt", modo=mode, eixo_x=xname, eixo_y=yname, x=xs, y=ys)
end
function abt_std_save_chart(spec,path)
 spec isa NamedTuple && keys(spec)==(:tipo,:modo,:eixo_x,:eixo_y,:x,:y) && spec.tipo=="grafico_abt" || error("ABT salvar_figura: esperado gráfico ABT")
 path isa String && (endswith(lowercase(path),".png") || endswith(lowercase(path),".svg")) || error("ABT salvar_figura: caminho deve terminar em .png ou .svg")
 cairo=abt_batch_require("Cairo", "159f3aea-2a34-519c-b102-8c37f9878175")
 return Base.invokelatest(abt_std_save_chart_loaded,spec,path,cairo)
end
function abt_std_save_chart_loaded(spec,path,cairo)
 width=640; height=480
 surface=nothing
 try
  surface=endswith(lowercase(path),".png") ? cairo.CairoRGBSurface(width,height) : cairo.CairoSVGSurface(path,width,height)
  ctx=cairo.CairoContext(surface)
  cairo.set_source_rgb(ctx,1.0,1.0,1.0)
  cairo.rectangle(ctx,0.0,0.0,width,height); cairo.fill(ctx)
  left=72.0; right=32.0; top=36.0; bottom=66.0
  xmin,xmax=extrema(spec.x); ymin,ymax=extrema(spec.y)
  xspan=xmax==xmin ? 1.0 : xmax-xmin
  yspan=ymax==ymin ? 1.0 : ymax-ymin
  xpos(x)=left+(x-xmin)/xspan*(width-left-right)
  ypos(y)=height-bottom-(y-ymin)/yspan*(height-top-bottom)
  cairo.set_source_rgb(ctx,0.16,0.20,0.27); cairo.set_line_width(ctx,1.5)
  cairo.move_to(ctx,left,top); cairo.line_to(ctx,left,height-bottom)
  cairo.line_to(ctx,width-right,height-bottom); cairo.stroke(ctx)
  cairo.set_font_size(ctx,14.0)
  cairo.move_to(ctx,left,height-25.0); cairo.show_text(ctx,spec.eixo_x)
  cairo.save(ctx); cairo.translate(ctx,20.0,height/2+40.0); cairo.rotate(ctx,-pi/2)
  cairo.move_to(ctx,0.0,0.0); cairo.show_text(ctx,spec.eixo_y); cairo.restore(ctx)
  cairo.set_font_size(ctx,11.0)
  cairo.move_to(ctx,left,height-bottom+20.0); cairo.show_text(ctx,string(xmin))
  cairo.move_to(ctx,width-right-58.0,height-bottom+20.0); cairo.show_text(ctx,string(xmax))
  cairo.move_to(ctx,8.0,height-bottom); cairo.show_text(ctx,string(ymin))
  cairo.move_to(ctx,8.0,top+5.0); cairo.show_text(ctx,string(ymax))
  cairo.set_source_rgb(ctx,0.12,0.42,0.72); cairo.set_line_width(ctx,2.5)
  if spec.modo=="linha"
   cairo.move_to(ctx,xpos(spec.x[1]),ypos(spec.y[1]))
   for i in 2:length(spec.x)
    cairo.line_to(ctx,xpos(spec.x[i]),ypos(spec.y[i]))
   end
   cairo.stroke(ctx)
  end
  for i in eachindex(spec.x)
   cairo.arc(ctx,xpos(spec.x[i]),ypos(spec.y[i]),3.5,0.0,2pi); cairo.fill(ctx)
  end
  if endswith(lowercase(path),".png")
   cairo.write_to_png(surface,path)
  end
  cairo.finish(surface)
  return (; arquivo=path,pontos=length(spec.x))
 catch err
  surface === nothing || try cairo.finish(surface) catch end
  error("ABT salvar_figura: arquivo '$path': " * sprint(showerror,err))
 end
end

function abt_std_align_fasta(handle, first_id, second_id, mode, match_score, mismatch_score, gap_open, gap_extend)
 abt_std_isfasta(handle) || error("ABT alinhar_sequencias: esperado FASTA ABT")
 first_id isa String && second_id isa String && first_id != second_id || error("ABT alinhar_sequencias: identificadores distintos são obrigatórios")
 mode in ("global","local") || error("ABT alinhar_sequencias: modo deve ser global ou local")
 all(x -> typeof(x)===Int64, (match_score,mismatch_score,gap_open,gap_extend)) || error("ABT alinhar_sequencias: pontuações devem ser Int64")
 match_score > 0 && mismatch_score <= 0 && gap_open <= 0 && gap_extend <= 0 || error("ABT alinhar_sequencias: pontuações inválidas")
 rows=abt_std_fasta_records(handle)
 selected_a=[r for r in rows if r.identificador==first_id]
 selected_b=[r for r in rows if r.identificador==second_id]
 length(selected_a)==1 || error("ABT alinhar_sequencias: identificador inexistente " * repr(first_id))
 length(selected_b)==1 || error("ABT alinhar_sequencias: identificador inexistente " * repr(second_id))
 a=only(selected_a); b=only(selected_b)
 bio=abt_batch_require("BioSequences", "7e6ae17a-c86d-528c-b3b9-7f778a29fe59")
 align=abt_batch_require("BioAlignments", "00701ae9-d1dc-5365-b64a-a3a3ebf5695e")
 return Base.invokelatest(abt_std_align_fasta_loaded, a,b,handle,mode,match_score,mismatch_score,gap_open,gap_extend,bio,align)
end
function abt_std_align_fasta_loaded(a,b,handle,mode,m,mm,go,ge,bio,align)
 try
  seq1=handle.alphabet=="DNA" ? bio.LongDNA{4}(a.sequencia) : bio.LongRNA{4}(a.sequencia)
  seq2=handle.alphabet=="DNA" ? bio.LongDNA{4}(b.sequencia) : bio.LongRNA{4}(b.sequencia)
  model=align.AffineGapScoreModel(;match=m,mismatch=mm,gap_open=go,gap_extend=ge)
  kind=mode=="global" ? align.GlobalAlignment() : align.LocalAlignment()
  result=align.pairalign(kind,seq1,seq2,model)
  paired=align.alignment(result)
  return (; identificador_a=a.identificador, identificador_b=b.identificador, modo=mode,
          pontuacao=align.score(result), correspondencias=align.count_matches(paired),
          diferencas=align.count_mismatches(paired), insercoes=align.count_insertions(paired),
          delecoes=align.count_deletions(paired))
 catch err
  error("ABT alinhar_sequencias: " * sprint(showerror,err))
 end
end

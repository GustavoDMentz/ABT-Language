using Test, ABT, LinearAlgebra
const S = ABT
@testset "bibliotecas científicas 0.13.0" begin
 @test !any(pkg -> pkg.name=="MultipleTesting",keys(Base.loaded_modules))
 @test !any(pkg -> pkg.name=="Optim",keys(Base.loaded_modules))
 @test length(S.abt_extension_catalog())==55  # 41 em 0.13.0 + 14 operações de bioinformática da 0.14.0
 path=joinpath(@__DIR__,"..","applications","scientific_0130","data","reads.fastq")
 h=S.abt_sc_fastq(path,"DNA","rejeitar","phred33")
 q=S.abt_sc_fastq_summary(h)
 @test (q.registros,q.bases,q.A,q.C,q.G,q.T,q.phred_medio)==(2,12,4,4,3,1,35.0)
 @test length(S.abt_sc_fastq_records(h))==2
 @test S.abt_sc_reverse("ACGTN")=="NACGT"
 @test S.abt_sc_translate("ATGGAA")=="ME"
 k=S.abt_sc_kmers("ACGTAC",2)
 @test k.total==5 && only(x for x in k.frequencias if x.sequencia=="AC").quantidade==2
 @test_throws ErrorException S.abt_sc_fastq(path,"DNA","rejeitar","unknown")
 @test_throws ErrorException S.abt_sc_kmers("ACNT",2)
 @test_throws ErrorException S.abt_sc_translate("ATGGA")
 for content in ("", "@r\nAC\n+\n", "@r\nAN\n+\nII\n", "@r\nAC\n+\nI \n")
  mktemp() do bad,io
   write(io,content); flush(io)
   @test_throws Exception S.abt_sc_fastq_summary(S.abt_sc_fastq(bad,"DNA","rejeitar","phred33"))
  end
 end
 a=[[2.0,0.0],[0.0,3.0]]; m=[2.0 0.0;0.0 3.0]
 @test S.abt_sc_product(a,a)==[[4.0,0.0],[0.0,9.0]]
 @test S.abt_sc_transpose(a)==a
 @test S.abt_sc_det(a)≈det(m)
 @test S.abt_sc_rank(a,0.0)==rank(m;atol=0.0,rtol=0.0)
 @test S.abt_sc_solve(a,[2.0,3.0]).solucao≈m\[2.0,3.0]
 @test S.abt_sc_decompose(a,"svd").singulares≈svdvals(m)
 qrresult=S.abt_sc_decompose(a,"qr")
 @test reduce(vcat,permutedims.(qrresult.Q))*reduce(vcat,permutedims.(qrresult.R))≈m
 tall=[1.0 2.0;3.0 4.0;5.0 6.0]
 tall_qr=S.abt_sc_decompose([[1.0,2.0],[3.0,4.0],[5.0,6.0]],"qr")
 @test reduce(vcat,permutedims.(tall_qr.Q))*reduce(vcat,permutedims.(tall_qr.R))≈tall
 eig=S.abt_sc_decompose(a,"autovalores_simetricos")
 @test eig.valores≈eigen(Symmetric(m)).values
 @test_throws ErrorException S.abt_sc_product([[1.0]],[[1.0,2.0],[3.0,4.0]])
 @test_throws ErrorException S.abt_sc_product([[1,2]],[[1.0],[2.0]])
 @test_throws ErrorException S.abt_sc_solve(a,[1.0])
 @test_throws ErrorException S.abt_sc_solve([[1.0,2.0],[2.0,4.0]],[1.0,2.0])
 @test_throws ErrorException S.abt_sc_decompose([[1.0,2.0],[3.0,4.0]],"autovalores_simetricos")
 @test_throws ErrorException S.abt_sc_rank(a,-1.0)
 @eval using MultipleTesting, Optim
 ps=[0.01,0.04,0.2]
 for (name,method) in (("bonferroni",Bonferroni()),("holm",Holm()),("bh",BenjaminiHochberg()),("by",BenjaminiYekutieli()))
  @test S.abt_sc_adjust(ps,name,0.05).ajustados≈MultipleTesting.adjust(ps,method)
 end
 @test_throws ErrorException S.abt_sc_adjust([1.2],"holm",0.05)
 @test_throws ErrorException S.abt_sc_adjust(ps,"unknown",0.05)
 opt=S.abt_sc_minimize([1.0,-2.0,1.0],-2.0,3.0,1e-8,1e-10,100)
 direct=Optim.optimize(x->evalpoly(x,[1.0,-2.0,1.0]),-2.0,3.0,Optim.Brent();rel_tol=1e-8,abs_tol=1e-10,iterations=100)
 @test opt.solucao≈Optim.minimizer(direct) && opt.valor_objetivo≈Optim.minimum(direct) && opt.convergiu
 @test !S.abt_sc_minimize([1.0,-2.0,1.0],-2.0,3.0,1e-8,1e-10,1).convergiu
 @test_throws ErrorException S.abt_sc_minimize([1.0],3.0,-2.0,1e-8,1e-10,100)
 schema=S.abt_std_schema("gene","texto","log2fc","real","p_valor","real")
 table=S.abt_std_csv(joinpath(@__DIR__,"..","applications","scientific_0130","data","expressao.csv"),schema,"erro")
 selected=S.abt_sc_select(table,["gene","p_valor"])
 @test selected.columns==["gene","p_valor"] && length(S.abt_std_table_rows(selected))==3
 renamed=S.abt_sc_rename(selected,["p_valor"],["p"])
 @test renamed.columns==["gene","p"]
 sorted=S.abt_sc_sort(renamed,["p"],["decrescente"],"erro")
 @test first(S.abt_std_column(sorted,"gene"))=="G3"
 @test length(S.abt_std_table_rows(S.abt_sc_unique(selected,["gene"])))==3
 joined=S.abt_sc_join(selected,renamed,["gene"],"interna")
 @test joined.columns==["gene","p_valor","p"] && length(S.abt_std_table_rows(joined))==3
 unmatched=S.abt_std_table([(;gene="G4",p=0.2)], ["gene","p"], ["texto","real"], "teste")
 left_join=S.abt_sc_join(selected,unmatched,["gene"],"esquerda")
 @test length(S.abt_std_table_rows(left_join))==3 && all(ismissing(row.p) for row in S.abt_std_table_rows(left_join))
 with_missing=S.abt_std_table([(;gene="A",p=missing),(;gene="B",p=0.3)], ["gene","p"], ["texto","real"], "teste")
 @test first(S.abt_std_table_rows(S.abt_sc_sort(with_missing,["p"],["crescente"],"primeiro"))).gene=="A"
 @test last(S.abt_std_table_rows(S.abt_sc_sort(with_missing,["p"],["crescente"],"ultimo"))).gene=="A"
 @test_throws ErrorException S.abt_sc_sort(with_missing,["p"],["crescente"],"erro")
 missing_key=S.abt_std_table([(;gene=missing,p=0.3)], ["gene","p"], ["texto","real"], "teste")
 @test_throws ErrorException S.abt_sc_join(missing_key,unmatched,["gene"],"interna")
 mktemp() do file,io
  close(io)
  result=S.abt_sc_export(joined,file,"NA")
  @test result.linhas==3 && occursin("gene,p_valor,p",read(file,String))
 end
 mktemp() do file,io
  close(io)
  empty_table=S.abt_std_table(NamedTuple[],["gene"],["texto"],"teste")
  @test S.abt_sc_export(empty_table,file,"NA").linhas==0 && read(file,String)=="gene\n"
 end
 @test_throws ErrorException S.abt_sc_select(table,["missing"])
 @test_throws ErrorException S.abt_sc_rename(selected,["gene"],["p_valor"])
 @test_throws ErrorException S.abt_sc_join(selected,table,["gene"],"interna")
end

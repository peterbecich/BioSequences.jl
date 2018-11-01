
function Base.iterate(it::EachSkipmerIterator{SK, <:Unsigned, <:BioSequence}) where {SK<:Skipmer}
    @inbounds for i in 1:BioSequences.cycle_len(SK)
        cycle_pos[i] = N - i
        last_unknown[i] = -1
        fkmer[i] = 0
        rkmer[i] = 0
    end
end


#=
 12345678901234567890123456789
 xx xx xx xx xx xx xx xx xx xx
  xx xx xx xx xx xx xx xx xx x
 x xx xx xx xx xx xx xx xx xx 
"GAGGGGGATGCCCCTCTTTGAGCCCAAGG" - 29 bases

=================================================

 12345678901234567890123456789
 xx xx xx xx xx xx xx xx xx xx
"GAGGGGGATGCCCCTCTTTGAGCCCAAGG" - 29 bases
"GA GG GA GC CC CT TG         " - 1          "CAAGGGGCTCCCTC"          
"   GG GA GC CC CT TG GC      " - 4
"      GA GC CC CT TG GC CA   " - 7
"         GC CC CT TG GC CA GG" - 10

 12345678901234567890123456789
  xx xx xx xx xx xx xx xx xx x
"GAGGGGGATGCCCCTCTTTGAGCCCAAGG" - 29 bases
" AG GG AT CC CT TT GA        " - 2              
"    GG AT CC CT TT GA CC     " - 5
"       AT CC CT TT GA CC AA  " - 8

 12345678901234567890123456789
 x xx xx xx xx xx xx xx xx xx 
"GAGGGGGATGCCCCTCTTTGAGCCCAAGG" - 29 bases
"  GG GG TG CC TC TT AG       " - 3
"     GG TG CC TC TT AG CC    " - 6
"        TG CC TC TT AG CC AG " - 9



seq = BioSequence{DNAAlphabet{2}}("GAGGGGGATGCCCCTCTTTGAGCCCAAGG")
K = 14
M = 2
N = 3
S = 20
=#



function make_from_seq(::Type{Skipmer{T, M, N, K}}, seq) where {T <: NucleicAcid, M, N, K}
    skipmers = Vector{Skipmer{T, M, N, K}}()
    
    kmer_mask = (UInt64(1) << (K * 2)) - 1
    firstoffset = (K - 1) * 2
    S = BioSequences.span(Skipmer{T, M, N, K})
    last_unknown = Vector{Int64}(undef, N)
    fkmer = Vector{UInt64}(undef, N)
    rkmer = Vector{UInt64}(undef, N)
    cycle_pos = Vector{UInt8}(undef, N)
    fi = 0x01
    
    @inbounds for i in 1:N
        cycle_pos[i] = N - i
        last_unknown[i] = -1
        fkmer[i] = 0
        rkmer[i] = 0
    end
    
    for p in eachindex(seq)
        
        for ni in 1:N
            cycle_pos[ni] += 1
            if cycle_pos[ni] == N
                cycle_pos[ni] = 0
            end
            
            if cycle_pos[ni] < M
                println("Sequence position: ", p, ", Phase: ", ni)
                fbits = BioSequences.twobitnucs[reinterpret(UInt8, seq[p]) + 0x01]
                rbits = ~fbits & 0x03
                fkmer[ni] = ((fkmer[ni] << 2) | fbits) & kmer_mask
                rkmer[ni] = (rkmer[ni] >> 2) | (UInt64(rbits) << firstoffset)
            end
        end
        
        # If we are at p, the skip-mer that started at p-S is now done. 
        if p >= S
            if p == S
                fi = 0x01
            else
                fi += 0x01
                if fi == (N + 1)
                    fi = 0x01
                end
            end
            if last_unknown[fi] + S <= p
                if fkmer[fi] <= rkmer[fi]
                    push!(skipmers, reinterpret(Skipmer{T, M, N, K}, fkmer[fi]))
                else
                    push!(skipmers, reinterpret(Skipmer{T, M, N, K}, rkmer[fi]))
                end
            end
        end
        
    end
    
    return skipmers
        
end
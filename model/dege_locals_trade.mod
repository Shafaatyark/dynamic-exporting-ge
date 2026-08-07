    @#for go in goods
        #gx@{go}r@{co} = (
        @#for co1 in countries
            @#if co!=co1
                +exp(p@{go}@{co}@{co1}+@{go}@{co}@{co1})
            @#endif
        @#endfor
        )/exp(p@{go}@{co}@{co}+@{go}@{co}@{co});
        #gm@{go}r@{co} = (
        @#for co1 in countries
            @#if co!=co1
                +exp(p@{go}@{co1}@{co}+@{go}@{co1}@{co})
            @#endif
        @#endfor
        )/exp(p@{go}@{co}@{co}+@{go}@{co}@{co});
        #gm@{go}@{co} = (
        @#for co1 in countries
            @#if co!=co1
                +exp(tau@{co1}@{co}+p@{go}@{co1}@{co}+@{go}@{co1}@{co})
            @#endif
        @#endfor
        )/exp(p@{go}@{co}@{co}+@{go}@{co}@{co});
    @#endfor

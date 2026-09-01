# Render-time apparatus helpers for the ISE 754 lecture meta-panels.
#
# `logjam_fns` regenerates the "New Logjam functions used" panel from the
# live docstrings on every render, so it can never fall out of date and
# needs no per-lecture curation. It pulls the one-line summary from each
# function's *primary* docstring (the scalar / keyword signature), skipping
# Logjam's struct-form `(sh, tr)` overload docstrings — which by convention
# open with "Struct-form overload of …".
#
# Included once per lecture from the hidden setup chunk:
#     include("../_common/julia/apparatus.jl")
# and called from an `#| output: asis` chunk inside the panel:
#     logjam_fns(:maxpayld, :rate_ltl, :prt)

_apparatus_raw(ds) = try; join(string.(ds.text)); catch; ""; end

# First prose line of a docstring: skip the indented signature block and any
# leading blank lines, then take the next non-blank line.
function _apparatus_firstprose(s::AbstractString)
    lines = split(s, '\n')
    i = 1
    while i <= length(lines) && (startswith(lines[i], "    ") || isempty(strip(lines[i])))
        i += 1
    end
    return i <= length(lines) ? strip(lines[i]) : ""
end

"""
    docline(M, name) -> String

One-line summary from the primary docstring of `name` in module `M`,
skipping Logjam's struct-form overload docstrings. Returns "" if absent.
"""
function docline(M::Module, name::Symbol)
    md = Base.Docs.meta(M)
    b = Base.Docs.Binding(M, name)
    haskey(md, b) || return ""
    for sig in md[b].order
        fp = _apparatus_firstprose(_apparatus_raw(md[b].docs[sig]))
        startswith(fp, "Struct-form overload") && continue
        return fp
    end
    return ""
end

"""
    logjam_fns(names...)

Print (for an `#| output: asis` chunk) a Markdown bullet list of the named
Logjam functions, each with its primary-docstring one-liner.
"""
function logjam_fns(names::Symbol...)
    for n in names
        println("- `", n, "`: ", docline(Logjam, n))
    end
end

"""
    docparams(M, name) -> String

The `# Arguments` bullets from the primary docstring of `name` in module `M`,
as Markdown, or "" if the docstring has no such section.

WHY THIS EXISTS (instructor, 2026-09-01). An implementation rung backed by an
imported Logjam export can only show the bare handle -- `ufladd` -- since there
is no definition to display. That leaves "just a bunch of variables": the
formulation above states the model in set notation, `kᵢ` and `C = (cᵢⱼ)`, and
nothing connects those to the `k`, `C`, `y`, `p` the function actually takes.
The keywords are worse, appearing ONLY in the implementation.

Read LIVE from the loaded module at render, exactly as `docline` is, so it
cannot drift from the pinned Logjam. That is the whole argument for generating
this rather than writing it by hand once per rung.

Arguments only, deliberately: `# Returns` repeats across the UFL family almost
verbatim and the rung's own signature comment already names what comes back.
"""
function docparams(M::Module, name::Symbol)
    md = Base.Docs.meta(M)
    b = Base.Docs.Binding(M, name)
    haskey(md, b) || return ""
    for sig in md[b].order
        raw = _apparatus_raw(md[b].docs[sig])
        startswith(_apparatus_firstprose(raw), "Struct-form overload") && continue
        i = findfirst("# Arguments", raw)
        i === nothing && continue
        rest = raw[(last(i) + 1):end]
        j = findfirst(r"\n#+ ", rest)          # the next section heading, if any
        body = j === nothing ? rest : rest[1:(first(j) - 1)]
        return strip(body)
    end
    return ""
end

"""
    logjam_sig(M, name) -> String

The call form of `name` as `(args; keywords)`, read from its first method.

Derived, not typed. The hand-written signature comments this replaces were wrong
about `pmedian` within a day of being written, because they were copied from the
working-copy source while the PINNED package is what renders.
"""
function logjam_sig(M::Module, name::Symbol; keywords::Bool = true)
    args = String.(Base.method_argnames(first(methods(getfield(M, name))))[2:end])
    filter!(a -> !startswith(a, "#"), args)
    kws = keywords ? logjam_kwargs(M, name) : String[]
    return "(" * join(args, ", ") * (isempty(kws) ? "" : "; " * join(kws, ", ")) * ")"
end

"""
    logjam_kwargs(M, name) -> Vector{String}

The keyword names of `name`, which is also what tells a rung's parameter list
which docstring bullets are optional.
"""
function logjam_kwargs(M::Module, name::Symbol)
    kws = String.(Base.kwarg_decl(first(methods(getfield(M, name)))))
    return filter(k -> !endswith(k, "..."), kws)
end

"""
    logjam_ret(M, name) -> String

The returned form of `name`, taken from the first `# Returns` bullet of its
docstring -- e.g. `(y, TC, W)`.

Instructor, 2026-09-01: "keep the input argument to output argument on the last
line ... currently nothing shows what the output arguments come from the
functions." Derived like everything else in a rung, so `y, TC, W` is the
docstring's own naming rather than a guess, and it cannot drift.
"""
function logjam_ret(M::Module, name::Symbol)
    md = Base.Docs.meta(M)
    b = Base.Docs.Binding(M, name)
    haskey(md, b) || return ""
    for sig in md[b].order
        raw = _apparatus_raw(md[b].docs[sig])
        startswith(_apparatus_firstprose(raw), "Struct-form overload") && continue
        i = findfirst("# Returns", raw)
        i === nothing && continue
        m = match(r"-\s*`([^`]+)`", raw[(last(i) + 1):end])
        return m === nothing ? "" : m.captures[1]
    end
    return ""
end

"""
    logjam_rung(name, title)

Print (for an `#| output: asis` chunk) a COMPLETE implementation rung as one
fenced Julia block: the model title, the parameter definitions as comments, and
the bare handle with its derived signature.

One block rather than two (instructor, 2026-09-01), so the rung reads as a single
piece of code rather than as a comment box sitting above a separate handle.
Nothing here executes: a rung shows apparatus, and the docstring lookup already
proves the binding exists -- an unknown name yields no parameters at all.
"""
function logjam_rung(name::Symbol, title::AbstractString;
                     width::Int = 74, keywords::Bool = true)
    # `keywords = false` FOR A PROCEDURE'S FIRST PRESENTATION (instructor,
    # 2026-09-01): "the initial one and then the modified one are identical.
    # That's confusing ... when you first present it, not include the two optional
    # keywords. That would make the second one actually different." ADD and
    # Modified ADD are one export, so with every parameter shown both rungs
    # rendered the same line and the second looked like a duplicate. A rung should
    # show what its own formulation describes: plain ADD takes `(k, C)`, and the
    # warm start and the cap arrive with the modified formulation that introduces
    # them.
    skip = keywords ? String[] : logjam_kwargs(Logjam, name)
    println("```julia")
    println("# Model: ", title)
    _logjam_param_comments(name; width = width, skip = skip)
    ret = logjam_ret(Logjam, name)
    println(rpad(String(name), 10), " # ",
            logjam_sig(Logjam, name; keywords = keywords),
            isempty(ret) ? "" : " -> " * ret)
    println("```")
    return nothing
end

function _logjam_param_comments(name::Symbol; width::Int = 74,
                                skip::Vector{String} = String[])
    body = docparams(Logjam, name)
    isempty(body) && return nothing
    # AS JULIA COMMENTS, INSIDE THE SHADED RUNG (instructor, 2026-09-01: "They
    # should be part of the shaded model section. These can be comments in
    # Julia."). A rung is a code block, so the parameter definitions belong in it
    # rather than in a disclosure beneath it -- but they still have to be
    # GENERATED, or they drift from the pinned Logjam the moment a docstring
    # changes. Printing from an `output: asis` chunk gives both.
    # JOIN EACH BULLET FIRST. A docstring bullet may run over several lines, and
    # treating every line as its own bullet mangles the long ones -- `ala`'s
    # `alloc` came out as three comments, two of them starting mid-sentence with
    # no name. Only a line beginning "- " starts a new parameter.
    bullets = String[]
    for b in split(body, "\n")
        s = strip(b)
        isempty(s) && continue
        if startswith(s, "-") || isempty(bullets)
            push!(bullets, s)
        else
            bullets[end] *= " " * s
        end
    end
    for s in bullets
        s = replace(s, r"^-\s*" => "", "`" => "")      # bullet and code ticks
        nm = strip(first(split(s, ":")))
        nm in skip && continue                          # an optional not shown here
        line = "#"
        for w in split(s)
            if length(line) + 1 + length(w) > width
                println(line); line = "#    " * w      # continuation, indented
            else
                line *= " " * w
            end
        end
        println(line)
    end
    return nothing
end

"""
    mdtable(headers, rows; align, caption, label, colwidths)

Print (for an `#| output: asis` chunk) a Markdown table from already-
formatted string cells, with an optional cross-referenceable caption.

Use this for a table whose generating code is **hidden** (`#| echo: false`):
the hidden Julia keeps the numbers reproducible-on-edit, while Markdown gives
clean output — no DataFrame type-row or index column, real math in cells and
caption, and `--:` column alignment. When the generating code is **visible**,
show a `DataFrame` (or Logjam's `prt`) instead, so a student reading the code
can reproduce the result; the DataFrame's extra chrome is worth it only then.

`headers` and each element of `rows` are vectors of strings; `align` is a
per-column vector of `:l` / `:c` / `:r` (default all `:r`). `colwidths`, if
given, is a per-column vector of relative widths emitted as Quarto's
`tbl-colwidths` (e.g. `[40, 12, 12, 12, 12, 12]` to widen a long label column
and shrink the rest so the table fits). A `\$` in a cell or caption must be
escaped (`\\\$`) in the Julia source so it is not interpolated.
"""
function mdtable(headers, rows; align=nothing, caption="", label="", colwidths=nothing)
    al = align === nothing ? fill(:r, length(headers)) : align
    sep(a) = a === :l ? ":---" : a === :c ? ":---:" : "---:"
    println("| ", join(headers, " | "), " |")
    println("| ", join(sep.(al), " | "), " |")
    for r in rows
        println("| ", join(r, " | "), " |")
    end
    if !isempty(caption) || !isempty(label)
        attrs = String[]
        isempty(label) || push!(attrs, "#$label")
        colwidths === nothing ||
            push!(attrs, "tbl-colwidths=\"[" * join(colwidths, ",") * "]\"")
        println()
        print(": ", caption)
        isempty(attrs) || print(" {", join(attrs, " "), "}")
        println()
    end
    return nothing
end

nothing

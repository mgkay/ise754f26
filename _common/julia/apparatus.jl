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

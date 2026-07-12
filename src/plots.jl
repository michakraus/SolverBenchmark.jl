const _PRECISION_ORDER = ["Float16", "Float32", "Float64"]

# Display order for the initial guesses (panels/rows in the plots and tables).
const _INITIAL_GUESS_ORDER = ["NoInitialGuess", "HermiteExtrapolation", "MidpointExtrapolation"]

# Return the distinct values present in `values`, ordered according to `order`
# (values not listed in `order` are appended in first-appearance order).
function _ordered(values, order)
    present = unique(values)
    vcat([v for v in order if v in present], [v for v in present if v ∉ order])
end

"""
    summary_table(df; drop_empty = true)

Return a tidy copy of a benchmark `DataFrame` for display: a selection of the
most relevant columns, sorted by precision, solver and initial guess. Columns
that are entirely `missing` (e.g. `accuracy` for problems without an analytic
reference) are dropped when `drop_empty = true`.
"""
function summary_table(df::DataFrame; panelcol::Symbol = :initial_guess,
                       panel_order = _INITIAL_GUESS_ORDER, drop_empty::Bool = true)
    cols = [:precision, :solver_label, panelcol, :converged,
            :iterations_mean, :runtime_s, :max_residual, :energy_drift, :accuracy]
    out = select(df, intersect(cols, propertynames(df)))

    porder = Dict(p => i for (i, p) in enumerate(_PRECISION_ORDER))
    sorder = Dict(s => i for (i, s) in enumerate(unique(df.solver_label)))
    gorder = Dict(g => i for (i, g) in enumerate(_ordered(df[!, panelcol], panel_order)))
    sort!(out, [DataFrames.order(:precision, by = p -> get(porder, p, 99)),
                DataFrames.order(:solver_label, by = s -> get(sorder, s, 99)),
                DataFrames.order(panelcol, by = g -> get(gorder, g, 99))])

    if drop_empty
        for c in names(out)
            all(ismissing, out[!, c]) && select!(out, Not(c))
        end
    end
    out
end

_fmt_cell(::Missing) = "—"
_fmt_cell(x::Bool) = x ? "✓" : "✗"
_fmt_cell(x::AbstractFloat) = isfinite(x) ? (@sprintf("%.3g", x)) : string(x)
_fmt_cell(x) = string(x)

"""
    markdown_table(df)

Render a `DataFrame` as a `Markdown.MD` GFM table with compact formatting
(`missing` shown as `—`, booleans as `✓`/`✗`, floats in 3 significant digits).
Useful in Documenter `@example` blocks, where the returned value is rendered as
an HTML table.
"""
function markdown_table(df::DataFrame)
    cols = names(df)
    io = IOBuffer()
    println(io, "| ", join(cols, " | "), " |")
    println(io, "|", repeat(" --- |", length(cols)))
    for row in eachrow(df)
        println(io, "| ", join((_fmt_cell(row[c]) for c in cols), " | "), " |")
    end
    Markdown.parse(String(take!(io)))
end

"""
    comparison_figure(df, valcol; ylabel, yscale = identity, title = "", converged_only = false)

Build a `CairoMakie.Figure` comparing metric `valcol` across the benchmarked
solver configurations. One panel is drawn per initial guess; within each panel
the solver configurations are on the x-axis and the floating point precisions
are distinguished by colour. Missing values (and, on logarithmic axes,
non-positive values) are omitted. With `converged_only = true` only converged
runs are shown (a missing bar/marker then means "did not converge").
"""
function comparison_figure(df::DataFrame, valcol::Symbol;
                           ylabel::AbstractString = string(valcol),
                           yscale = identity,
                           title::AbstractString = "",
                           converged_only::Bool = false,
                           panelcol::Symbol = :initial_guess,
                           panel_order = _INITIAL_GUESS_ORDER)

    # category axes come from the full grid so failing configs keep their tick
    igs     = _ordered(df[!, panelcol], panel_order)
    solvers = unique(df.solver_label)
    precs   = filter(p -> p in df.precision, _PRECISION_ORDER)
    converged_only && (df = df[df.converged, :])
    nprec   = length(precs)
    colors  = cgrad(:viridis, max(nprec, 2); categorical = true)
    islog   = yscale in (log10, log2, log)

    fig  = Figure(size = (340 * length(igs) + 180, 480))
    axes = Axis[]
    for (j, ig) in enumerate(igs)
        ax = Axis(fig[1, j];
            title = ig,
            ylabel = j == 1 ? ylabel : "",
            xticks = (1:length(solvers), solvers),
            xticklabelrotation = π / 4,
            yscale = yscale)
        push!(axes, ax)
        sub = df[df[!, panelcol] .== ig, :]

        for (pi, p) in enumerate(precs)
            xs = Float64[]; ys = Float64[]
            for (si, s) in enumerate(solvers)
                r = sub[(sub.solver_label .== s) .& (sub.precision .== p), :]
                isempty(r) && continue
                v = r[1, valcol]
                v === missing && continue
                vf = Float64(v)
                isfinite(vf) || continue
                (islog && vf <= 0) && continue
                offset = nprec == 1 ? 0.0 : (pi - (nprec + 1) / 2) * (0.72 / nprec)
                push!(xs, si + offset); push!(ys, vf)
            end
            isempty(xs) && continue
            if islog
                scatter!(ax, xs, ys; color = colors[pi], markersize = 12, strokewidth = 0.5)
            else
                barplot!(ax, xs, ys; width = 0.72 / nprec, color = colors[pi])
            end
        end
        xlims!(ax, 0.4, length(solvers) + 0.6)
    end
    length(axes) > 1 && linkyaxes!(axes...)

    elems = islog ? [MarkerElement(marker = :circle, color = colors[i], markersize = 12) for i in 1:nprec] :
                    [PolyElement(polycolor = colors[i]) for i in 1:nprec]
    Legend(fig[1, length(igs) + 1], elems, precs, "precision")

    isempty(title) || Label(fig[0, :], title; fontsize = 18, font = :bold)
    fig
end

"""
    plot_iterations(df; title = "")

Grouped bar chart of the mean number of nonlinear-solver iterations per time step
(converged runs only).
"""
plot_iterations(df::DataFrame; title = "", kwargs...) =
    comparison_figure(df, :iterations_mean; ylabel = "mean iterations / step",
        converged_only = true, title, kwargs...)

"""
    plot_runtime(df; title = "")

Comparison of the integration run time (seconds, logarithmic axis; converged runs only).
"""
plot_runtime(df::DataFrame; title = "", kwargs...) =
    comparison_figure(df, :runtime_s; ylabel = "runtime [s]", yscale = log10,
        converged_only = true, title, kwargs...)

"""
    plot_energy_drift(df; title = "")

Comparison of the energy (invariant) drift `|H(t_end) - H(t_0)|` (logarithmic axis).
"""
plot_energy_drift(df::DataFrame; title = "", kwargs...) =
    comparison_figure(df, :energy_drift; ylabel = "energy drift", yscale = log10, title, kwargs...)

"""
    plot_accuracy(df; title = "")

Comparison of the maximum error against the analytic solution (logarithmic axis).
Only meaningful for problems that provide a reference solution.
"""
plot_accuracy(df::DataFrame; title = "", kwargs...) =
    comparison_figure(df, :accuracy; ylabel = "max error vs. analytic", yscale = log10, title, kwargs...)

"""
    plot_convergence(df; title = "")

Overview of convergence across the whole grid: one panel per initial guess, with
solver configurations on the x-axis and precisions on the y-axis. Green cells
converged, red cells did not.
"""
function plot_convergence(df::DataFrame; title::AbstractString = "",
                          panelcol::Symbol = :initial_guess,
                          panel_order = _INITIAL_GUESS_ORDER)
    igs     = _ordered(df[!, panelcol], panel_order)
    solvers = unique(df.solver_label)
    precs   = filter(p -> p in df.precision, _PRECISION_ORDER)

    fig = Figure(size = (340 * length(igs) + 180, 340))
    for (j, ig) in enumerate(igs)
        ax = Axis(fig[1, j];
            title = ig,
            xticks = (1:length(solvers), solvers),
            xticklabelrotation = π / 4,
            yticks = (1:length(precs), precs))
        sub = df[df[!, panelcol] .== ig, :]
        M = fill(NaN, length(solvers), length(precs))
        for (si, s) in enumerate(solvers), (pj, p) in enumerate(precs)
            r = sub[(sub.solver_label .== s) .& (sub.precision .== p), :]
            isempty(r) || (M[si, pj] = r[1, :converged] ? 1.0 : 0.0)
        end
        heatmap!(ax, 1:length(solvers), 1:length(precs), M;
            colormap = [:firebrick, :seagreen], colorrange = (0, 1))
    end

    elems = [PolyElement(polycolor = :seagreen), PolyElement(polycolor = :firebrick)]
    Legend(fig[1, length(igs) + 1], elems, ["converged", "failed"], "status")
    isempty(title) || Label(fig[0, :], title; fontsize = 18, font = :bold)
    fig
end


# ---------------------------------------------------------------------------
# Box Plot

notch_width(q2, q4, N) = 1.58 * (q4-q2)/sqrt(N)

@recipe function f(
    ::Type{Val{:boxplot}},
    x,
    y,
    z;
    notch = false,
    range = 1.5,
    outliers = true,
    whisker_width = :half,
    percentiles = [0.25, 0.5, 0.75]
)
    # if only y is provided, then x will be UnitRange 1:size(y,2)
    if typeof(x) <: AbstractRange
        if step(x) == first(x) == 1
            x = plotattributes[:series_plotindex]
        else
            x = [getindex(x, plotattributes[:series_plotindex])]
        end
    end
    xsegs, ysegs = Segments(), Segments()
    texts = String[]
    glabels = sort(collect(unique(x)))
    warning = false
    emptywarning = false
    outliers_x, outliers_y = zeros(0), zeros(0)
    bw = plotattributes[:bar_width]
    isnothing(bw) && (bw = 0.8)
    @assert whisker_width == :match || whisker_width == :half || whisker_width >= 0 "whisker_width must be :match, :half, or a positive number"
    ww = whisker_width == :match ? bw : 
         whisker_width == :half ? bw / 2 :
         whisker_width
    for (i, glabel) in enumerate(glabels)
        # filter y
        values = y[filter(i -> _cycle(x, i) == glabel, 1:length(y))]

        # compute quantiles
        q1, q2, q3, q4, q5 = quantile(values, Base.range(0, stop = 1, length = 5))

        # ensure that only valid percentiles are requested (also removing the min + max to ensure lower + upper T gets rendered)
        filter!(x -> x > 0 && x < 100, percentiles)

        # if our validated percentiles result in an empty list, use default quartiles
        if isempty(percentiles)
            if !emptywarning
                @warn("Zero valid percentiles were requested. Plotting using quartiles.")
                emptywarning = true # Show the warning only one time
            end
            percentiles = [0.25, 0.5, 0.75]
        end

        # compute percentiles
        ps = sort(quantile(values, unique(percentiles)))

        # get minimum and maximum values which are not q1 or q5
        pmin, pmax = extrema(ps)

        # notch
        n = notch_width(q2, q4, length(values))

        # warn on inverted notches?
        if notch && !warning && ((q2 > (q3 - n)) || (q4 < (q3 + n)))
            @warn("Boxplot's notch went outside hinges. Set notch to false.")
            warning = true # Show the warning only one time
        end

        # make the shape
        center = Plots.discrete_value!(plotattributes[:subplot][:xaxis], glabel)[1]
        hw = 0.5_cycle(bw, i) # Box width
        HW = 0.5_cycle(ww, i) # Whisker width
        l, m, r = center - hw, center, center + hw
        lw, rw = center - HW, center + HW

        # internal nodes for notches
        L, R = center - 0.5 * hw, center + 0.5 * hw

        # outliers
        if Float64(range) != 0.0  # if the range is 0.0, the whiskers will extend to the data
            limit = range * (pmax - pmin)
            inside = Float64[]
            for value in values
                if (value < (pmin - limit)) || (value > (pmax + limit))
                    if outliers
                        push!(outliers_y, value)
                        push!(outliers_x, center)
                    end
                else
                    push!(inside, value)
                end
            end
            # change q1 and q5 to show outliers
            # using maximum and minimum values inside the limits
            q1, q5 = Plots.ignorenan_extrema(inside)
            q1, q5 = (min(q1, pmin), max(pmax, q5)) # whiskers cannot be inside the box
        end
        # Box
        push!(xsegs, m, lw, rw, m, m)       # lower T
        push!(ysegs, q1, q1, q1, q1, pmin)    # lower T
        push!(
            texts,
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Lower fence: $q1",
            "Q1: $pmin",
            "",
        )

        if notch
            # draw segments between requested percentile pairs, accounting for case where notch lies between percentiles
            for (ii, (pa, pb)) in enumerate(zip(ps, ps[2:end]))
                # determine if percentile window being processed falls within the notch
                inlower = (q3 - n > pa) && (q3 - n < pb)
                inupper = (q3 + n > pa) && (q3 + n < pb)
                
                # account for case where the percentile window falls in the upper portion of notch
                if inupper
                    push!(xsegs, r, r, l, l, L, R, r, r) # upper box
                    push!(ysegs, q3 + n, pb, pb, q3 + n, q3, q3, q3 + n, pb) # upper box
                    push!(texts, 
                        "Q$ii: $pb",
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Q$ii: $pb",
                        "Q$ii: $pb",
                        "Median: $q3 ± $n",
                        "",
                    )
                end

                # account for case where the percentile window falls in the lower portion of notch
                if inlower
                    push!(xsegs, r, r, R, L, l, l, r, r) # lower box
                    push!(ysegs, pa, q3 - n, q3, q3, q3 - n, pa, pa, q3 - n) # lower box
                    push!(texts, "Q$ii: $pa", 
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Median: $q3 ± $n",
                        "Q$ii: $pa",
                        "Q$ii: $pa",
                        "Median: $q3 ± $n",
                        "",
                    )
                end
                
                # account for case where the percentile window is completely outside the notch
                if !inupper & !inlower
                    push!(xsegs, r, r, l, l, r, r)
                    push!(ysegs, pa, pb, pb, pa, pa, pb)
                    push!(texts, "Q$ii: $pa", "Median: $pb", "Median: $pb", "Q$ii: $pa", "Q$ii: $pa", "Median: $pb", "")
                end
            end
        else
            # draw segments between requested percentile pairs
            for (ii, (pa, pb)) in enumerate(zip(ps, ps[2:end]))
                push!(xsegs, r, r, l, l, r, r)
                push!(ysegs, pa, pb, pb, pa, pa, pb)
                push!(texts, "Q$ii: $pa", "Median: $pb", "Median: $pb", "Q$ii: $pa", "Q$ii: $pa", "Median: $pb", "")
            end
        end

        push!(xsegs, m, lw, rw, m, m)             # upper T
        push!(ysegs, q5, q5, q5, q5, pmax)          # upper T
        push!(
            texts,
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Upper fence: $q5",
            "Q3: $pmax",
            "",
        )

    end

    @series begin
        # To prevent linecolor equal to fillcolor (It makes the median visible)
        if plotattributes[:linecolor] == plotattributes[:fillcolor]
            plotattributes[:linecolor] = plotattributes[:markerstrokecolor]
        end
        primary := true
        seriestype := :shape
        x := xsegs.pts
        y := ysegs.pts
        ()
    end

    # Outliers
    if outliers && !isempty(outliers)
        @series begin
            primary := false
            seriestype := :scatter
            if get!(plotattributes, :markershape, :circle) == :none
                plotattributes[:markershape] = :circle
            end

            fillrange := nothing
            x := outliers_x
            y := outliers_y
            ()
        end
    end

    # Hover
    primary := false
    seriestype := :path
    marker := false
    hover := texts
    linewidth := 0
    x := xsegs.pts
    y := ysegs.pts
    ()
end

Plots.@deps boxplot shape scatter


# ------------------------------------------------------------------------------
# Grouped Boxplot

@userplot GroupedBoxplot

recipetype(::Val{:groupedboxplot}, args...) = GroupedBoxplot(args)

@recipe function f(g::GroupedBoxplot; spacing = 0.1)
    x, y = grouped_xy(g.args...)

    # extract xnums and set default bar width.
    # might need to set xticks as well
    ux = unique(x)
    x = if eltype(x) <: Number
        bar_width --> (0.8 * mean(diff(sort(ux))))
        float.(x)
    else
        bar_width --> 0.8
        xnums = [findfirst(isequal(xi), ux) for xi in x] .- 0.5
        xticks --> (eachindex(ux) .- 0.5, ux)
        xnums
    end

    # shift x values for each group
    group = get(plotattributes, :group, nothing)
    if group != nothing
        gb = RecipesPipeline._extract_group_attributes(group)
        labels, idxs = getfield(gb, 1), getfield(gb, 2)
        n = length(labels)
        bws = plotattributes[:bar_width] / n
        bar_width := bws * clamp(1 - spacing, 0, 1)
        for i in 1:n
            groupinds = idxs[i]
            Δx = _cycle(bws, i) * (i - (n + 1) / 2)
            x[groupinds] .+= Δx
        end
    end

    seriestype := :boxplot
    x, y
end

Plots.@deps groupedboxplot boxplot
